// FILEPATH: lib/src/screens/mygarden_taskview.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../services/task_service.dart';
import '../../services/weather_service.dart';
import '../../model/task_model.dart';
import 'mygarden_history.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';

class MyGardenTaskView extends StatefulWidget {
  final String plantId;
  final String commonName;
  final String growthType;

  const MyGardenTaskView({
    super.key, 
    required this.plantId, 
    required this.commonName, 
    required this.growthType
  });

  @override
  _MyGardenTaskViewState createState() => _MyGardenTaskViewState();
}

class _MyGardenTaskViewState extends State<MyGardenTaskView> with SingleTickerProviderStateMixin {
  int _currentTaskNumber = 1;
  String? _libraryPlantId;
  bool _isLoading = true;
  String _errorMessage = '';
  int _totalTasks = 0;
  int _completedTasks = 0;
  bool _isFirstDay = false;
  String _lastWeatherCondition = '';
  String _lastTimeOfDay = '';
  List<TaskModel> _tasks = [];
  String? _plantImageUrl;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  DateTime _lastReset = DateTime.now();
  
  late final WeatherService _weatherService;
  late final TaskService _taskService;
  late Timer _weatherUpdateTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _weatherService = WeatherService('ab71a5a7461d08be8573bdd947fb6285');
    _taskService = TaskService(_weatherService, FirebaseFirestore.instance);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn)
    );
    
    _fetchPlantData();
    _checkForDailyReset();
  }

  @override
  void dispose() {
    _weatherUpdateTimer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlantData() async {
    try {
      var userPlantDoc = await FirebaseFirestore.instance
          .collection('UserPlants')
          .doc(widget.plantId)
          .get();
      
      if (userPlantDoc.exists) {
        var userData = userPlantDoc.data() as Map<String, dynamic>;
        _currentTaskNumber = userData['currentTaskNumber'] ?? 1;
        _isFirstDay = userData['isFirstDay'] ?? true;
        // Read completed tasks count if available
        _completedTasks = userData['completedTasks'] ?? 0;

        var libraryQuery = await FirebaseFirestore.instance
            .collection('PlantLibrary')
            .where('commonName', isEqualTo: widget.commonName)
            .get();

        if (libraryQuery.docs.isNotEmpty) {
          _libraryPlantId = libraryQuery.docs.first.id;
          var libraryData = libraryQuery.docs.first.data();
          _plantImageUrl = libraryData['PlantImage'] as String?;
        } else {
          throw Exception("No matching plant found in PlantLibrary for common name: ${widget.commonName}");
        }
      } else {
        throw Exception("User plant document does not exist for ID: ${widget.plantId}");
      }
      
      await _fetchInitialTasks();
      
      // Validate and fix task counts
      await _validateTaskCounts();
      
      _startWeatherTaskUpdates();
      _animationController.forward();

    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchInitialTasks() async {
    try {
      // First, check if we have any pending tasks in the app-specific collection
      var pendingTasksSnapshot = await FirebaseFirestore.instance
          .collection('UserPlants')
          .doc(widget.plantId)
          .collection('PendingTasks')
          .get();
      
      List<TaskModel> pendingTasks = [];
      
      // If there are pending tasks, use those
      if (pendingTasksSnapshot.docs.isNotEmpty) {
        print('Found ${pendingTasksSnapshot.docs.length} pending tasks');
        for (var doc in pendingTasksSnapshot.docs) {
          var taskData = doc.data();
          pendingTasks.add(TaskModel(
            taskName: taskData['taskName'] ?? '',
            taskDesc: taskData['taskDesc'] ?? '',
            isWeatherTask: taskData['isWeatherTask'] ?? false,
            completedToday: taskData['completedToday'] ?? false,
            taskNumber: taskData['taskNumber'] ?? 0,
          ));
        }
        
        // Sort tasks by task number to ensure proper sequencing
        pendingTasks.sort((a, b) => a.taskNumber.compareTo(b.taskNumber));
        _tasks = pendingTasks;
      } else {
        // If no pending tasks, fetch fresh tasks from the library
      _tasks = await _taskService.fetchInitialTasks(
        libraryPlantId: _libraryPlantId!, 
        growthType: widget.growthType, 
        isFirstDay: _isFirstDay
      );

        // Save the fetched tasks to PendingTasks collection
        await _savePendingTasks(_tasks);
      }

      // Fetch total task count if not already set
      if (_totalTasks == 0) {
      _totalTasks = await _taskService.fetchTotalTasks(
        libraryPlantId: _libraryPlantId!, 
        growthType: widget.growthType
      );
      }
      
      // Only fetch weather tasks if plant tasks are completed
      String currentWeather = await _weatherService.getCurrentWeatherCondition();
      String currentTime = _getTimeOfDay();
      
      // Check if all plant tasks are completed
      bool plantTasksCompleted = _areAllPlantTasksCompleted() || _completedTasks >= _totalTasks;
      
      // Only fetch weather tasks if plant tasks are done or there are no plant tasks
      if (plantTasksCompleted) {
        print('All plant tasks completed or no plant tasks, fetching weather tasks');
        await _fetchWeatherTasks(currentWeather, currentTime);
      } else {
        print('Plant tasks not completed, weather tasks will be fetched later');
        // Still store the conditions for later
        _lastWeatherCondition = currentWeather;
        _lastTimeOfDay = currentTime;
      }
      
      setState(() {
        // Important: Reset current task number if we have no plant tasks but have weather tasks
        if (_currentTaskNumber > _totalTasks && _tasks.isNotEmpty) {
          _currentTaskNumber = 1;
          print('Reset current task number to 1');
        }
      });
    } catch (e) {
      print("Error fetching initial tasks: $e");
    }
  }

  // Helper to check if all plant-based tasks are completed
  bool _areAllPlantTasksCompleted() {
    // If completed tasks count equals or exceeds total tasks, all plant tasks are completed
    return _completedTasks >= _totalTasks && _totalTasks > 0;
  }

  Future<void> _savePendingTasks(List<TaskModel> tasks) async {
    // Save only non-weather tasks as pending
    var nonWeatherTasks = tasks.where((task) => !task.isWeatherTask).toList();
    
    // Clear existing pending tasks first
    var pendingTasksSnapshot = await FirebaseFirestore.instance
        .collection('UserPlants')
        .doc(widget.plantId)
        .collection('PendingTasks')
        .where('isWeatherTask', isEqualTo: false)
        .get();
    
    for (var doc in pendingTasksSnapshot.docs) {
      await doc.reference.delete();
    }
    
    // Save new non-weather tasks
    for (var task in nonWeatherTasks) {
      await FirebaseFirestore.instance
          .collection('UserPlants')
          .doc(widget.plantId)
          .collection('PendingTasks')
          .add({
        'taskName': task.taskName,
        'taskDesc': task.taskDesc,
        'isWeatherTask': false,
        'taskNumber': task.taskNumber,
      });
    }
  }

  String _getTimeOfDay() {
    var now = DateTime.now().toLocal();
    var hour = now.hour;
    
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  void _startWeatherTaskUpdates() {
    _weatherUpdateTimer = Timer.periodic(const Duration(minutes: 15), (timer) async {
      String currentWeatherCondition = await _weatherService.getCurrentWeatherCondition();
      String currentTimeOfDay = _getTimeOfDay();

      if (currentWeatherCondition != _lastWeatherCondition || 
          currentTimeOfDay != _lastTimeOfDay) {
        await _fetchWeatherTasks(currentWeatherCondition, currentTimeOfDay);
      }
    });
  }

  // Check if it's a new day and reset weather tasks if needed
  Future<void> _checkForDailyReset() async {
    try {
      // Get the last reset time from Firebase
      var userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(_userId)
          .get();
      
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        if (userData.containsKey('lastWeatherTaskReset')) {
          _lastReset = (userData['lastWeatherTaskReset'] as Timestamp).toDate();
        }
      }
      
      // Check if it's a new day
      DateTime now = DateTime.now();
      bool isNewDay = now.day != _lastReset.day || 
                     now.month != _lastReset.month || 
                     now.year != _lastReset.year;
      
      if (isNewDay) {
        print('New day detected, resetting weather tasks...');
        await _resetWeatherTasksForNewDay();
        
        // Reset completed tasks count for a new day
        await FirebaseFirestore.instance
            .collection('UserPlants')
            .doc(widget.plantId)
            .update({
              'completedTasks': 0,
            });
        
        setState(() {
          _completedTasks = 0;
        });
        
        // Update the reset time
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(_userId)
            .set({
              'lastWeatherTaskReset': Timestamp.now(),
            }, SetOptions(merge: true));
        
        _lastReset = now;
      }
    } catch (e) {
      print('Error checking for daily reset: $e');
    }
  }

  Future<void> _fetchWeatherTasks(String weatherCondition, String timeOfDay) async {
    // Standardize the weatherCondition to match Firebase
    // This ensures we only use: sunny, rainy, cloudy, windy
    if (!['sunny', 'rainy', 'cloudy', 'windy'].contains(weatherCondition.toLowerCase())) {
      print('Warning: Non-standard weather condition received: $weatherCondition');
      weatherCondition = 'sunny'; // Default to sunny if not a standard value
    } else {
      weatherCondition = weatherCondition.toLowerCase(); // Ensure lowercase
    }
    
    try {
      print('Fetching weather tasks with conditions:');
      print('Weather Condition: $weatherCondition');
      print('Time of Day: $timeOfDay');

      // Get available weather tasks that match the current conditions
      List<TaskModel> weatherTasks = [];
      
      // Check for tasks matching current standardized conditions
      print('Checking for tasks matching: $weatherCondition, $timeOfDay');
      var matchingTasksSnapshot = await FirebaseFirestore.instance
          .collection('WeatherTasks')
          .where('weatherCondition', isEqualTo: weatherCondition)
          .where('timeOfDay', isEqualTo: timeOfDay)
          .get();
          
      print('Found ${matchingTasksSnapshot.docs.length} matching weather tasks');
      
      // If we have matching tasks, convert them to task models
      if (matchingTasksSnapshot.docs.isNotEmpty) {
        weatherTasks = matchingTasksSnapshot.docs.map((doc) {
          var data = doc.data();
          print('Processing matching task: ${data['taskName']}');
          return TaskModel(
            taskName: data['taskName'] ?? '',
            taskDesc: data['taskDesc'] ?? '',
            isWeatherTask: true,
            weatherCondition: weatherCondition,
            timeOfDay: timeOfDay,
            taskNumber: 0, // Weather tasks don't have sequence numbers
          );
        }).toList();
      } else {
        print('No matching weather tasks found for: $weatherCondition, $timeOfDay');
      }
      
      // Get today's start and end timestamps
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // Get completed weather tasks for THIS PLANT from TaskHistory
      var completedTasksSnapshot = await FirebaseFirestore.instance
          .collection('UserPlants')
          .doc(widget.plantId)
          .collection('TaskHistory')
          .where('isWeatherTask', isEqualTo: true)
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('completedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      
      // Create a set of completed task names for quick lookup
      Set<String> completedTaskNames = completedTasksSnapshot.docs
          .map((doc) => doc.data()['taskName'] as String)
          .toSet();
      
      print('Number of completed weather tasks today for this plant: ${completedTaskNames.length}');

      // Filter out tasks that have been completed today
      weatherTasks = weatherTasks.where((task) {
        bool isCompleted = completedTaskNames.contains(task.taskName);
        if (isCompleted) {
          print('Task "${task.taskName}" is already completed today for this plant');
        }
        return !isCompleted;
      }).toList();

      print('Number of new weather tasks after filtering: ${weatherTasks.length}');

      // Get plant tasks (non-weather tasks)
      var plantTasks = _tasks.where((task) => !task.isWeatherTask).toList();
      
      // CRITICAL: Check if ALL plant tasks are completed
      bool allPlantTasksCompleted = _areAllPlantTasksCompleted();
      print('All plant tasks completed? $allPlantTasksCompleted');
      
      // Store the weather tasks but don't display them yet if plant tasks aren't completed
      setState(() {
        // Remove old weather tasks first
        _tasks.removeWhere((task) => task.isWeatherTask);
        
        // Only add weather tasks to visible list if ALL plant tasks are completed
        if (allPlantTasksCompleted || plantTasks.isEmpty) {
          // Add weather tasks to the beginning of the list
          _tasks.insertAll(0, weatherTasks);
          print('Added ${weatherTasks.length} weather tasks to visible list');
          
          // Reset current task to first weather task
          if (weatherTasks.isNotEmpty) {
            _currentTaskNumber = 1;
            print('Reset current task number to 1 to show weather task');
          }
        } else {
          // Store weather tasks at the end of the list, but they won't be displayed yet
          _tasks.addAll(weatherTasks);
          print('Stored ${weatherTasks.length} weather tasks at end of list (not displayed yet)');
        }

        // Update tracking variables
        _lastWeatherCondition = weatherCondition;
        _lastTimeOfDay = timeOfDay;
      });

      // Force UI update
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {});
        }
      });

    } catch (e) {
      print("Error fetching weather tasks: $e");
    }
  }

  void _completeTask() async {
    try {
      print('Completing task at index ${_currentTaskNumber - 1}');
      
      // Separate tasks by type
      var weatherTasks = _tasks.where((task) => task.isWeatherTask).toList();
      var plantTasks = _tasks.where((task) => !task.isWeatherTask).toList();
      
      // IMPORTANT: Determine which tasks to display based on completion status
      List<TaskModel> tasksToDisplay = [];
      bool allPlantTasksCompleted = _areAllPlantTasksCompleted();
      
      if (plantTasks.isNotEmpty) {
        // If plant tasks exist, only operate on those until they're completed
        tasksToDisplay = plantTasks;
      } else if (allPlantTasksCompleted && weatherTasks.isNotEmpty) {
        // Only show/operate on weather tasks if plant tasks are complete
        tasksToDisplay = weatherTasks;
      } else if (plantTasks.isEmpty && weatherTasks.isNotEmpty) {
        // No plant tasks, allow weather task operations
        tasksToDisplay = weatherTasks;
      }
      
      if (tasksToDisplay.isEmpty || _currentTaskNumber > tasksToDisplay.length) {
        print('No tasks available to complete');
        return;
      }
      
      var currentTask = tasksToDisplay[_currentTaskNumber - 1];
      print('Completing task: ${currentTask.taskName}, Is weather: ${currentTask.isWeatherTask}');
      
      // Save task to history with additional info
      await _addTaskToHistory(currentTask);
      print('Task added to history');

      if (currentTask.isWeatherTask) {
        print('Processing weather task completion');
        try {
          // For weather tasks, mark as completed for THIS PLANT only (not user-wide)
          await _markWeatherTaskCompletedForUser(currentTask);
          print('Weather task marked as complete for plant: ${widget.plantId}');
        } catch (weatherError) {
          print('Error marking weather task as complete: $weatherError');
          // Continue with completion even if marking fails
        }
      } else {
        // For non-weather tasks, remove from pending tasks collection
        var pendingTasksSnapshot = await FirebaseFirestore.instance
            .collection('UserPlants')
            .doc(widget.plantId)
            .collection('PendingTasks')
            .where('taskName', isEqualTo: currentTask.taskName)
            .get();
        
        for (var doc in pendingTasksSnapshot.docs) {
          await doc.reference.delete();
        }

        // Only increment completed tasks count for non-weather tasks
        // as they count toward task progress
        _completedTasks++;
        
        // Update the completed tasks count in the UserPlants document
        await FirebaseFirestore.instance
            .collection('UserPlants')
            .doc(widget.plantId)
            .update({
          'completedTasks': _completedTasks,
        });
      }

      // Remove the completed task from the list
      setState(() {
        // Remove from the appropriate list
        if (currentTask.isWeatherTask) {
          int index = _tasks.indexWhere((task) => 
              task.isWeatherTask && task.taskName == currentTask.taskName);
          if (index != -1) {
            _tasks.removeAt(index);
          }
        } else {
          int index = _tasks.indexWhere((task) => 
              !task.isWeatherTask && task.taskName == currentTask.taskName);
          if (index != -1) {
            _tasks.removeAt(index);
          }
        }
        
        print('Task removed. Remaining tasks: ${_tasks.length}');
      });

      // Don't increment task number for weather tasks
      int nextTaskNumber = _currentTaskNumber;
      if (!currentTask.isWeatherTask) {
        // Only increment task number for plant-based tasks to maintain sequence
        nextTaskNumber = _currentTaskNumber + 1;
      }
      
      // Check if we just completed the last plant task
      bool justCompletedLastPlantTask = !currentTask.isWeatherTask && 
          _completedTasks >= _totalTasks && 
          weatherTasks.isNotEmpty;
          
      if (justCompletedLastPlantTask) {
        // If we just completed the last plant task, always set to 1 to show first weather task
        nextTaskNumber = 1;
        print('Just completed last plant task, setting task number to 1 for weather tasks');
      }
      
      // Always update the currentTaskNumber in Firebase
      await FirebaseFirestore.instance
          .collection('UserPlants')
          .doc(widget.plantId)
          .update({
        'currentTaskNumber': nextTaskNumber,
      });

      if (_isFirstDay) {
        await _taskService.updateUserPlantProgress(
          widget.plantId, 
          nextTaskNumber, 
          false
        );
      }

      // Show a success animation
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Task completed!'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );

      // Show all tasks completed dialog if no more tasks
      bool noTasksRemaining = _tasks.isEmpty;
      bool noPlantTasksRemaining = !_tasks.any((task) => !task.isWeatherTask);
      bool allTasksCompleted = noTasksRemaining || 
          (_completedTasks >= _totalTasks && noPlantTasksRemaining);
          
      if (noTasksRemaining) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('All Tasks Completed'),
            content: const Text('Great job! You\'ve completed all tasks for today.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  // Don't pop the task view so user can still access history
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (justCompletedLastPlantTask) {
        // Now fetch weather tasks since we've completed all plant tasks
        print('All plant tasks completed, now showing weather tasks');
        String currentWeather = await _weatherService.getCurrentWeatherCondition();
        String currentTime = _getTimeOfDay();
        await _fetchWeatherTasks(currentWeather, currentTime);
          
        // Update UI
        setState(() {
          _currentTaskNumber = 1;
        });
      } else {
        // Always fetch new weather tasks after completing any task
        // (they will be stored but only shown when plant tasks are done)
        String currentWeather = await _weatherService.getCurrentWeatherCondition();
        String currentTime = _getTimeOfDay();
        await _fetchWeatherTasks(currentWeather, currentTime);
      }
    } catch (e) {
      print('Error in _completeTask: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing task: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
  
  // Mark a weather task as completed for THIS PLANT only (not user-wide)
  Future<void> _markWeatherTaskCompletedForUser(TaskModel task) async {
    try {
      print('Marking weather task "${task.taskName}" as completed for plant: ${widget.plantId}');
      print('Weather: ${task.weatherCondition}, Time: ${task.timeOfDay}');
      
      // Get the task ID from Firebase
      var taskQuery = await FirebaseFirestore.instance
          .collection('WeatherTasks')
          .where('taskName', isEqualTo: task.taskName)
          .get();
      
      print('Found ${taskQuery.docs.length} matching tasks in Firebase');
      
      String WeatherTasksId = taskQuery.docs.isEmpty 
          ? 'generated-${DateTime.now().millisecondsSinceEpoch}'
          : taskQuery.docs.first.id;
      
      // Add to TaskHistory collection
      await FirebaseFirestore.instance
          .collection('UserPlants')
          .doc(widget.plantId)
          .collection('TaskHistory')
          .add({
        'WeatherTasksId': WeatherTasksId,
        'taskName': task.taskName,
        'taskDesc': task.taskDesc,
        'isWeatherTask': true,
        'weatherCondition': task.weatherCondition ?? taskQuery.docs.first.data()['weatherCondition'] ?? 'unknown',
        'timeOfDay': task.timeOfDay ?? taskQuery.docs.first.data()['timeOfDay'] ?? 'unknown',
        'completedAt': FieldValue.serverTimestamp(),
      });
      
      print('Weather task marked as completed for plant: ${widget.plantId}');
    } catch (e) {
      print('Error marking weather task as completed: $e');
      rethrow;
    }
  }

Future<void> _addTaskToHistory(TaskModel task) async {
    try {
      // Add more details to the task history including date for better filtering
      Map<String, dynamic> historyData = {
        'taskName': task.taskName,
        'taskDesc': task.taskDesc,
        'isWeatherTask': task.isWeatherTask,
        'weatherCondition': task.weatherCondition,
        'timeOfDay': task.timeOfDay,
        'completedAt': FieldValue.serverTimestamp(),
      };
      
      // Add to TaskHistory collection
      await FirebaseFirestore.instance
          .collection('UserPlants')
          .doc(widget.plantId)
          .collection('TaskHistory')
          .add(historyData);
      
      print('Task "${task.taskName}" added to history for plant ${widget.plantId}');
    } catch (e) {
      print('Error adding task to history: $e');
      rethrow; // Rethrow to handle in the calling method
    }
  }

  Future<void> _resetWeatherTasksForNewDay() async {
    try {
      // No need to clear any collection as we're using TaskHistory
      // The daily check in _fetchWeatherTasks will handle filtering tasks by date
      print('Weather tasks will be filtered by date in TaskHistory');
    } catch (e) {
      print("Error in weather task reset: $e");
    }
  }

  // New method to validate and fix task counts
  Future<void> _validateTaskCounts() async {
    try {
      // First, make sure _totalTasks is at least the count of non-weather tasks plus any weather tasks
      int nonWeatherTasksCount = _tasks.where((task) => !task.isWeatherTask).length;
      int weatherTasksCount = _tasks.where((task) => task.isWeatherTask).length;
      
      if (_totalTasks < nonWeatherTasksCount) {
        _totalTasks = nonWeatherTasksCount;
        print('Corrected _totalTasks to $nonWeatherTasksCount based on actual non-weather tasks');
      }
      
      // Make sure completed tasks don't exceed total tasks (excluding weather tasks)
      if (_completedTasks > _totalTasks) {
        print('Fixing invalid completedTasks value: $_completedTasks > $_totalTasks');
        _completedTasks = _totalTasks;
        
        // Update the corrected value in Firebase
        await FirebaseFirestore.instance
            .collection('UserPlants')
            .doc(widget.plantId)
            .update({
          'completedTasks': _completedTasks,
        });
        print('Updated completedTasks in Firebase to $_completedTasks');
      }
      
      // Reset currentTaskNumber if it's incorrect
      if (_currentTaskNumber > _totalTasks && _completedTasks < _totalTasks) {
        // This is a case where task number is ahead but tasks aren't actually completed
        // Reset to a valid task number
        _currentTaskNumber = math.min(_completedTasks + 1, _totalTasks);
        
        // Update in Firebase to correct the value
        await FirebaseFirestore.instance
            .collection('UserPlants')
            .doc(widget.plantId)
            .update({
          'currentTaskNumber': _currentTaskNumber,
        });
        print('Corrected _currentTaskNumber to $_currentTaskNumber');
      }
      
      print('Task counts after validation - Total: $_totalTasks, Completed: $_completedTasks, Current: $_currentTaskNumber');
    } catch (e) {
      print('Error validating task counts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade50,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                )
              : _errorMessage.isNotEmpty
                  ? _buildErrorScreen()
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildTaskScreen(),
                    ),
                  ),
                ),
              );
  }
  
  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 70,
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Return to Garden'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
          ),
        ],
      ),
      ),
    );
  }
  
  Widget _buildTaskScreen() {
    print('Building task view. Tasks count: ${_tasks.length}, Current task number: $_currentTaskNumber');
    
    // Separate tasks by type
    var weatherTasks = _tasks.where((task) => task.isWeatherTask).toList();
    var plantTasks = _tasks.where((task) => !task.isWeatherTask).toList();
    
    print('Weather tasks: ${weatherTasks.length}, Plant tasks: ${plantTasks.length}');
    
    // IMPORTANT: Only display weather tasks if ALL plant tasks are completed
    List<TaskModel> tasksToDisplay = [];
    bool allPlantTasksCompleted = _areAllPlantTasksCompleted();
    
    if (plantTasks.isNotEmpty) {
      // If plant tasks exist, show only those until they're all completed
      tasksToDisplay = plantTasks;
      print('Displaying ${plantTasks.length} plant tasks');
    } else if (allPlantTasksCompleted && weatherTasks.isNotEmpty) {
      // Only show weather tasks if plant tasks are complete
      tasksToDisplay = weatherTasks;
      print('Plant tasks completed, displaying ${weatherTasks.length} weather tasks');
    } else if (plantTasks.isEmpty && weatherTasks.isNotEmpty) {
      // No plant tasks, show weather tasks
      tasksToDisplay = weatherTasks;
      print('No plant tasks, displaying ${weatherTasks.length} weather tasks');
    }
    
    // Empty tasks could mean either all tasks completed or no tasks available
    if (tasksToDisplay.isEmpty) {
      // Only show completion screen if we've actually completed tasks
      if (_completedTasks >= _totalTasks && _totalTasks > 0) {
        return _buildAllTasksCompletedState();
      } else {
        // Otherwise show empty state (no tasks available)
        return _buildEmptyTaskState();
      }
    }

    // This check is now more accurate - only show completed state if we've actually done all tasks
    // AND we don't have any weather tasks to show
    if (_completedTasks >= _totalTasks && _totalTasks > 0 && weatherTasks.isEmpty) {
      return _buildAllTasksCompletedState();
    }

    // Ensure we don't get index out of bounds errors
    int safeIndex = math.min(_currentTaskNumber - 1, tasksToDisplay.length - 1);
    if (safeIndex < 0) safeIndex = 0;
    
    var currentTask = tasksToDisplay[safeIndex];
    print('Selected current task: ${currentTask.taskName}, Is Weather Task: ${currentTask.isWeatherTask}');
    
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
                        const SizedBox(height: 20),
                        _buildProgressIndicator(),
                        const SizedBox(height: 30),
                        Expanded(
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: _buildTaskCard(currentTask),
                          ),
                        ),
                        const SizedBox(height: 30),
        _buildActionButtons(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF2E7D32),
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
                  Text(
                    widget.commonName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          Text(
                    widget.growthType == 'FromSeed' ? 'From Seed' : 'From Plant',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyGardenHistory(
                    plantId: widget.plantId,
                    plantName: widget.commonName,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Color(0xFF2E7D32),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressIndicator() {
    // Calculate progress based on completed tasks
    // Don't count weather tasks in the progress calculation
    double progress = 0.0;
    if (_totalTasks > 0) {
      progress = _completedTasks / _totalTasks;
    }
    
    // If all tasks are completed, show full progress
    if (_tasks.isEmpty || _completedTasks >= _totalTasks) {
      progress = 1.0;
    }
    
    // Keep progress in valid range
    progress = progress.clamp(0.0, 1.0);
    int percent = (progress * 100).toInt();
    
    // Debug task counts
    print('Progress indicator - Completed: $_completedTasks, Total: $_totalTasks');
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      width: MediaQuery.of(context).size.width * 0.7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Stack(
            children: [
              // Background
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Progress indicator
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade700],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          
          // Spacing
          const SizedBox(height: 8),
          
          // Compact text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Current progress as fraction
              Text(
                "$_completedTasks/$_totalTasks",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
              // Percentage
              Text(
                "$percent%",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: task.isWeatherTask 
                ? [Colors.blue.shade50, Colors.lightBlue.shade100]
                : [Colors.white, Colors.green.shade50],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Task type indicator (weather or regular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: task.isWeatherTask ? Colors.blue.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    task.isWeatherTask ? Icons.cloud : Icons.eco,
                    size: 16,
                    color: task.isWeatherTask ? Colors.blue.shade800 : Colors.green.shade800,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    task.isWeatherTask ? 'Weather Task' : 'Care Task',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: task.isWeatherTask ? Colors.blue.shade800 : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Task icon
            if (_plantImageUrl != null && !task.isWeatherTask)
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  image: DecorationImage(
                    image: NetworkImage(_plantImageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: task.isWeatherTask ? Colors.blue.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  task.isWeatherTask 
                      ? (task.taskName.toLowerCase().contains('water') 
                          ? Icons.water_drop
                          : Icons.cloud)
                      : Icons.spa,
                  size: 50,
                  color: task.isWeatherTask ? Colors.blue.shade700 : Colors.green.shade700,
                ),
              ),
              
            const SizedBox(height: 24),
            
            // Task name
            Text(
              task.taskName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: task.isWeatherTask ? Colors.blue.shade800 : const Color(0xFF2E7D32),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            // Task description
            Text(
              task.taskDesc,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
      children: [
          Expanded(
            child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: const Text(
                'Skip For Now',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
          onPressed: _completeTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: const Text(
                'Mark Complete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyTaskState() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 70,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'No Tasks Available',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'There are no tasks available for this plant at the moment.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Return to Garden'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAllTasksCompletedState() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: Icon(
                      Icons.celebration,
                      size: 70,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'All Tasks Completed!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Great job! You\'ve completed all tasks for this plant today.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  _buildProgressIndicator(),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MyGardenHistory(
                                plantId: widget.plantId,
                                plantName: widget.commonName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: const Text('View History'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        ),
                        child: const Text(
                          'Return to Garden',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Additional function to check if a task exists in history
  Future<bool> _isTaskInHistory(String taskName) async {
    try {
      // Get today's start and end timestamps
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      // Check if the task exists in history for today using completedAt
      var historySnapshot = await FirebaseFirestore.instance
          .collection('UserPlants')
          .doc(widget.plantId)
          .collection('TaskHistory')
          .where('taskName', isEqualTo: taskName)
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('completedAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();
      
      return historySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking task history: $e');
      return false;
    }
  }
}