import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/repositories/diary_repository.dart';

class DateStrip extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onLongPress;

  const DateStrip({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.onLongPress,
  });

  @override
  State<DateStrip> createState() => _DateStripState();
}

class _DateStripState extends State<DateStrip> {
  static const int _initialDays = 30;
  static const int _loadMoreDays = 30;
  int _totalDays = _initialDays;
  final ScrollController _scrollController = ScrollController();
  final DiaryRepository _repository = DiaryRepository();
  Set<int> _entryDays = {};
  int _entryMonth = 0;

  @override
  void initState() {
    super.initState();
    _loadEntryDays(widget.selectedDate);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(DateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.month != widget.selectedDate.month ||
        oldWidget.selectedDate.year != widget.selectedDate.year) {
      _loadEntryDays(widget.selectedDate);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      setState(() => _totalDays += _loadMoreDays);
    }
  }

  Future<void> _loadEntryDays(DateTime date) async {
    final key = date.year * 100 + date.month;
    if (key == _entryMonth) return;
    _entryMonth = key;
    final days = await _repository.getEntryDatesInMonth(date.year, date.month);
    if (mounted) setState(() => _entryDays = days);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: SizedBox(
        height: 72,
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _totalDays + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildTodayButton(isDark, today);
            }
            final date = today.subtract(Duration(days: index - 1));
            final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
            final isToday = DateUtils.isSameDay(date, today);
            final hasEntry = date.month == widget.selectedDate.month &&
                _entryDays.contains(date.day);

            return _DateChip(
              date: date,
              isSelected: isSelected,
              isToday: isToday,
              hasEntry: hasEntry,
              isDark: isDark,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onDateSelected(date);
                _loadEntryDays(date);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTodayButton(bool isDark, DateTime today) {
    final isTodaySelected = DateUtils.isSameDay(today, widget.selectedDate);
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onDateSelected(today);
      },
      child: Container(
        width: 44,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isTodaySelected
              ? accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTodaySelected
                ? accentColor.withValues(alpha: 0.4)
                : (isDark ? AppColors.darkSubtleText : AppColors.subtleText)
                    .withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.today,
              size: 18,
              color: isTodaySelected
                  ? accentColor
                  : (isDark ? AppColors.darkSubtleText : AppColors.subtleText),
            ),
            const SizedBox(height: 2),
            Text(
              '今天',
              style: TextStyle(
                fontSize: 10,
                color: isTodaySelected
                    ? accentColor
                    : (isDark
                        ? AppColors.darkSubtleText
                        : AppColors.subtleText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool hasEntry;
  final bool isDark;
  final VoidCallback onTap;

  const _DateChip({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.hasEntry,
    required this.isDark,
    required this.onTap,
  });

  static const List<String> _weekdays = ['日', '一', '二', '三', '四', '五', '六'];

  // 水彩色轮换
  static const List<Color> _chipColors = [
    AppColors.pink,
    AppColors.blue,
    AppColors.green,
    AppColors.yellow,
    AppColors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final chipColor = _chipColors[date.day % _chipColors.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor
              : isToday
                  ? chipColor.withValues(alpha: 0.2)
                  : chipColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor
                : isToday
                    ? chipColor.withValues(alpha: 0.4)
                    : chipColor.withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weekdays[date.weekday % 7],
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? (isDark ? AppColors.darkCardBackground : AppColors.cardBackground)
                    : subtleColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isDark ? AppColors.darkCardBackground : AppColors.cardBackground)
                    : isToday
                        ? accentColor
                        : (isDark
                            ? AppColors.darkTitleText
                            : AppColors.titleText),
              ),
            ),
            SizedBox(
              height: 6,
              child: hasEntry
                  ? Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? (isDark
                                ? AppColors.darkCardBackground
                                : AppColors.cardBackground)
                            : accentColor.withValues(alpha: 0.6),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
