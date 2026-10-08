import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/weather_data.dart';

class WeatherService {
  static const _geocodingUrl = 'https://geocoding-api.open-meteo.com/v1/search';
  static const _weatherUrl = 'https://api.open-meteo.com/v1/forecast';

  /// 反向地理编码（坐标 → 地名）。免费、无需 Key，`localityLanguage=zh` 出中文。
  static const _reverseUrl =
      'https://api.bigdatacloud.net/data/reverse-geocode-client';
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

  // ── 写日记时的现场快照 ──

  /// 采集一次「写这篇日记时」的天气 + 地点。
  ///
  /// ★ 刻意**不主动请求定位权限**（只 `checkPermission`）—— 用户点「保存」
  /// 时突然弹系统权限框太突兀，也说不清为什么写日记要定位。
  /// 没授权就直接返回 null，由调用方决定「这一条不加」。
  static Future<DiarySnapshot?> captureForDiary() async {
    try {
      final permission = await Geolocator.checkPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );

      // 两个请求互不依赖：先把两个 Future 都启动起来再 await，
      // 总耗时 = max(两者) 而不是相加。（两个方法内部各自 try-catch，
      // 不会抛错，所以不需要担心 Future.wait 的「一个炸全都炸」。）
      final weatherFuture = _fetchWeather(
        lat: position.latitude,
        lon: position.longitude,
      );
      final placeFuture = _reverseGeocode(
        position.latitude,
        position.longitude,
      );
      final weather = await weatherFuture;
      final place = await placeFuture;

      if (weather == null && place.isEmpty) return null;
      return DiarySnapshot(
        weather: weather == null
            ? ''
            : '${weather.description} ${weather.tempDisplay}',
        location: place,
      );
    } catch (e) {
      return null;
    }
  }

  /// 坐标 → 中文地名（省 + 市 + 区），失败返回空串。
  ///
  /// 用 BigDataCloud 的 `reverse-geocode-client`：**免费、无需 Key**，
  /// 实测深圳坐标 → `广东省 / 深圳市 / 福田区`。
  ///
  /// 换不掉的理由：Open-Meteo 的 geocoding 只有**正向**（名字 → 坐标），
  /// 做不了这件事；Nominatim 实测在国内返回空。
  static Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final url = '$_reverseUrl?latitude=$lat&longitude=$lon'
          '&localityLanguage=zh';
      final resp = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 8),
      );
      if (resp.statusCode != 200) return '';

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      // 由粗到细拼接。直辖市的 principalSubdivision 与 city 常常同名
      // （如「北京市 / 北京市」），必须去重，否则会拼成「北京市北京市」。
      final raw = <String>[
        (json['principalSubdivision'] as String?) ?? '',
        (json['city'] as String?) ?? '',
        (json['locality'] as String?) ?? '',
      ].map((s) => s.trim()).where((s) => s.isNotEmpty);

      final unique = <String>[];
      for (final part in raw) {
        if (!unique.contains(part)) unique.add(part);
      }
      return unique.join();
    } catch (e) {
      return '';
    }
  }
}

/// 写日记时采集到的「现场快照」。
///
/// 两个字段都可能为空串（天气接口挂了 / 反查地名失败），
/// 由 UI 决定要不要显示 —— 空就整条不画。
class DiarySnapshot {
  final String weather;
  final String location;

  const DiarySnapshot({required this.weather, required this.location});

  bool get isEmpty => weather.isEmpty && location.isEmpty;
}
