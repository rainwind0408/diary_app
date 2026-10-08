import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
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
/// - **金色指针** = 可拨动的游标：拖动它绕圆走，每跨过一天响一声「嗒」
class DiaryConstellation extends StatefulWidget {
  /// 每天的 {日序号(1~366): (words, mood)}
  final Map<int, ({int words, String mood})> dailyStats;

  /// 这一年是闰年吗（决定圆盘按 365 还是 366 等分）
  final bool isLeapYear;

  /// 点击某天
  final void Function(int dayOfYear)? onDayTap;

  /// true = 只渲染内容，不套卡片壳（由外层「写作年历」卡统一提供容器）
  final bool bare;

  const DiaryConstellation({
    super.key,
    required this.dailyStats,
    this.isLeapYear = false,
    this.onDayTap,
    this.bare = false,
  });

  @override
  State<DiaryConstellation> createState() => _DiaryConstellationState();
}

class _DiaryConstellationState extends State<DiaryConstellation> {
  /// 被点中的那天（显示在中心）
  int? _selectedDay;

  // ── 可拨动指针 ──

  /// 指针当前角度（**画布坐标**弧度，`-π/2` = 12 点钟方向）。
  ///
  /// 刻意让它**跟手**而不是吸附到刻度：吸附在快速拖动时会一跳一跳的；
  /// 而日期本身是按取整算的，语义已经足够明确。
  double _pointerAngle = -math.pi / 2;

  /// 指针音效。与齿轮是**两套采样**（更轻、更脆、更短），别混用。
  static const int _kTickVariants = 3;
  AudioPlayer? _player;
  int _tickSeq = 0;

  int get _daysInYear => widget.isLeapYear ? 366 : 365;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor =
        isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    final activeDays = widget.dailyStats.length;

