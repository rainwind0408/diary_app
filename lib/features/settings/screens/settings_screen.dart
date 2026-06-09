import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../weather/providers/seasonal_provider.dart';
import '../providers/font_size_provider.dart';

import '../providers/theme_provider.dart';
import '../widgets/import_export_button.dart';
import '../../reminders/widgets/reminder_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final seasonalProvider = context.watch<SeasonalProvider>();
    final fontProvider = context.watch<FontSizeProvider>();
    final isDark = themeProvider.isDark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                const ImportExportButton(),
                Divider(height: 1, color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine),
                SwitchListTile(
                  secondary: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                  ),
                  title: Text('暗色模式', style: AppTextStyles.body.copyWith(
                    color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                  )),
                  subtitle: Text(
                    isDark ? '夜间护眼模式' : '日间明亮模式',
                    style: AppTextStyles.label.copyWith(
                      color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                    ),
                  ),
                  value: isDark,
                  activeThumbColor: AppColors.darkGoldAccent,
                  onChanged: (_) => themeProvider.toggle(),
                ),
                Divider(height: 1, color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine),
                ListTile(
                  leading: Icon(
                    Icons.text_fields,
                    color: isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                  ),
                  title: Text('字体大小', style: AppTextStyles.body.copyWith(
                    color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                  )),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('小', style: AppTextStyles.label.copyWith(
                            fontSize: 11,
                            color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                          )),
                          Expanded(
                            child: Slider(
                              value: fontProvider.scale,
                              min: FontSizeProvider.minScale,
                              max: FontSizeProvider.maxScale,
                              divisions: 6,
                              activeColor: AppColors.darkGoldAccent,
                              inactiveColor: (isDark ? AppColors.darkSubtleText : AppColors.subtleText).withValues(alpha: 0.2),
                              onChanged: (v) => fontProvider.setScale(v),
                            ),
                          ),
                          Text('大', style: AppTextStyles.label.copyWith(
                            fontSize: 11,
                            color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                          )),
                        ],
                      ),
                    ],
                  ),
                  trailing: Text(
                    '字体',
                    style: AppTextStyles.body.copyWith(
                      color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                    ),
                  ),
                ),
                Divider(height: 1, color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine),
                const ReminderSettings(),
                Divider(height: 1, color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine),
                SwitchListTile(
                  secondary: Icon(
                    Icons.eco,
                    color: isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                  ),
                  title: Text('节气主题', style: AppTextStyles.body.copyWith(
                    color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                  )),
                  subtitle: Text(
                    seasonalProvider.isEnabled
                        ? '${seasonalProvider.currentTerm?.name ?? ""} · ${seasonalProvider.weatherData != null ? "${seasonalProvider.weatherData!.tempDisplay} ${seasonalProvider.weatherData!.description}" : "节气配色"}'
                        : '跟随节气变化切换主题',
                    style: AppTextStyles.label.copyWith(
                      color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                    ),
                  ),
                  value: seasonalProvider.isEnabled,
                  activeThumbColor: isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                  onChanged: (_) => seasonalProvider.toggleEnabled(),
                ),
                Divider(height: 1, color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine),
                ListTile(
                  leading: Icon(Icons.info_outline,
                    color: isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                  ),
                  title: Text('关于', style: AppTextStyles.body.copyWith(
                    color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                  )),
                  subtitle: Text('个人日记本 v1.6.0', style: AppTextStyles.label.copyWith(
                    color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                  )),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}
