// FILEPATH: c:/Users/thu/OneDrive/Documents/FYP/MyGd_app/mygd_frontend/lib/src/main/services/weather_service.dart

import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../model/weather_model.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  static const BASE_URL = 'https://api.openweathermap.org/data/2.5/weather';
  final String apiKey;

  WeatherService(this.apiKey);

  Future<Weather> getWeather(String cityName) async {
    final response = await http.get(Uri.parse('$BASE_URL?q=$cityName&appid=$apiKey&units=metric'));

    if (response.statusCode == 200) {
      return Weather.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load weather data');
    }
  }

  Future<String> getCurrentCity() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
    );
    
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude
    );

    String? city = placemarks[0].locality;

    return city ?? "";
  }

  String interpretWeatherCondition(Weather weather) {
    String condition = weather.condition.toLowerCase();
    
    if (condition.contains('clear') || condition.contains('sun')) {
      return 'sunny';
    } else if (condition.contains('rain') || condition.contains('drizzle')) {
      return 'rainy';
    } else if (condition.contains('cloud')) {
      return 'cloudy';
    } else if (condition.contains('thunderstorm') || condition.contains('storm')) {
      return 'stormy';
    } else if (condition.contains('haze') || condition.contains('mist') || condition.contains('fog')) {
      return 'foggy';
    } else if (condition.contains('wind') || condition.contains('gale')) {
      return 'windy';
    } else {
      return 'sunny';
    }
  }

  Future<String> getCurrentWeatherCondition() async {
    try {
      String city = await getCurrentCity();
      print('WeatherService: Getting weather for city: $city');
      
      Weather weather = await getWeather(city);
      print('WeatherService: Raw weather condition from API: "${weather.condition}"');
      
      String interpretedCondition = interpretWeatherCondition(weather);
      print('WeatherService: Interpreted weather condition: "$interpretedCondition"');
      
      return interpretedCondition;
    } catch (e) {
      print('Error getting current weather condition: $e');
      return 'sunny';
    }
  }

  Future<Map<String, dynamic>> getWeatherByCoordinates(double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String weatherMain = 'Unknown';
        double temp = 0;
        
        if (data['weather'] != null && data['weather'].length > 0) {
          weatherMain = data['weather'][0]['main'];
        }
        
        if (data['main'] != null && data['main']['temp'] != null) {
          temp = data['main']['temp'].toDouble();
        }
        
        return {
          'main': weatherMain,
          'temp': temp,
        };
      }
      return {
        'main': 'Unknown',
        'temp': 0,
      };
    } catch (e) {
      print('Error getting weather by coordinates: $e');
      return {
        'main': 'Unknown',
        'temp': 0,
      };
    }
  }
}