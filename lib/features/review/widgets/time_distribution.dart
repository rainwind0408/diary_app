import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class TimeDistribution extends StatelessWidget {
  final Map<String, int> timeStats;

  const TimeDistribution({super.key, required this.timeStats});

  static const List<_TimeSlot> _slots = [
    _TimeSlot('早晨', '🌅'),
    _TimeSlot('下午', '☀️'),
    _TimeSlot('晚上', '🌙'),
    _TimeSlot('深夜', '🌑'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    final total = timeStats.values.fold(0, (sum, v) => sum + v);
    final maxCount = timeStats.values.fold(0, (max, v) => v > max ? v : max);

    // 找出最常写作的时间段
    String peakTime = '';
    if (total > 0) {
      int peakCount = 0;
      for (final entry in timeStats.entries) {
        if (entry.value > peakCount) {
          peakCount = entry.value;
          peakTime = entry.key;
        }
      }
    }

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
            '写作时间',
            style: AppTextStyles.cardTitle.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            ),
          ),
          if (peakTime.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '你最常在$peakTime写日记',
              style: AppTextStyles.label.copyWith(
                color: subtleColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ..._slots.map((slot) {
            final count = timeStats[slot.name] ?? 0;
            final ratio = maxCount > 0 ? count / maxCount : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(slot.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      slot.name,
                      style: TextStyle(fontSize: 12, color: subtleColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: subtleColor.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          goldColor.withValues(alpha: 0.7),
                        ),
                        minHeight: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$count篇',
                      style: TextStyle(fontSize: 11, color: subtleColor),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TimeSlot {
  final String name;
  final String emoji;
  const _TimeSlot(this.name, this.emoji);
}
