import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/achievement.dart';
import 'achievement_detail_dialog.dart';

class AchievementBadge extends StatelessWidget {
  final Achievement achievement;

  const AchievementBadge({
    super.key,
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackgroundAlt : AppColors.cardBackgroundAlt;
    final unlocked = achievement.isUnlocked;

    return GestureDetector(
      onTap: () => AchievementDetailDialog.show(context, achievement),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unlocked
              ? goldColor.withValues(alpha: 0.08)
              : bgColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unlocked
                ? goldColor.withValues(alpha: 0.3)
                : subtleColor.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Text(
              achievement.icon,
              style: TextStyle(
                fontSize: 28,
                color: unlocked ? null : Colors.grey.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 6),
            // Name
            Text(
              achievement.name,
              style: AppTextStyles.label.copyWith(
                fontSize: 12,
                color: unlocked
                    ? (isDark ? AppColors.darkTitleText : AppColors.titleText)
                    : subtleColor.withValues(alpha: 0.5),
                fontWeight: unlocked ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            // Description
            Text(
              achievement.description,
              style: TextStyle(
                fontSize: 10,
                color: unlocked
                    ? subtleColor
                    : subtleColor.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
