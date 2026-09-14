import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../data/repositories/diary_repository.dart';

/// 有日记的格子用到的水彩轮换色
const List<Color> _kDayColors = [
  AppColors.pink,
  AppColors.blue,
  AppColors.green,
  AppColors.yellow,
  AppColors.purple,
];

/// 隐藏式日历卡片
///
/// **首页唯一的日期导航入口**：收起时只显示一条 44px 的头条
/// （月份 + 本月记录天数 + 箭头），点击后展开完整月历网格；
/// 选中日期后自动收起。
///
/// - 触屏点击头条展开，再点日期完成选日
/// - 展开态下左右箭头切换月份，右侧「回到今天」快速回位
/// - 不允许选择未来日期（格子置灰不可点）
///
/// 数据走 [DiaryRepository.getMonthDayStats] 一次性批量查询整月，
/// 不做逐天查询。
class CollapsibleCalendar extends StatefulWidget {
  /// 当前选中的日期（由 DateFilterProvider.selectedDate 驱动）
  final DateTime selectedDate;

  /// 点击某个日期后的回调
  final ValueChanged<DateTime> onDateSelected;

  /// 月份切换后的回调，供外部按新月份刷新封面图等月度数据
  final ValueChanged<DateTime>? onMonthChanged;

  const CollapsibleCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.onMonthChanged,
  });

  @override
  State<CollapsibleCalendar> createState() => _CollapsibleCalendarState();
}

class _CollapsibleCalendarState extends State<CollapsibleCalendar> {
  static const List<String> _weekdayLabels = ['日', '一', '二', '三', '四', '五', '六'];

  final DiaryRepository _repository = DiaryRepository();

