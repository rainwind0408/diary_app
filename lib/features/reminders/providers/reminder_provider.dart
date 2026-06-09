import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  bool _enabled = false;
  int _hour = 21;
  int _minute = 0;
  String _message = '记录今天的美好瞬间吧';

  static const _keyEnabled = 'reminder_enabled';
  static const _keyHour = 'reminder_hour';
  static const _keyMinute = 'reminder_minute';
  static const _keyMessage = 'reminder_message';

  bool get enabled => _enabled;
  int get hour => _hour;
  int get minute => _minute;
  String get message => _message;

  String get timeDisplay =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? false;
    _hour = prefs.getInt(_keyHour) ?? 21;
    _minute = prefs.getInt(_keyMinute) ?? 0;
    _message = prefs.getString(_keyMessage) ?? '记录今天的美好瞬间吧';
    notifyListeners();

    // 如果已启用提醒，重新安排通知（应用重启后通知会丢失）
    if (_enabled) {
      await NotificationService.scheduleDailyReminder(
        hour: _hour,
        minute: _minute,
        message: _message,
      );
    }
  }

  /// 返回 true 表示设置成功，false 表示权限被拒绝
  Future<bool> setEnabled(bool value) async {
    if (value) {
      // 先请求权限
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        // 权限被拒绝，不启用
        return false;
      }
    }

    _enabled = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);

    if (value) {
      await NotificationService.scheduleDailyReminder(
        hour: _hour,
        minute: _minute,
        message: _message,
      );
    } else {
      await NotificationService.cancelReminder();
    }

    return true;
  }

  Future<void> setTime(int hour, int minute) async {
    _hour = hour;
    _minute = minute;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);

    if (_enabled) {
      await NotificationService.scheduleDailyReminder(
        hour: _hour,
        minute: _minute,
        message: _message,
      );
    }
  }

  Future<void> setMessage(String message) async {
    _message = message;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMessage, message);

    if (_enabled) {
      await NotificationService.scheduleDailyReminder(
        hour: _hour,
        minute: _minute,
        message: _message,
      );
    }
  }
}
