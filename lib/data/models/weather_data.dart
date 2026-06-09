enum WeatherCategory { clear, clouds, rain, drizzle, thunderstorm, snow, atmosphere }

/// Map WMO weather codes to internal weather IDs
/// (preserves existing WeatherCategory logic based on ID ranges)
int _wmoToWeatherId(int wmo) {
  // Thunderstorm
  if (wmo >= 95 && wmo <= 99) return 200;
  // Drizzle
  if (wmo >= 51 && wmo <= 57) return 300;
  // Rain
  if (wmo >= 61 && wmo <= 67) return 500;
  // Snow
  if (wmo >= 71 && wmo <= 77) return 600;
  // Fog / mist / haze
  if (wmo >= 45 && wmo <= 48) return 741;
  // Clear sky
  if (wmo == 0) return 800;
  // Partly cloudy / overcast
  if (wmo >= 1 && wmo <= 3) return 802;
  return 800;
}

/// Chinese description for WMO weather codes
String _wmoDescription(int wmo) {
  if (wmo == 0) return '晴';
  if (wmo == 1) return '大部晴朗';
  if (wmo == 2) return '局部多云';
  if (wmo == 3) return '多云';
  if (wmo == 45 || wmo == 48) return '雾';
  if (wmo >= 51 && wmo <= 55) return '毛毛雨';
  if (wmo == 56 || wmo == 57) return '冻毛毛雨';
  if (wmo >= 61 && wmo <= 63) return '雨';
  if (wmo == 64 || wmo == 65) return '大雨';
  if (wmo == 66 || wmo == 67) return '冻雨';
  if (wmo >= 71 && wmo <= 75) return '雪';
  if (wmo == 77) return '雪粒';
  if (wmo == 80 || wmo == 81) return '阵雨';
  if (wmo == 82) return '暴雨';
  if (wmo == 85 || wmo == 86) return '阵雪';
  if (wmo == 95) return '雷暴';
  if (wmo == 96 || wmo == 99) return '雷暴伴冰雹';
  return '未知';
}

class WeatherData {
  final String cityName;
  final double temperature;
  final String description;
  final int weatherCode; // WMO weather code
  final double humidity;
  final double windSpeed;
  final DateTime timestamp;

  const WeatherData({
    required this.cityName,
    required this.temperature,
    required this.description,
    required this.weatherCode,
    required this.humidity,
    required this.windSpeed,
    required this.timestamp,
  });

  /// Internal weather ID derived from WMO code (for category mapping)
  int get weatherId => _wmoToWeatherId(weatherCode);

  WeatherCategory get category {
    final id = weatherId;
    if (id >= 200 && id < 300) return WeatherCategory.thunderstorm;
    if (id >= 300 && id < 400) return WeatherCategory.drizzle;
    if (id >= 500 && id < 600) return WeatherCategory.rain;
    if (id >= 600 && id < 700) return WeatherCategory.snow;
    if (id >= 700 && id < 800) return WeatherCategory.atmosphere;
    if (id == 800) return WeatherCategory.clear;
    return WeatherCategory.clouds;
  }

  /// Temperature rounded to integer
  String get tempDisplay => '${temperature.round()}°C';

  /// Chinese weather emoji
  String get emoji {
    switch (category) {
      case WeatherCategory.clear:
        return '☀️';
      case WeatherCategory.clouds:
        return '☁️';
      case WeatherCategory.rain:
        return '🌧️';
      case WeatherCategory.drizzle:
        return '🌦️';
      case WeatherCategory.thunderstorm:
        return '⛈️';
      case WeatherCategory.snow:
        return '❄️';
      case WeatherCategory.atmosphere:
        return '🌫️';
    }
  }

  /// Parse from Open-Meteo current weather response
  factory WeatherData.fromOpenMeteo(Map<String, dynamic> json, {String cityName = ''}) {
    final current = json['current'] as Map<String, dynamic>;
    final wmo = (current['weather_code'] as num).toInt();
    return WeatherData(
      cityName: cityName,
      temperature: (current['temperature_2m'] as num).toDouble(),
      description: _wmoDescription(wmo),
      weatherCode: wmo,
      humidity: (current['relative_humidity_2m'] as num).toDouble(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cityName': cityName,
      'temperature': temperature,
      'description': description,
      'weatherCode': weatherCode,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      cityName: json['cityName'] ?? '',
      temperature: (json['temperature'] as num).toDouble(),
      description: json['description'] ?? '',
      weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
      humidity: (json['humidity'] as num).toDouble(),
      windSpeed: (json['windSpeed'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  /// Check if cached data is still valid (within 30 minutes)
  bool get isExpired {
    return DateTime.now().difference(timestamp).inMinutes > 30;
  }
}
