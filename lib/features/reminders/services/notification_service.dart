import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Timer? _backupTimer;

  static const _channelId = 'diary_reminder';
  static const _channelName = '写作提醒';
  static const _notificationId = 1001;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    // 使用设备本地时区，而非硬编码
    final localTimeZone = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(_getTzDatabaseName(localTimeZone)));
    } catch (_) {
      // 无法识别时区名时，通过偏移量查找
      final offset = DateTime.now().timeZoneOffset;
      tz.setLocalLocation(tz.getLocation(_getTimezoneByOffset(offset)));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// 将系统时区名映射到 tz 数据库名称
  static String _getTzDatabaseName(String systemName) {
    const map = {
      '中国标准时间': 'Asia/Shanghai',
      'CST': 'Asia/Shanghai',
      'China Standard Time': 'Asia/Shanghai',
      'HKT': 'Asia/Hong_Kong',
      'JST': 'Asia/Tokyo',
      'KST': 'Asia/Seoul',
      'PST': 'America/Los_Angeles',
      'EST': 'America/New_York',
      'CET': 'Europe/Berlin',
      'UTC': 'UTC',
      'GMT': 'UTC',
    };
    return map[systemName] ?? 'Asia/Shanghai';
  }

  /// 根据 UTC 偏移量查找时区
  static String _getTimezoneByOffset(Duration offset) {
    final hours = offset.inHours;
    const offsetMap = {
      8: 'Asia/Shanghai',
      9: 'Asia/Tokyo',
      7: 'Asia/Bangkok',
      5: 'Asia/Kolkata',
      3: 'Europe/Moscow',
      1: 'Europe/Berlin',
      0: 'UTC',
      -5: 'America/New_York',
      -6: 'America/Chicago',
      -7: 'America/Denver',
      -8: 'America/Los_Angeles',
    };
    return offsetMap[hours] ?? 'Asia/Shanghai';
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// 检查精确闹钟权限（Android 12+）
  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// 引导用户开启精确闹钟权限
  static Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String message,
  }) async {
    if (!_initialized) await initialize();

    // 检查精确闹钟权限
    final canExact = await canScheduleExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _plugin.zonedSchedule(
      _notificationId,
      '写日记的时间到了',
      message,
      _nextInstanceOfTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '每日写作提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // 备用方案：Dart Timer（应用在前台时生效）
    _setupBackupTimer(hour, minute, message);
  }

  /// 设置备用 Timer，应用在前台时触发通知
  static void _setupBackupTimer(int hour, int minute, String message) {
    _backupTimer?.cancel();
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    final delay = target.difference(now);
    _backupTimer = Timer(delay, () {
      _plugin.show(
        _notificationId + 1,
        '写日记的时间到了',
        message,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: '每日写作提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
      // 触发后设置下一天的 Timer
      _setupBackupTimer(hour, minute, message);
    });
  }

  static Future<void> cancelReminder() async {
    if (!_initialized) await initialize();
    await _plugin.cancel(_notificationId);
  }

  static Future<bool> isReminderScheduled() async {
    if (!_initialized) await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((n) => n.id == _notificationId);
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
