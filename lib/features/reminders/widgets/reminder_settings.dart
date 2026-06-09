import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/toast.dart';
import '../providers/reminder_provider.dart';
import '../services/notification_service.dart';

class ReminderSettings extends StatefulWidget {
  const ReminderSettings({super.key});

  @override
  State<ReminderSettings> createState() => _ReminderSettingsState();
}

class _ReminderSettingsState extends State<ReminderSettings> {
  bool _canExactSchedule = true;

  @override
  void initState() {
    super.initState();
    _checkExactPermission();
  }

  Future<void> _checkExactPermission() async {
    final can = await NotificationService.canScheduleExactAlarms();
    if (mounted) {
      setState(() => _canExactSchedule = can);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReminderProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final textColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            provider.enabled ? Icons.notifications_active : Icons.notifications_outlined,
            color: goldColor,
          ),
          title: Text(
            '写作提醒',
            style: AppTextStyles.body.copyWith(color: textColor),
          ),
          subtitle: Text(
            provider.enabled ? '每天 ${provider.timeDisplay} 提醒你写日记' : '开启后每天定时提醒',
            style: AppTextStyles.label.copyWith(color: subtleColor),
          ),
          value: provider.enabled,
          activeThumbColor: goldColor,
          onChanged: (value) async {
            final success = await provider.setEnabled(value);
            if (!success && context.mounted) {
              Toast().show(
                context,
                '需要通知权限才能开启提醒，请在系统设置中授权',
                ToastType.warning,
              );
            }
            // 开启后重新检查权限
            if (value) _checkExactPermission();
          },
        ),
        if (provider.enabled) ...[
          Divider(
            height: 1,
            color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine,
          ),
          ListTile(
            leading: Icon(Icons.access_time, color: goldColor),
            title: Text(
              '提醒时间',
              style: AppTextStyles.body.copyWith(color: textColor),
            ),
            trailing: Text(
              provider.timeDisplay,
              style: AppTextStyles.body.copyWith(
                color: goldColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => _pickTime(context, provider),
          ),
          // 精确闹钟权限未开启时显示提示
          if (!_canExactSchedule) ...[
            Divider(
              height: 1,
              color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine,
            ),
            ListTile(
              leading: Icon(Icons.warning_amber_rounded, color: AppColors.toastWarning),
              title: Text(
                '需要精确闹钟权限',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.toastWarning,
                ),
              ),
              subtitle: Text(
                '点击前往系统设置开启，否则提醒可能不准时',
                style: AppTextStyles.label.copyWith(color: subtleColor),
              ),
              trailing: Icon(Icons.chevron_right, color: subtleColor, size: 20),
              onTap: () async {
                await NotificationService.requestExactAlarmPermission();
                Future.delayed(const Duration(seconds: 1), _checkExactPermission);
              },
            ),
          ],
          Divider(
            height: 1,
            color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine,
          ),
          ListTile(
            leading: Icon(Icons.battery_saver, color: AppColors.toastInfo),
            title: Text(
              '电池优化白名单',
              style: AppTextStyles.body.copyWith(color: textColor),
            ),
            subtitle: Text(
              '部分手机需要手动设置才能收到定时提醒',
              style: AppTextStyles.label.copyWith(color: subtleColor),
            ),
            trailing: Icon(Icons.chevron_right, color: subtleColor, size: 20),
            onTap: () => _showBatteryGuide(context, isDark, goldColor, textColor, subtleColor),
          ),
        ],
      ],
    );
  }

  void _showBatteryGuide(BuildContext context, bool isDark, Color goldColor, Color textColor, Color subtleColor) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        title: Text('电池优化设置', style: AppTextStyles.heading.copyWith(
          color: isDark ? AppColors.darkTitleText : AppColors.titleText,
        )),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('为确保定时提醒正常工作，请按以下步骤设置：', style: AppTextStyles.body.copyWith(
                color: textColor, height: 1.5,
              )),
              const SizedBox(height: 12),
              _guideStep('1', '打开手机「设置」→「应用」→「应用管理」', textColor),
              _guideStep('2', '找到「手写日记」→「电池」或「耗电管理」', textColor),
              _guideStep('3', '选择「不限制」或「允许后台活动」', textColor),
              const SizedBox(height: 12),
              Text('华为/荣耀设备额外设置：', style: AppTextStyles.body.copyWith(
                color: goldColor, fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 4),
              _guideStep('•', '设置 → 电池 → 启动管理 → 手写日记 → 关闭自动管理 → 手动开启所有开关', textColor),
              _guideStep('•', '设置 → 应用 → 应用管理 → 手写日记 → 通知 → 开启允许通知', textColor),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('我知道了', style: TextStyle(color: goldColor)),
          ),
        ],
      ),
    );
  }

  Widget _guideStep(String num, String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$num ', style: AppTextStyles.body.copyWith(color: textColor)),
          Expanded(child: Text(text, style: AppTextStyles.body.copyWith(
            color: textColor, fontSize: 13, height: 1.4,
          ))),
        ],
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, ReminderProvider provider) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: provider.hour, minute: provider.minute),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
              hourMinuteColor: isDark
                  ? AppColors.darkGoldAccent.withValues(alpha: 0.15)
                  : AppColors.goldAccent.withValues(alpha: 0.1),
              hourMinuteTextColor: isDark ? AppColors.darkTitleText : AppColors.titleText,
              dialHandColor: isDark ? AppColors.darkGoldAccent : AppColors.goldAccent,
              dialBackgroundColor:
                  isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      provider.setTime(picked.hour, picked.minute);
    }
  }
}