  bool _expanded = false;
  late DateTime _displayMonth;
  Map<int, ({int count, String mood})> _dayStats = {};
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    _loadMonthStats();
  }

  @override
  void didUpdateWidget(CollapsibleCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部切换日期若跨月，日历跟随到该月
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      final target =
          DateTime(widget.selectedDate.year, widget.selectedDate.month);
      if (target.year != _displayMonth.year ||
          target.month != _displayMonth.month) {
        _displayMonth = target;
        _loadMonthStats();
      }
    }
  }

  Future<void> _loadMonthStats() async {
    final generation = ++_loadGeneration;
    final year = _displayMonth.year;
    final month = _displayMonth.month;
    try {
      final stats = await _repository.getMonthDayStats(year, month);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _dayStats = stats);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _dayStats = {});
    }
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() => _expanded = !_expanded);
  }

  void _changeMonth(int delta) {
    final next = DateTime(_displayMonth.year, _displayMonth.month + delta);
    // 不允许翻到未来月份
    final now = DateTime.now();
    if (delta > 0 && next.isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _displayMonth = next;
      _dayStats = {};
    });
    _loadMonthStats();
    widget.onMonthChanged?.call(next);
  }

  void _selectDate(DateTime date) {
    // 全应用统一规则：不允许选未来日期
    final now = DateTime.now();
    if (date.isAfter(DateTime(now.year, now.month, now.day))) return;
    HapticFeedback.lightImpact();
    widget.onDateSelected(date);
    setState(() => _expanded = false);
  }

  void _backToToday() {
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day);
    if (_displayMonth.year != target.year ||
        _displayMonth.month != target.month) {
      setState(() {
        _displayMonth = DateTime(target.year, target.month);
        _dayStats = {};
      });
      _loadMonthStats();
      widget.onMonthChanged?.call(_displayMonth);
    }
    _selectDate(target);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final cardBg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(textColor, subtleColor, accentColor),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _buildMonthGrid(isDark, subtleColor, accentColor)
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        ),
      ),
    );
  }

  /// 收起态头条：图标 + 月份 + 本月记录天数 + 旋转箭头
  Widget _buildHeader(
    Color textColor,
    Color subtleColor,
    Color accentColor,
  ) {
    final recordedDays = _dayStats.length;
    final monthText = '${_displayMonth.year}年${_displayMonth.month}月';

    return InkWell(
      onTap: _toggle,
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                monthText,
                style: AppTextStyles.cardTitle.copyWith(
                  color: textColor,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 10),
              if (recordedDays > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$recordedDays 天',
                    style: TextStyle(
                      fontSize: 11,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                _expanded ? '收起' : '展开',
                style: TextStyle(fontSize: 12, color: subtleColor),
              ),
              const SizedBox(width: 2),
              AnimatedRotation(
                turns: _expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: subtleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGrid(
    bool isDark,
    Color subtleColor,
    Color accentColor,
  ) {
    final year = _displayMonth.year;
    final month = _displayMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // 周日为一周第一列
    final startWeekday = firstDay.weekday % 7;
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),

          // 星期表头 + 月份切换
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left,
                color: subtleColor,
                onTap: () => _changeMonth(-1),
              ),
              Expanded(
                child: Row(
                  children: _weekdayLabels.map((label) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            color: subtleColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right,
                color: subtleColor,
                onTap: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 月历网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox.shrink();
              final day = index - startWeekday + 1;
              final cellDate = DateTime(year, month, day);
              final isFuture = cellDate
                  .isAfter(DateTime(now.year, now.month, now.day));
              return _CalendarCell(
                day: day,
                isToday: now.year == year &&
                    now.month == month &&
                    now.day == day,
                isSelected: widget.selectedDate.year == year &&
                    widget.selectedDate.month == month &&
                    widget.selectedDate.day == day,
                isFuture: isFuture,
                count: _dayStats[day]?.count ?? 0,
                mood: _dayStats[day]?.mood ?? '',
                accentColor: accentColor,
                subtleColor: subtleColor,
                isDark: isDark,
                // 未来日期不可点，避免「选了明天却没有日记」的空态困惑
                onTap: isFuture ? null : () => _selectDate(cellDate),
              );
            },
          ),
          const SizedBox(height: 8),

          // 回到今天
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _backToToday,
              icon: Icon(Icons.today, size: 15, color: accentColor),
              label: Text(
                '回到今天',
                style: TextStyle(fontSize: 12, color: accentColor),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 月份切换小按钮
class _NavButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

/// 单个日期格子
class _CalendarCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isSelected;

  /// 未来日期：置灰且不可点
  final bool isFuture;
  final int count;
  final String mood;
  final Color accentColor;
  final Color subtleColor;
  final bool isDark;
  final VoidCallback? onTap;

  const _CalendarCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.count,
    required this.mood,
    required this.accentColor,
    required this.subtleColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasEntry = count > 0;
    final dayColor = _kDayColors[day % _kDayColors.length];

    final Color bgColor;
    if (isSelected) {
      bgColor = accentColor.withValues(alpha: 0.85);
    } else if (isFuture) {
      bgColor = Colors.transparent;
    } else if (hasEntry) {
      // 填充浓度提高到 0.6：浅水彩底 + 深色文字在真机上对比度不足，
      // 尤其是 yellow / green 这类明度高的色。
      bgColor = dayColor.withValues(alpha: 0.6);
    } else {
      bgColor = dayColor.withValues(alpha: 0.08);
    }

    final Color fgColor;
    if (isSelected) {
      fgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    } else if (isFuture) {
      fgColor = subtleColor.withValues(alpha: 0.3);
    } else if (hasEntry) {
      // 有日记时统一用最深的标题色，保证在任何水彩底上都清晰
      fgColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    } else {
      fgColor = subtleColor.withValues(alpha: 0.5);
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: accentColor, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (mood.isNotEmpty && hasEntry)
              Text(mood, style: const TextStyle(fontSize: 13))
            else
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  color: fgColor,
                  fontWeight:
                      (isToday || isSelected) ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            if (hasEntry && count > 1)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (isDark
                          ? AppColors.darkCardBackground
                          : AppColors.cardBackground)
                      : accentColor,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