    return Container(
      padding: widget.bare ? EdgeInsets.zero : const EdgeInsets.all(20),
      decoration: widget.bare
          ? null
          : BoxDecoration(
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
                child: RawGestureDetector(
                  // opaque：整块方形都算命中区。真正的「能不能拨」由
                  // 识别器自己判（只看有没有按在指针上），不靠命中测试。
                  behavior: HitTestBehavior.opaque,
                  gestures: {
                    _DialPanGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                            _DialPanGestureRecognizer>(
                      () => _DialPanGestureRecognizer(),
                      (r) {
                        // ⚠️ 这里**不能**写成级联（`r..hitTest = ... ..onStart = ...`）：
                        // 箭头函数的 body 会把后面的 `..onStart` 一起吞进去，
                        // 于是它被级联到 `_hitsPointer(...)` 返回的 `bool` 上
                        // → `The setter 'onStart' isn't defined for the type 'bool'`。
                        // hitTest 必须每帧刷新：闭包里带着 LayoutBuilder 量出的
                        // size 和**当前**指针角度，而识别器实例是复用的，
                        // 只有 initializer 会被重跑。
                        r.hitTest = (p) => _hitsPointer(p, size);
                        r.onStart = (d) => _handlePan(d.localPosition, size);
                        r.onUpdate = (d) => _handlePan(d.localPosition, size);
                        // 拖动过程中只更新选中，**松手才回调** ——
                        // 否则手指划过一百天就会触发一百次 onDayTap。
                        r.onEnd = (_) {
                          final day = _selectedDay;
                          if (day != null) widget.onDayTap?.call(day);
                        };
                      },
                    ),
                  },
                  child: GestureDetector(
                    onTapUp: (details) => _handleTap(details, size),
                    child: CustomPaint(
                      painter: _ConstellationPainter(
                        dailyStats: widget.dailyStats,
                        daysInYear: _daysInYear,
                        selectedDay: _selectedDay,
                        pointerAngle: _pointerAngle,
                        isDark: isDark,
                        subtleColor: subtleColor,
                      ),
                      child: _buildCenterLabel(isDark, textColor, subtleColor),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 14),
          _buildLegend(subtleColor),
          const SizedBox(height: 10),
          // 指针是「可拨动」的，但不写提示没人会想到去拖它 —— 一行小字，成本极低。
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_outlined, size: 12, color: subtleColor),
              const SizedBox(width: 4),
              Text(
                '拖动金色指针，或点圆盘上任意一天',
                style: TextStyle(fontSize: 10, color: subtleColor),
              ),
            ],
          ),
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
  /// 点击同时**把指针拨到那个方向** —— 否则会出现「选中了 5 月、
  /// 指针还杵在 1 月」的割裂感。
  void _handleTap(TapUpDetails details, double size) {
    final center = Offset(size / 2, size / 2);
    final v = details.localPosition - center;
    final dist = v.distance;
    final outer = size / 2;
    if (dist < outer * 0.30 || dist > outer * 1.05) return;

    final angle = math.atan2(v.dy, v.dx);
    final day = _dayFromCanvasAngle(angle);

    setState(() {
      _pointerAngle = angle;
      _selectedDay = day;
    });
    widget.onDayTap?.call(day);
  }

  /// 拖动指针。
  ///
  /// 指针**跟手**（不吸附到刻度）—— 吸附在快速拖动时会一跳一跳的，
  /// 手感很差；而「选中哪天」是拿角度取整算出来的，语义已经足够明确。
  /// 每跨过一天响一声「嗒」，正好对应圆盘上 365 个刻度。
  void _handlePan(Offset local, double size) {
    final center = Offset(size / 2, size / 2);
    final v = local - center;
    // 太靠近圆心时角度会剧烈抖动（半径趋近 0），直接丢掉这一帧
    if (v.distance < size * 0.04) return;

    final angle = math.atan2(v.dy, v.dx);
    final day = _dayFromCanvasAngle(angle);

    // 只在「跨过一天」时出声。同一天内手指微抖不该响。
    if (day != _selectedDay) _pointerTick();

    setState(() {
      _pointerAngle = angle;
      _selectedDay = day;
    });
  }

  /// 画布角度（0 = 3 点钟方向、顺时针为正）→ 日序号（1 起）
  ///
  /// 圆盘的约定是「12 点钟 = 1 月 1 日」，所以先转 90° 把起点挪到正上方。
  /// 与 [onDayTap] 的回调值、[_ConstellationPainter._pointAt] 的排布
  /// 共用同一个约定 —— 三处必须一致，否则指针指的日期和点亮的点会错位。
  int _dayFromCanvasAngle(double canvasAngle) {
    var a = canvasAngle + math.pi / 2;
    if (a < 0) a += 2 * math.pi;
    final fraction = a / (2 * math.pi);
    return ((fraction * _daysInYear).floor() + 1).clamp(1, _daysInYear);
  }

  /// 指针拨动音效。
  ///
  /// 与齿轮是**两套采样**，别混用 —— 齿轮是 90ms 的金属共鸣（低通），
  /// 指针是 55ms 的高频脆响（高通），混起来就分不清在拨哪个了。
  /// 3 个变体轮换，避免听出同一个采样在重复。
  void _pointerTick() {
    final p = _player ??= AudioPlayer();
    final n = (_tickSeq++ % _kTickVariants) + 1;
    // lowLatency = SoundPool 语义：上一条还没播完就丢弃。
    // 快速划过时正好变成一串「嗒嗒嗒」，而不是糊成噪音。
    p.play(
      AssetSource('audio/dial_tick_$n.wav'),
      mode: PlayerMode.lowLatency,
      volume: 0.5,
    );
  }

  /// 指针在**本组件坐标系**里的尾端与针尖。
  ///
  /// 与 [_ConstellationPainter] 共用 [_Dial] 里的同一套常量，
  /// 所以「画出来的针」和「抓得到的针」必然是同一根 ——
  /// 两边各写一份字面量的话，改一处就会变成「看得见却抓不到」。
  ({Offset tail, Offset tip}) _pointerEnds(double size) {
    final center = Offset(size / 2, size / 2);
    final ringRadius = size / 2 * _Dial.ringRatio;
    final dir = Offset(math.cos(_pointerAngle), math.sin(_pointerAngle));
    return (
      tail: center - dir * (ringRadius * _Dial.tailRatio),
      tip: center + dir * (ringRadius * _Dial.tipRatio),
    );
  }

  /// 按下点是否落在指针的可抓区域里。
  ///
  /// 故意做得**比针身宽**（22px 容差）：针只有 1.8px 粗，严格命中等于
  /// 抓不到。读数头再单独给一个 20px 的圆 —— 它是视觉上的「把手」。
  bool _hitsPointer(Offset p, double size) {
    final ends = _pointerEnds(size);
    if ((p - ends.tip).distance <= _Dial.knobGrab) return true;
    return _distanceToSegment(p, ends.tail, ends.tip) <= _Dial.grabTolerance;
  }

  /// 点到线段的最短距离
  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    // 投影参数钳到 [0,1]，保证落在线段内而不是它的延长线上
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2)
        .clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  static String _dayLabel(int dayOfYear) => constellationDayLabel(dayOfYear);
}

/// 圆盘几何常量 —— State 与 [_ConstellationPainter] **共用**，改一处即可。
class _Dial {
  const _Dial._();

  /// 圆环半径 / 外半径
  static const double ringRatio = 0.84;

  /// 针尖 / 圆环半径。略超出去 —— 刻度点在环上，读数头要能「指到」它们
  static const double tipRatio = 1.06;

  /// 尾端 / 圆环半径
  static const double tailRatio = 0.18;

  /// 抓取容差（逻辑像素）：手指到针身的距离小于它就算抓住了
  static const double grabTolerance = 22;

