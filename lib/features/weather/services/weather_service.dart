import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/weather_data.dart';

class WeatherService {
  static const _geocodingUrl = 'https://geocoding-api.open-meteo.com/v1/search';
  static const _weatherUrl = 'https://api.open-meteo.com/v1/forecast';
  static const _cacheKey = 'weather_cache';
  static const _lastCityKey = 'last_city';

  /// Get current weather using device location
  static Future<WeatherData?> getCurrentWeather() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return null;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return await _fetchWeather(
        lat: position.latitude,
        lon: position.longitude,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get weather by city name using Open-Meteo geocoding
  static Future<WeatherData?> getWeatherByCity(String city) async {
    try {
      // Geocode city name → coordinates
      final geoUrl = '$_geocodingUrl?name=${Uri.encodeComponent(city)}&count=1&language=zh';
      final geoResp = await http.get(Uri.parse(geoUrl)).timeout(
        const Duration(seconds: 8),
      );

      if (geoResp.statusCode != 200) return null;

      final geoJson = jsonDecode(geoResp.body);
      final results = geoJson['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final lat = (results[0]['latitude'] as num).toDouble();
      final lon = (results[0]['longitude'] as num).toDouble();
      final resolvedName = results[0]['name'] as String? ?? city;

      return await _fetchWeather(lat: lat, lon: lon, cityName: resolvedName);
    } catch (e) {
      return null;
    }
  }

  /// Internal: fetch weather from Open-Meteo API
  static Future<WeatherData?> _fetchWeather({
    required double lat,
    required double lon,
    String? cityName,
  }) async {
    final url =
        '$_weatherUrl?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
        '&timezone=auto';

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 8),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final data = WeatherData.fromOpenMeteo(json, cityName: cityName ?? '');
      await _cacheWeather(data);

      if (data.cityName.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastCityKey, data.cityName);
      }

      return data;
    }

    return null;
  }

  /// Get cached weather data
  static Future<WeatherData?> getCachedWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null) return null;

      final json = jsonDecode(cached);
      final data = WeatherData.fromJson(json);

      if (DateTime.now().difference(data.timestamp).inHours > 24) {
        return null;
      }

      return data;
    } catch (e) {
      return null;
    }
  }

  /// Cache weather data
  static Future<void> _cacheWeather(WeatherData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Get the last known city name
  static Future<String?> getLastCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastCityKey);
  }

  /// Full fallback strategy: location → last city → cache → null
  static Future<WeatherData?> getWeatherWithFallback() async {
    var weather = await getCurrentWeather();
    if (weather != null) return weather;

    final lastCity = await getLastCity();
    if (lastCity != null) {
      weather = await getWeatherByCity(lastCity);
      if (weather != null) return weather;
    }

    weather = await getCachedWeather();
    return weather;
  }
}
