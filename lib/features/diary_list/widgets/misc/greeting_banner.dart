import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class GreetingBanner extends StatelessWidget {
  final String greeting;
  final int streakDays;
  final List<bool> weekDays;

  const GreetingBanner({
    super.key,
    required this.greeting,
    required this.streakDays,
    this.weekDays = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;

    final lines = greeting.split('\n');
    final mainGreeting = lines.first;
    final subGreeting = lines.length > 1 ? lines.skip(1).join('\n') : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主问候语（手写体风格）
          Text(
            mainGreeting,
            style: AppTextStyles.handwritingTitle.copyWith(
              color: textColor,
              fontSize: 24,
            ),
          ),
          if (subGreeting.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subGreeting,
              style: AppTextStyles.body.copyWith(
                color: subtleColor,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // 连续天数 + 本周进度
          Row(
            children: [
              if (streakDays > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        '连续 $streakDays 天',
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (weekDays.isNotEmpty) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(7, (index) {
                    final hasEntry =
                        index < weekDays.length && weekDays[index];
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasEntry
                            ? accentColor
                            : accentColor.withValues(alpha: 0.15),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
