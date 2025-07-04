// FILEPATH: lib/src/services/task_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/task_model.dart';
import 'weather_service.dart';

class TaskService {
  final WeatherService _weatherService;
  final FirebaseFirestore _firestore;

  TaskService(this._weatherService, this._firestore);

  Future<List<TaskModel>> fetchInitialTasks({
    required String libraryPlantId, 
    required String growthType, 
    required bool isFirstDay
  }) async {
    List<TaskModel> tasks = [];

    if (isFirstDay) {
      var plantTasksSnapshot = await _firestore
          .collection('PlantLibrary')
          .doc(libraryPlantId)
          .collection('growthType')
          .doc(growthType)
          .collection('tasks')
          .get();

      tasks = plantTasksSnapshot.docs.map((doc) {
        var data = doc.data();
        // Extract the numeric part of the task ID
        int taskNumber;
        try {
          // First, attempt to directly parse the numeric part of "task1", "task2", etc.
          String numericPart = doc.id.replaceAll('task', '');
          taskNumber = int.parse(numericPart);
          print('Successfully parsed task number: $taskNumber from ID: ${doc.id}');
        } catch (e) {
          // If parsing fails, check if there's any other usable numeric information
          if (data.containsKey('taskNumber')) {
            taskNumber = data['taskNumber'] as int? ?? 0;
            print('Using taskNumber from data: $taskNumber for ID: ${doc.id}');
          } else {
            // Fallback to a default value and log the error
            taskNumber = 0;
            print('ERROR: Failed to parse task number from ID: ${doc.id}. Using default 0.');
          }
        }
        return TaskModel.fromMap({...data, 'taskNumber': taskNumber});
      }).toList();

      tasks.sort((a, b) => a.taskNumber.compareTo(b.taskNumber));
      
      print('Task order after sorting:');
      for (var task in tasks) {
        print('Task ${task.taskNumber}: ${task.taskName}');
      }
    }

    return tasks;
  }

  Future<List<TaskModel>> fetchWeatherTasks(
    String weatherCondition,
    String timeOfDay
  ) async {
    print('TaskService: Fetching weather tasks with conditions:');
    print('Weather Condition: $weatherCondition');
    print('Time of Day: $timeOfDay');
    
    // Try exact match first
    var weatherTasksSnapshot = await _firestore
        .collection('WeatherTasks')
        .where('weatherCondition', isEqualTo: weatherCondition)
        .where('timeOfDay', isEqualTo: timeOfDay)
        .get();

    print('TaskService: Found ${weatherTasksSnapshot.docs.length} weather tasks with exact match');
    
    // If no results, try with lowercase
    if (weatherTasksSnapshot.docs.isEmpty) {
      String lowerWeatherCondition = weatherCondition.toLowerCase();
      print('TaskService: Trying with lowercase: $lowerWeatherCondition');
      
      weatherTasksSnapshot = await _firestore
          .collection('WeatherTasks')
          .where('weatherCondition', isEqualTo: lowerWeatherCondition)
          .where('timeOfDay', isEqualTo: timeOfDay)
          .get();
          
      print('TaskService: Found ${weatherTasksSnapshot.docs.length} weather tasks with lowercase');
    }
    
    // If still no results, try just matching on timeOfDay as fallback
    if (weatherTasksSnapshot.docs.isEmpty) {
      print('TaskService: No specific weather tasks found, checking for generic time-of-day tasks');
      
      // Try to find tasks that don't specify a weather condition but match the time of day
      weatherTasksSnapshot = await _firestore
          .collection('WeatherTasks')
          .where('timeOfDay', isEqualTo: timeOfDay)
          .get();
          
      // Filter client-side for docs that don't have weatherCondition or have empty weatherCondition
      var filteredDocs = weatherTasksSnapshot.docs.where((doc) {
        var data = doc.data();
        return !data.containsKey('weatherCondition') || 
                data['weatherCondition'] == null || 
                data['weatherCondition'] == '';
      }).toList();
      
      // Since we can't create a new QuerySnapshot directly, we'll work with the filtered docs
      if (filteredDocs.isNotEmpty) {
        print('TaskService: Found ${filteredDocs.length} generic time-based tasks');
        
        // Return early using just these filtered docs
        return filteredDocs.map((doc) {
          var data = doc.data();
          print('TaskService: Found task "${data['taskName']}" for time: ${data['timeOfDay']} (no weather condition)');
          return TaskModel.fromMap({
            ...data, 
            'isWeatherTask': true,
            'taskNumber': 0
          });
        }).toList();
      }
      
      print('TaskService: Found 0 generic time-based tasks');
    }
    
    // Print each found task for debugging
    for (var doc in weatherTasksSnapshot.docs) {
      var data = doc.data();
      print('TaskService: Found task "${data['taskName']}" for weather: ${data['weatherCondition']}, time: ${data['timeOfDay']}');
    }
    
    return weatherTasksSnapshot.docs
        .map((doc) {
          var data = doc.data();
          return TaskModel.fromMap({
            ...data, 
            'isWeatherTask': true,
            'taskNumber': 0 // Weather tasks don't have sequence numbers
          });
        })
        .toList();
  }

  Future<int> fetchTotalTasks({
    required String libraryPlantId, 
    required String growthType
  }) async {
    var tasksSnapshot = await _firestore
        .collection('PlantLibrary')
        .doc(libraryPlantId)
        .collection('growthType')
        .doc(growthType)
        .collection('tasks')
        .get();
    
    return tasksSnapshot.docs.length;
  }

  Future<void> updateUserPlantProgress(
    String plantId, 
    int currentTaskNumber, 
    bool isFirstDay
  ) async {
    await _firestore
        .collection('UserPlants')
        .doc(plantId)
        .update({
      'currentTaskNumber': currentTaskNumber, 
      'isFirstDay': isFirstDay
    });
  }

  Future<void> updateWeatherTaskCompletion(TaskModel task) async {
    // Update the task in your database to mark it as completed for today
    await _firestore
        .collection('WeatherTasks')
        .where('taskName', isEqualTo: task.taskName)
        .where('weatherCondition', isEqualTo: task.weatherCondition)
        .where('timeOfDay', isEqualTo: task.timeOfDay)
        .get()
        .then((querySnapshot) {
      for (var doc in querySnapshot.docs) {
        doc.reference.update({'completedToday': true});
      }
    });
  }

  Future<void> resetWeatherTasksCompletion() async {
    // Reset the completedToday status for all weather tasks in your database
    var batch = _firestore.batch();
    var weatherTasksSnapshot = await _firestore.collection('WeatherTasks').get();

    for (var doc in weatherTasksSnapshot.docs) {
      batch.update(doc.reference, {'completedToday': false});
    }

    await batch.commit();
  }

  Future<void> addTaskToHistory(String plantId, TaskModel task) async {
    await _firestore
        .collection('UserPlants')
        .doc(plantId)
        .collection('TaskHistory')
        .add({
      'taskName': task.taskName,
      'completedAt': FieldValue.serverTimestamp(),
      'isWeatherTask': task.isWeatherTask,
      'weatherCondition': task.weatherCondition,
      'timeOfDay': task.timeOfDay,
    });
  }
}