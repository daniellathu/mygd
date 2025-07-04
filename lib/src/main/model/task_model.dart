// FILEPATH: lib/src/models/task_model.dart

class TaskModel {
  final String taskName;
  final String taskDesc;
  final int taskNumber;
  final bool isWeatherTask;
  final String? weatherCondition;
  final String? timeOfDay;
  bool completedToday;

  TaskModel({
    required this.taskName,
    required this.taskDesc,
    this.taskNumber = 0,
    this.isWeatherTask = false,
    this.weatherCondition,
    this.timeOfDay,
    this.completedToday = false,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      taskName: map['taskName'] ?? '',
      taskDesc: map['taskDesc'] ?? '',
      taskNumber: map['taskNumber'] ?? 0,
      isWeatherTask: map['isWeatherTask'] ?? false,
      weatherCondition: map['weatherCondition'],
      timeOfDay: map['timeOfDay'],
      completedToday: map['completedToday'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskName': taskName,
      'taskDesc': taskDesc,
      'taskNumber': taskNumber,
      'isWeatherTask': isWeatherTask,
      'weatherCondition': weatherCondition,
      'timeOfDay': timeOfDay,
      'completedToday': completedToday,
    };
  }
}