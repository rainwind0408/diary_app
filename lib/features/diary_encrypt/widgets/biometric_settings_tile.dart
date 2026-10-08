import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/toast.dart';
import '../services/biometric_service.dart';

/// 设置页的「指纹解锁」开关。
///
/// - 设备根本用不了（无硬件 / 插件缺失）→ 整项不显示，不占版面。
/// - 系统没录入指纹、但设备凭据可用 → 显示，并诚实说明「将使用锁屏密码验证」。
/// - 打开开关时**必须先成功验证一次**才落盘：证明这台机器此刻真能用，
///   否则会出现「开关是开的，但每次点都弹不出来」的假象。
class BiometricSettingsTile extends StatefulWidget {
  const BiometricSettingsTile({super.key});

  @override
  State<BiometricSettingsTile> createState() => _BiometricSettingsTileState();
}

class _BiometricSettingsTileState extends State<BiometricSettingsTile> {
  BiometricStatus? _status;
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await BiometricService.status();
    final enabled = await BiometricService.isEnabled();
    if (!mounted) return;
    setState(() {
      _status = status;
      _enabled = enabled;
    });
  }

  Future<void> _onChanged(bool value) async {
    if (_busy) return;

    if (!value) {
      await BiometricService.setEnabled(false);
      if (!mounted) return;
      setState(() => _enabled = false);
      return;
    }

    setState(() => _busy = true);
    final result = await BiometricService.authenticate(
      title: '开启指纹解锁',
      subtitle: '请先验证一次，确认此设备可用',
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.success) {
      await BiometricService.setEnabled(true);
      if (!mounted) return;
      setState(() => _enabled = true);
      Toast().show(context, '指纹解锁已开启', ToastType.success);
    } else if (!result.cancelled) {
      Toast().show(
        context,
        result.errorMessage?.isNotEmpty == true ? result.errorMessage! : '验证失败，请重试',
        ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    // 还没查完 / 设备不支持 → 不占版面
    if (status == null || !status.available) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitle = status.enrolled
        ? '使用系统已录入的指纹快速解锁日记'
        : '系统未录入指纹，将改用锁屏密码验证';

    return SwitchListTile(
      secondary: _busy
          ? SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                ),
              ),
            )
          : Icon(
              Icons.fingerprint,
              color: isDark ? AppColors.darkAccentPink : AppColors.accentPink,
            ),
      title: Text('指纹解锁', style: AppTextStyles.body.copyWith(
        color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
      )),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.label.copyWith(
          color: isDark ? AppColors.darkLabelText : AppColors.labelText,
        ),
      ),
      value: _enabled,
      activeThumbColor: AppColors.darkGoldAccent,
      onChanged: _busy ? null : _onChanged,
    );
  }
}
