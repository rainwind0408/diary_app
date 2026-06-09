import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/template.dart';

class TemplateCard extends StatelessWidget {
  final DiaryTemplate template;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TemplateCard({
    super.key,
    required this.template,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: goldColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            Text(
              template.name,
              style: AppTextStyles.label.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              template.description,
              style: AppTextStyles.cardDate.copyWith(
                color: subtleColor,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
