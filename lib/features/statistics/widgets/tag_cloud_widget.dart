import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class TagCloudWidget extends StatelessWidget {
  final Map<String, int> tagData;
  final ValueChanged<String>? onTagTapped;

  const TagCloudWidget({
    super.key,
    required this.tagData,
    this.onTagTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;

    final sorted = tagData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) return const SizedBox.shrink();

    final maxCount = sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '标签云',
            style: AppTextStyles.cardTitle.copyWith(color: textColor),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sorted.map((entry) {
              final ratio = entry.value / maxCount;
              final fontSize = 12.0 + ratio * 8.0;
              final opacity = 0.5 + ratio * 0.5;

              return GestureDetector(
                onTap: onTagTapped != null
                    ? () => onTagTapped!(entry.key)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: goldColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    '#${entry.key}',
                    style: TextStyle(
                      fontSize: fontSize,
                      color: goldColor.withValues(alpha: opacity),
                      fontWeight:
                          ratio > 0.7 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
