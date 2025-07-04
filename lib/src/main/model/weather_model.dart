// FILEPATH: c:/Users/thu/OneDrive/Documents/FYP/MyGd_app/mygd_frontend/lib/src/main/model/weather_model.dart

class Weather {
  final String cityName;
  final double temperature;
  final String condition;

  Weather({
    required this.cityName,
    required this.temperature,
    required this.condition,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      cityName: json['name'],
      temperature: json['main']['temp'].toDouble(),
      condition: json['weather'][0]['main'],
    );
  }
}