  /// 读数头的抓取半径
  static const double knobGrab = 20;
}

/// 「只有抓住指针才算数」的拖动识别器。
///
/// ## 为什么不能直接用 `GestureDetector(onPanUpdate:)`
/// 星座图分别住在 `ListView`（回顾页）和 `PageView`（年报页）里。
/// 那两个容器的拖动识别器 slop 只有 `kTouchSlop`(18px)，而 pan 要
/// `kPanSlop`(36px) —— 手指一动就被父级抢走，指针**永远拨不动**：
/// 回顾页竖向拖 = 滚列表，年报页横向拖 = 翻页。
///
/// ## 解法
/// 按下时先看是不是按在指针上：
/// - 是 → 立刻 `resolve(accepted)` 抢下手势，父级拿不到这一串事件；
/// - 否 → **根本不进竞技场**（不调 `super`），父级滚动 / 翻页照常。
///
/// 代价：按在指针上时页面滚不动。但这正是用户想要的 —— 他正在拨针。
class _DialPanGestureRecognizer extends PanGestureRecognizer {
  /// 命中判定。**必须每帧刷新** —— 闭包里带着 LayoutBuilder 量出的 `size`
  /// 与当前的指针角度，而识别器实例是复用的。
  bool Function(Offset localPosition)? hitTest;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final hit = hitTest;
    if (hit == null || !hit(event.localPosition)) return;
    super.addAllowedPointer(event);
    // 此刻竞技场还是 open 的，所以这次 accept 先记成 eagerWinner；
    // 等 pointer-down 派发结束、arena 关闭时立刻生效。父级识别器是同一轮
    // 里后加入的，必然排在它后面、直接被判负。
    resolve(GestureDisposition.accepted);
  }
}

class _ConstellationPainter extends CustomPainter {
  final Map<int, ({int words, String mood})> dailyStats;
  final int daysInYear;
  final int? selectedDay;

  /// 金色指针的画布角度（弧度，0 = 3 点钟方向、顺时针为正）
  final double pointerAngle;

  final bool isDark;
  final Color subtleColor;

  _ConstellationPainter({
    required this.dailyStats,
    required this.daysInYear,
    required this.selectedDay,
    required this.pointerAngle,
    required this.isDark,
    required this.subtleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2;
    final ringRadius = outer * _Dial.ringRatio;

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

    // 指针画在**最后** —— 它必须压在数据点之上，
    // 否则会被光晕糊掉，看起来像蒙了一层雾。
    _paintPointer(canvas, center, ringRadius);
  }

  /// 金色指针：从圆心附近伸出到圆环外侧，尾部留一小段配重。
  ///
  /// 针尖刻意越过圆环（`ringRadius * 1.06`）—— 刻度点在环上，
  /// 读数头要能「指到」它们而不是压在中间。
  void _paintPointer(Canvas canvas, Offset center, double ringRadius) {
    // 浅色用 `goldPointer` 而不是 `goldAccent`：后者在米白卡纸上只有 1.68:1，
    // 画装饰够用，当「要用手抓的控件」太淡。深色主题的 `darkGoldAccent`
    // 本来就有 8.2:1，不用换。
    final gold = isDark ? AppColors.darkGoldAccent : AppColors.goldPointer;
    final dir = Offset(math.cos(pointerAngle), math.sin(pointerAngle));
    final tip = center + dir * (ringRadius * _Dial.tipRatio);
    final tail = center - dir * (ringRadius * _Dial.tailRatio);

    // 外发光：金色压在浅色卡纸 / 深色底上都要「亮」起来，靠一层模糊描边实现
    final glow = Paint()
      ..color = gold.withValues(alpha: 0.35)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawLine(tail, tip, glow);

    // 针身。比装饰线粗一档 —— 它是抓手，不是花纹。
    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..color = gold
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // 读数头：实心点 + 一圈淡环
    canvas.drawCircle(tip, 2.6, Paint()..color = gold);
    canvas.drawCircle(
      tip,
      5.4,
      Paint()
        ..color = gold.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 尾部配重
    canvas.drawCircle(tail, 2.0, Paint()..color = gold.withValues(alpha: 0.75));

    // 中心轴：让指针「有支点」，否则像一根飘着的火柴
    canvas.drawCircle(center, 3.2, Paint()..color = gold);
    canvas.drawCircle(
      center,
      6.0,
      Paint()
        ..color = gold.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
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
    // 只在数据、选中项、指针角度或主题变化时重绘 —— 圆盘有 365 次 drawCircle，
    // 每帧重建代价不低，必须严格判断。
    // ⚠️ pointerAngle 必须比：拖动指针时只有它在变，漏了就等于指针卡住不动。
    return old.dailyStats != dailyStats ||
        old.selectedDay != selectedDay ||
        old.daysInYear != daysInYear ||
        old.pointerAngle != pointerAngle ||
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
