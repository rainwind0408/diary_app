import 'package:flutter/material.dart';

import 'biometric_service.dart';
import 'pin_service.dart';
import '../widgets/pin_input_dialog.dart';

/// 一次「访问受保护日记」的结论。
enum DiaryAccessResult {
  /// 放行：指纹通过，或 PIN 正确。
  granted,

  /// PIN 输错了（指纹没参与或指纹失败后回落到了 PIN）。
  denied,

  /// 用户主动放弃：关掉了 PIN 弹窗，或取消了指纹验证。
  cancelled,
}

/// 受保护日记的统一门禁。
///
/// **降级链**（四处入口共用同一份逻辑，避免各写各的）：
/// ```
/// 没锁 → 放行
/// 指纹开关开 且 设备可用 → 弹系统指纹
///     成功        → 放行
///     用户取消    → cancelled（不再弹 PIN，避免二次打扰）
///     锁定/异常   → 继续往下走 PIN
/// 否则 → PIN 弹窗
///     PIN 正确 → 放行
///     PIN 错误 → denied
///     关掉弹窗 → cancelled
/// ```
///
/// ⚠️ **上锁时不用指纹**：PIN 是唯一的兜底密钥，只用指纹上锁会导致
/// 「指纹失效后日记再也打不开」。所以 `_handleLock` 仍必须走 PIN。
class DiaryAccess {
  DiaryAccess._();

  static Future<DiaryAccessResult> verify(
    BuildContext context,
    String storedHash, {
    String title = '输入密码',
    String biometricTitle = '验证身份',
  }) async {
    // 没设密码的日记不该走到这里，但兜一下更安全
    if (storedHash.isEmpty) return DiaryAccessResult.granted;

    if (await BiometricService.isEnabled()) {
      final status = await BiometricService.status();
      if (status.available) {
        final auth = await BiometricService.authenticate(title: biometricTitle);
        if (auth.success) return DiaryAccessResult.granted;
        if (auth.cancelled) return DiaryAccessResult.cancelled;
        // 其余情况（锁定 / 硬件异常）静默回落到 PIN
      }
    }

    if (!context.mounted) return DiaryAccessResult.cancelled;
    final pin = await PinInputDialog.show(context, title: title);
    if (pin == null) return DiaryAccessResult.cancelled;

    return PinService.verifyPin(pin, storedHash)
        ? DiaryAccessResult.granted
        : DiaryAccessResult.denied;
  }
}
