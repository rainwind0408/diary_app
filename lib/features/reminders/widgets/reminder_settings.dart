import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/toast.dart';
import '../providers/reminder_provider.dart';

class ReminderSettings extends StatelessWidget {
  const ReminderSettings({super.key});

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
        ],
      ],
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
