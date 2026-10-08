import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 生物识别（指纹）状态。
class BiometricStatus {
  /// 现在能不能弹验证框（把「设备 PIN/图案/密码」这条退路也算进去）。
  final bool available;

  /// 系统里是否**确实录入了指纹/人脸** —— 决定设置页开关能不能打开。
  final bool enrolled;

  /// 给用户看的原因说明（不可用时用它做提示）。
  final String reason;

  const BiometricStatus({
    required this.available,
    required this.enrolled,
    required this.reason,
  });

  static const BiometricStatus unsupported = BiometricStatus(
    available: false,
    enrolled: false,
    reason: '此设备不支持生物识别',
  );
}

/// 一次验证的结果。
class BiometricAuthResult {
  final bool success;
  final String? errorCode;
  final String? errorMessage;

  const BiometricAuthResult({
    required this.success,
    this.errorCode,
    this.errorMessage,
  });

  /// 用户主动取消（点了取消 / 按了返回）—— 此时**不该**再弹 PIN 打扰用户。
  bool get cancelled =>
      errorCode == 'USER_CANCELED' ||
      errorCode == 'NEGATIVE_BUTTON' ||
      errorCode == 'CANCELED';

  /// 根本弹不出来（硬件没有 / 没录入 / 插件缺失）—— 应回落到 PIN。
  bool get unavailable =>
      errorCode == 'UNAVAILABLE' ||
      errorCode == 'NO_BIOMETRICS' ||
      errorCode == 'HW_NOT_PRESENT' ||
      errorCode == 'NO_DEVICE_CREDENTIAL' ||
      errorCode == 'PLUGIN_ERROR';
}

/// 指纹验证（复用**系统已录入**的指纹，不自建指纹库）。
///
/// 走原生 `androidx.biometric.BiometricPrompt`，协议见
/// `android/app/src/main/kotlin/com/example/diary_app/BiometricPlugin.kt`。
///
/// ⚠️ 这里只是**门禁**，不参与密钥派生：日记的 `pinHash` 仍是唯一密钥。
class BiometricService {
  BiometricService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.diary_app/biometric');

  /// 「指纹解锁」总开关（用户可以在设置页关掉）。
  static const String prefKey = 'biometric_unlock_enabled';

  static BiometricStatus? _statusCache;
  static bool? _enabledCache;

  /// 查询设备能力。默认走缓存，`refresh: true` 强制重新查询。
  static Future<BiometricStatus> status({bool refresh = false}) async {
    if (!refresh && _statusCache != null) return _statusCache!;
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('isAvailable');
      if (raw == null) {
        _statusCache = BiometricStatus.unsupported;
      } else {
        _statusCache = BiometricStatus(
          available: raw['available'] == true,
          enrolled: raw['enrolled'] == true,
          reason: (raw['reason'] as String?) ?? '',
        );
      }
    } on MissingPluginException {
      // 插件没注册（例如跑在桌面/测试环境）—— 静默降级，不要炸
      _statusCache = BiometricStatus.unsupported;
    } on PlatformException catch (e) {
      _statusCache = BiometricStatus(
        available: false,
        enrolled: false,
        reason: e.message ?? '生物识别不可用',
      );
    } catch (_) {
      _statusCache = BiometricStatus.unsupported;
    }
    return _statusCache!;
  }

  /// 弹一次系统验证框。
  static Future<BiometricAuthResult> authenticate({
    String title = '验证身份',
    String subtitle = '使用系统已录入的指纹',
    String negativeText = '取消',
  }) async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'authenticate',
        <String, dynamic>{
          'title': title,
          'subtitle': subtitle,
          'negativeText': negativeText,
        },
      );
      if (raw == null) {
        return const BiometricAuthResult(
          success: false,
          errorCode: 'PLUGIN_ERROR',
          errorMessage: '原生未返回结果',
        );
      }
      return BiometricAuthResult(
        success: raw['success'] == true,
        errorCode: raw['errorCode'] as String?,
        errorMessage: raw['errorMessage'] as String?,
      );
    } on MissingPluginException {
      return const BiometricAuthResult(
        success: false,
        errorCode: 'PLUGIN_ERROR',
        errorMessage: '当前环境不支持指纹',
      );
    } on PlatformException catch (e) {
      return BiometricAuthResult(
        success: false,
        errorCode: e.code,
        errorMessage: e.message,
      );
    } catch (e) {
      return BiometricAuthResult(
        success: false,
        errorCode: 'PLUGIN_ERROR',
        errorMessage: e.toString(),
      );
    }
  }

  /// 设置页开关状态。
  static Future<bool> isEnabled() async {
    if (_enabledCache != null) return _enabledCache!;
    final prefs = await SharedPreferences.getInstance();
    _enabledCache = prefs.getBool(prefKey) ?? false;
    return _enabledCache!;
  }

  static Future<void> setEnabled(bool value) async {
    _enabledCache = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }
}
