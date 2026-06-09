import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/achievement.dart';
import 'achievement_badge.dart';

class AchievementGrid extends StatelessWidget {
  final String title;
  final List<Achievement> achievements;

  const AchievementGrid({
    super.key,
    required this.title,
    required this.achievements,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            '── $title ──',
            style: AppTextStyles.label.copyWith(
              color: textColor,
              fontSize: 13,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: achievements.map((achievement) {
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 56) / 5,
              child: AchievementBadge(achievement: achievement),
            );
          }).toList(),
        ),
      ],
    );
  }
}
