import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class MoodIntensityBar extends StatelessWidget {
  final int intensity; // 1-5
  final ValueChanged<int> onChanged;

  const MoodIntensityBar({
    super.key,
    required this.intensity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Row(
      children: [
        Text(
          '轻微',
          style: TextStyle(fontSize: 11, color: subtleColor),
        ),
        const SizedBox(width: 8),
        ...List.generate(5, (index) {
          final level = index + 1;
          final isSelected = level <= intensity;
          return GestureDetector(
            onTap: () => onChanged(level),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? goldColor
                      : goldColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: isSelected
                        ? goldColor
                        : goldColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 8),
        Text(
          '强烈',
          style: TextStyle(fontSize: 11, color: subtleColor),
        ),
      ],
    );
  }
}
