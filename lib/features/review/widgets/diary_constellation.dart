import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/mood_constants.dart';

/// 日记星座图（圆形年盘）
///
/// 把一年的日记按日期铺在一个圆盘上：**一年 365 天对应圆周 365 个刻度**，
/// 每天一个光点绕圆排布，一个圆就是一年。
///
/// 为什么替换原来的 `YearlyHeatmap`：
/// 那个是 GitHub 贡献图式的方格阵 —— **程序员的语言**，横平竖直、密不透风。
/// 圆形年盘是**天文式的、诗意的语言**，跟「折花日记」的水彩调性是一路的。
///
/// 视觉编码：
/// - **位置** = 日期（12 点钟方向是 1 月 1 日，顺时针走完一年）
/// - **半径** = 固定；但**亮度与大小** = 当天写的字数
/// - **颜色** = 当天的心情（映射 `AppColors.mood*`）
/// - **虚线圈** = 季度分隔，帮助定位月份
class DiaryConstellation extends StatefulWidget {
  /// 每天的 {日序号(1~366): (words, mood)}
  final Map<int, ({int words, String mood})> dailyStats;

  /// 这一年是闰年吗（决定圆盘按 365 还是 366 等分）
  final bool isLeapYear;

  /// 点击某天
  final void Function(int dayOfYear)? onDayTap;

  const DiaryConstellation({
    super.key,
    required this.dailyStats,
    this.isLeapYear = false,
    this.onDayTap,
  });

  @override
  State<DiaryConstellation> createState() => _DiaryConstellationState();
}

class _DiaryConstellationState extends State<DiaryConstellation> {
  /// 被点中的那天（显示在中心）
  int? _selectedDay;

  int get _daysInYear => widget.isLeapYear ? 366 : 365;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor =
        isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    final activeDays = widget.dailyStats.length;

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
          Row(
            children: [
              Text(
                '日记星座',
                style: AppTextStyles.cardTitle.copyWith(color: textColor),
              ),
              const Spacer(),
              Text(
                '$activeDays 天有记录',
                style: TextStyle(fontSize: 12, color: subtleColor),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 圆盘
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth;
              return SizedBox(
                width: size,
                height: size,
                child: GestureDetector(
                  onTapUp: (details) => _handleTap(details, size),
                  child: CustomPaint(
                    painter: _ConstellationPainter(
                      dailyStats: widget.dailyStats,
                      daysInYear: _daysInYear,
                      selectedDay: _selectedDay,
                      isDark: isDark,
                      subtleColor: subtleColor,
                    ),
                    child: _buildCenterLabel(isDark, textColor, subtleColor),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 14),
          _buildLegend(subtleColor),
        ],
      ),
    );
  }

  /// 圆盘中心：显示选中日期的简述，否则显示全年概览
  Widget _buildCenterLabel(bool isDark, Color textColor, Color subtleColor) {
    final day = _selectedDay;
    final stat = day == null ? null : widget.dailyStats[day];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (day == null) ...[
              Text(
                '${widget.dailyStats.length}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkGoldAccent : AppColors.goldAccent,
                  fontFamily: 'MaShanZheng',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '个闪耀的日子',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: subtleColor),
              ),
            ] else ...[
              Text(
                stat?.mood.isNotEmpty == true ? stat!.mood : '·',
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(height: 4),
              Text(
                _dayLabel(day),
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stat == null ? '这天没有记录' : '${stat.words} 字',
                style: TextStyle(fontSize: 11, color: subtleColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color subtleColor) {
    final items = <(String, Color)>[
      ('开心', AppColors.moodHappy),
      ('平静', AppColors.moodCalm),
      ('难过', AppColors.moodSad),
      ('兴奋', AppColors.moodExcited),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (label, color) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(fontSize: 10, color: subtleColor)),
            ],
          ),
      ],
    );
  }

  /// 把点击坐标换算成「日序号」
  ///
  /// 只认离圆心 30%~110% 半径之间的点击，避免点中心标签误触发。
  void _handleTap(TapUpDetails details, double size) {
    final center = Offset(size / 2, size / 2);
    final v = details.localPosition - center;
    final dist = v.distance;
    final outer = size / 2;
    if (dist < outer * 0.30 || dist > outer * 1.05) return;

    // 12 点钟为 0 弧度，顺时针递增
    var angle = math.atan2(v.dy, v.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    final fraction = angle / (2 * math.pi);
    final day = (fraction * _daysInYear).floor() + 1;
    final clamped = day.clamp(1, _daysInYear);

    setState(() => _selectedDay = clamped);
    widget.onDayTap?.call(clamped);
  }

  static String _dayLabel(int dayOfYear) => constellationDayLabel(dayOfYear);
}

class _ConstellationPainter extends CustomPainter {
  final Map<int, ({int words, String mood})> dailyStats;
  final int daysInYear;
  final int? selectedDay;
  final bool isDark;
  final Color subtleColor;

