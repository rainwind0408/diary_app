import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/repositories/diary_repository.dart';

class MiniCalendar extends StatefulWidget {
  final DateTime currentMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const MiniCalendar({
    super.key,
    required this.currentMonth,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  State<MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<MiniCalendar> {
  final DiaryRepository _repository = DiaryRepository();
  Set<int> _entryDays = {};
  bool _loading = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadEntryDays();
  }

  @override
  void didUpdateWidget(MiniCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMonth.month != widget.currentMonth.month ||
        oldWidget.currentMonth.year != widget.currentMonth.year) {
      _loadEntryDays();
    }
  }

  Future<void> _loadEntryDays() async {
    final generation = ++_loadGeneration;
    setState(() => _loading = true);
    final days = await _repository.getEntryDatesInMonth(
      widget.currentMonth.year,
      widget.currentMonth.month,
    );
    if (mounted && generation == _loadGeneration) {
      setState(() {
        _entryDays = days;
        _loading = false;
      });
    }
  }

  // 水彩色轮换
  static const List<Color> _dayColors = [
    AppColors.pink,
    AppColors.blue,
    AppColors.green,
    AppColors.yellow,
    AppColors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final bgColor = isDark ? AppColors.darkCardBackgroundAlt : AppColors.cardBackgroundAlt;

    final year = widget.currentMonth.year;
    final month = widget.currentMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // 0=Sunday
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: widget.onPreviousMonth,
                icon: Icon(Icons.chevron_left, color: subtleColor, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Text(
                '$year年$month月',
                style: AppTextStyles.dateLabel.copyWith(color: textColor),
              ),
              IconButton(
                onPressed: widget.onNextMonth,
                icon: Icon(Icons.chevron_right, color: subtleColor, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Weekday headers
          Row(
            children: ['日', '一', '二', '三', '四', '五', '六'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(d, style: AppTextStyles.cardDate.copyWith(color: subtleColor)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),

          // Calendar grid with colored cells
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: startWeekday + lastDay.day,
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox.shrink();

              final day = index - startWeekday + 1;
              final date = DateTime(year, month, day);
              final isSelected = date.year == widget.selectedDate.year &&
                  date.month == widget.selectedDate.month &&
                  date.day == widget.selectedDate.day;
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final hasEntry = _entryDays.contains(day);
              final dayColor = _dayColors[day % _dayColors.length];

              return GestureDetector(
                onTap: () => widget.onDateSelected(date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor
                        : hasEntry
                            ? dayColor.withValues(alpha: 0.3)
                            : dayColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: accentColor, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? (isDark ? AppColors.darkCardBackground : AppColors.cardBackground)
                              : textColor,
                        ),
                      ),
                      if (hasEntry)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? (isDark ? AppColors.darkCardBackground : AppColors.cardBackground)
                                : accentColor,
                          ),
                        )
                      else
                        const SizedBox(height: 6),
                    ],
                  ),
                ),
              );
            },
          ),

          if (_loading)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: accentColor),
              ),
            ),
        ],
      ),
    );
  }
}
