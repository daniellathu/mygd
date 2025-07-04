// FILEPATH: c:/Users/thu/OneDrive/Documents/FYP/MyGd_app/mygd_frontend/lib/src/screens/mygarden_history.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MyGardenHistory extends StatelessWidget {
  final String plantId;
  final String plantName;

  const MyGardenHistory({super.key, required this.plantId, required this.plantName});

  Future<List<Map<String, dynamic>>> _fetchPlantTaskHistory() async {
    try {
      var taskHistorySnapshot = await FirebaseFirestore.instance
          .collection('UserPlants')
          .doc(plantId)
          .collection('TaskHistory')
          .orderBy('completedAt', descending: true)
          .limit(100) // Limit to 100 most recent tasks for performance
          .get();

      return taskHistorySnapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      print('Error fetching task history: $e');
      return [];
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
              const Color(0xFF348F50),
              const Color(0xFF56B4D3).withOpacity(0.9),
              Colors.white,
            ],
            stops: const [0.0, 0.3, 0.5],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Task History",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            plantName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // History content
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchPlantTaskHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF348F50)),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade400,
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Error loading task history",
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Please try again later",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      var taskHistory = snapshot.data ?? [];
                      
                      if (taskHistory.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                color: Colors.grey.shade400,
                                size: 70,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No task history yet",
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Complete tasks to see your history here",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }
                      
                      // Group tasks by date
                      Map<String, List<Map<String, dynamic>>> groupedTasks = {};
                      for (var task in taskHistory) {
                        Timestamp timestamp = task['completedAt'] as Timestamp;
                        DateTime date = timestamp.toDate();
                        String dateKey = DateFormat('yyyy-MM-dd').format(date);
                        
                        if (!groupedTasks.containsKey(dateKey)) {
                          groupedTasks[dateKey] = [];
                        }
                        groupedTasks[dateKey]!.add(task);
                      }
                      
                      List<String> sortedDates = groupedTasks.keys.toList()
                        ..sort((a, b) => b.compareTo(a));
                      
                      return Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: ListView.builder(
                          itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                            String dateKey = sortedDates[index];
                            List<Map<String, dynamic>> tasksForDate = groupedTasks[dateKey]!;
                            DateTime date = DateTime.parse(dateKey);
                            String formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(date);
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ...tasksForDate.map((task) {
                                  Timestamp timestamp = task['completedAt'] as Timestamp;
                                  DateTime taskTime = timestamp.toDate();
                                  String formattedTime = DateFormat('h:mm a').format(taskTime);
                                  
                                  bool isWeatherTask = task['isWeatherTask'] as bool? ?? false;
                                  String? weatherCondition = task['weatherCondition'] as String?;
                                  String? timeOfDay = task['timeOfDay'] as String?;
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: isWeatherTask 
                                            ? _getTaskColor(true, weatherCondition).withOpacity(0.3) 
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: _getTaskColor(isWeatherTask, weatherCondition).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _getTaskIcon(task['taskName'], isWeatherTask, weatherCondition),
                                            color: _getTaskColor(isWeatherTask, weatherCondition),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                task['taskName'],
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              if (task['taskDesc'] != null && task['taskDesc'].toString().isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    task['taskDesc'],
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              if (isWeatherTask && (weatherCondition != null || timeOfDay != null))
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Row(
                                                    children: [
                                                      if (weatherCondition != null)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          margin: const EdgeInsets.only(right: 8),
                                                          decoration: BoxDecoration(
                                                            color: _getTaskColor(true, weatherCondition).withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Text(
                                                            weatherCondition.capitalize(),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: _getTaskColor(true, weatherCondition),
                                                            ),
                                                          ),
                                                        ),
                                                      if (timeOfDay != null)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.purple.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Text(
                                                            timeOfDay.capitalize(),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.purple.shade700,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          formattedTime,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                  ),
                );
              },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get icon for task type
  IconData _getTaskIcon(String taskName, [bool isWeatherTask = false, String? weatherCondition]) {
    if (isWeatherTask) {
      if (weatherCondition != null) {
        switch (weatherCondition.toLowerCase()) {
          case 'sunny':
            return Icons.wb_sunny;
          case 'rainy':
            return Icons.water_drop;
          case 'cloudy':
            return Icons.cloud;
          case 'windy':
            return Icons.air;
          default:
            return Icons.wb_sunny;
        }
      }
      return Icons.cloud;
    }
    
    taskName = taskName.toLowerCase();
    if (taskName.contains('water')) {
      return Icons.water_drop;
    } else if (taskName.contains('fertilize')) {
      return Icons.eco;
    } else if (taskName.contains('prune')) {
      return Icons.content_cut;
    } else if (taskName.contains('harvest')) {
      return Icons.shopping_basket;
    } else if (taskName.contains('shade')) {
      return Icons.umbrella;
    } else if (taskName.contains('protect')) {
      return Icons.shield;
    } else if (taskName.contains('monitor')) {
      return Icons.visibility;
    } else if (taskName.contains('check')) {
      return Icons.check_circle;
    } else if (taskName.contains('move')) {
      return Icons.swap_horiz;
    } else if (taskName.contains('secure')) {
      return Icons.lock;
    } else {
      return Icons.yard;
    }
  }

  // Helper method to get color for task type
  Color _getTaskColor(bool isWeatherTask, [String? weatherCondition]) {
    if (isWeatherTask) {
      if (weatherCondition != null) {
        switch (weatherCondition.toLowerCase()) {
          case 'sunny':
            return Colors.orange;
          case 'rainy':
            return Colors.blue;
          case 'cloudy':
            return Colors.blueGrey;
          case 'windy':
            return Colors.teal;
          default:
            return Colors.blue;
        }
      }
      return Colors.blue;
    }
    return const Color(0xFF348F50); // Default plant task color
  }
}

// Extension to capitalize first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}