  _ConstellationPainter({
    required this.dailyStats,
    required this.daysInYear,
    required this.selectedDay,
    required this.isDark,
    required this.subtleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2;
    final ringRadius = outer * 0.84;

    // 全年最大字数，用于归一化亮度
    var maxWords = 1;
    for (final s in dailyStats.values) {
      if (s.words > maxWords) maxWords = s.words;
    }

    // 底座圆环：一年 365 个刻度，每个都是一个极淡的点
    // 这样即使某天没写日记，圆盘也不会显得残缺
    final basePaint = Paint()
      ..color = subtleColor.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    for (var d = 0; d < daysInYear; d++) {
      final p = _pointAt(center, ringRadius, d, daysInYear);
      canvas.drawCircle(p, 1.1, basePaint);
    }

    // 季度分隔的虚线圆（帮助定位）
    final guidePaint = Paint()
      ..color = subtleColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, ringRadius * 0.62, guidePaint);
    canvas.drawCircle(center, ringRadius * 0.31, guidePaint);

    // 月份刻度：每月第一天往外画一小段线
    final tickPaint = Paint()
      ..color = subtleColor.withValues(alpha: 0.30)
      ..strokeWidth = 1.2;
    for (var m = 1; m <= 12; m++) {
      final dayOfYear = _dayOfYearForMonth(m);
      final p1 = _pointAt(center, ringRadius * 0.92, dayOfYear - 1, daysInYear);
      final p2 = _pointAt(center, ringRadius * 1.0, dayOfYear - 1, daysInYear);
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 数据点：按字数决定大小与亮度
    for (final entry in dailyStats.entries) {
      final dayIndex = entry.key - 1;
      if (dayIndex < 0 || dayIndex >= daysInYear) continue;

      final stat = entry.value;
      final intensity = (stat.words / maxWords).clamp(0.0, 1.0);
      final color = _colorForMood(stat.mood);

      // 每个有记录的日子都有一层柔和光晕，字数越多越亮
      final glow = Paint()
        ..color = color.withValues(alpha: 0.10 + intensity * 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      final p = _pointAt(center, ringRadius, dayIndex, daysInYear);
      canvas.drawCircle(p, 3.0 + intensity * 3.2, glow);

      // 核心亮点
      final dot = Paint()..color = color.withValues(alpha: 0.75 + intensity * 0.25);
      canvas.drawCircle(p, 1.6 + intensity * 1.7, dot);

      // 选中日：加一圈描边
      if (selectedDay == entry.key) {
        final ring = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6;
        canvas.drawCircle(p, 7.0, ring);
      }
    }
  }

  /// 圆周上第 [dayIndex] 天（0 起）的坐标，12 点钟为起点、顺时针
  Offset _pointAt(Offset center, double radius, int dayIndex, int total) {
    final angle = (dayIndex / total) * 2 * math.pi - math.pi / 2;
    return Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
  }

  /// 某月 1 日是这一年的第几天（1 起）
  int _dayOfYearForMonth(int month) {
    const cumulative = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    return cumulative[month - 1] + 1;
  }

  /// 心情 emoji → 颜色
  ///
  /// 按 `MoodConstants` 的四类归并到四个色相上：正向→暖黄、平静→绿、
  /// 负面→蓝、特殊→橙。没有对应心情时用中性的金粉色。
  Color _colorForMood(String mood) {
    if (mood.isEmpty) {
      return isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    }
    const happy = {'😊', '🥰', '🙏'};
    const excited = {'🤩', '😲', '🤞'};
    const calm = {'😌', '😐', '🤔', '😴', '😑'};
    const sad = {'😢', '😰', '😤', '😫', '😔', '🥲', '🥹'};

    if (happy.contains(mood)) return AppColors.moodHappy;
    if (excited.contains(mood)) return AppColors.moodExcited;
    if (calm.contains(mood)) return AppColors.moodCalm;
    if (sad.contains(mood)) return AppColors.moodSad;
    return isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter old) {
    // 只在数据、选中项或主题变化时重绘 —— 圆盘有 365 次 drawCircle，
    // 每帧重建代价不低，必须严格判断。
    return old.dailyStats != dailyStats ||
        old.selectedDay != selectedDay ||
        old.daysInYear != daysInYear ||
        old.isDark != isDark;
  }
}

/// 把「第几天」转成人话（如 `9月14日`），供外部使用
///
/// 用非闰年做基准换算；闰年 3 月后会有 1 天偏差，仅用于展示可接受。
String constellationDayLabel(int dayOfYear) {
  final date = DateTime(2025, 1, 1).add(Duration(days: dayOfYear - 1));
  return '${date.month}月${date.day}日';
}

/// 供外部判断某年是否闰年（决定圆盘按 365 还是 366 等分）
bool isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// 心情 emoji → 中文标签，供星座图的中心文案使用
String moodLabelOf(String emoji) =>
    MoodConstants.findByEmoji(emoji)?['label'] ?? '';
