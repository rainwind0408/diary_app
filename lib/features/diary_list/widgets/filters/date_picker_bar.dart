import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';

class DatePickerBar extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onDatePicked;

  const DatePickerBar({
    super.key,
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onDatePicked,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final borderColor = isDark ? AppColors.darkDividerLine : AppColors.dividerLine;
    final iconColor = isDark ? AppColors.darkLabelText : AppColors.labelText;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: Icon(Icons.chevron_left, color: iconColor),
            iconSize: 28,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: goldColor,
                          onPrimary: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
                          surface: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) onDatePicked(picked);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  DateFormatter.formatFull(selectedDate),
                  key: ValueKey(selectedDate),
                  style: AppTextStyles.dateLabel.copyWith(
                    color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(Icons.chevron_right, color: iconColor),
            iconSize: 28,
          ),
        ],
      ),
    );
  }
}
