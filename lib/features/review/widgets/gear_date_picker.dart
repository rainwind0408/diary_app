import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';

// ═══════════════════ 齿轮几何参数（顶层常量，State / Wheel / Painter 共用）═══════════════════
//
// 三个齿轮必须共用同一个**模数** `m`，齿距才会相同（`p = π·m`），才能咬合。
// 「年 < 月 < 周」= 齿数递增；分度圆直径 `d = m·z` 随之递增。
//
// 真实齿轮的三个圆（这里都按标准取值，不手调）：
//   分度圆  d      = m·z          ← 啮合发生在这一圈
//   齿顶圆  d + 2m                  ← 齿轮外廓（也是本组件的布局尺寸）
//   齿根圆  d − 2.5m                ← 齿轮本体
// 圆心距 = 两分度圆半径之和 = m·(z_i + z_j) / 2（**标准公式，不需要"重叠量"这种手调参数**），
// 于是齿顶插进邻轮齿根，顶隙恰好 0.25m。
const double _kModule = 5.2;
const int _kTeethYear = 16;
const int _kTeethMonth = 20;
const int _kTeethWeek = 24;

/// 下标顺序固定为 年(0) / 月(1) / 周(2)，传动公式里的 `i−k` 依赖它。
const List<int> _kTeeth = [_kTeethYear, _kTeethMonth, _kTeethWeek];

const double _kAddendum = _kModule; // 齿顶高 = 1.0 m
const double _kDedendum = 1.25 * _kModule; // 齿根高 = 1.25 m
const double _kToothHeight = _kAddendum + _kDedendum; // 全齿高 = 2.25 m

/// 齿顶圆直径（布局尺寸）：`m·(z + 2)`
const double _kOutYear = _kModule * (_kTeethYear + 2); // 93.6
const double _kOutMonth = _kModule * (_kTeethMonth + 2); // 114.4
const double _kOutWeek = _kModule * (_kTeethWeek + 2); // 135.2

const List<double> _kOuterD = [_kOutYear, _kOutMonth, _kOutWeek];

/// 光源方向（画布坐标，y 轴向下 → −3π/4 是左上）。
/// 明暗按齿在**世界坐标**里的实际角度算，所以光不跟着齿轮转。
const double _kLightAngle = -3 * math.pi / 4;

/// 圆心距 = 两**分度圆**半径之和（标准啮合公式）
const double _kGapYearMonth = _kModule * (_kTeethYear + _kTeethMonth) / 2; // 93.6
const double _kGapMonthWeek = _kModule * (_kTeethMonth + _kTeethWeek) / 2; // 114.4

const double _kCxYear = _kOutYear / 2; // 46.8
const double _kCxMonth = _kCxYear + _kGapYearMonth; // 140.4
const double _kCxWeek = _kCxMonth + _kGapMonthWeek; // 254.8

/// 三个圆心的 x（y 一律是画布中线）
const List<double> _kCenterX = [_kCxYear, _kCxMonth, _kCxWeek];

const double _kTotalW = _kCxWeek + _kOutWeek / 2; // 322.4
const double _kTotalH = _kOutWeek; // 135.2

/// 三齿轮咬合日期检索器。
///
/// 交互隐喻：年 / 月 / 周是三个互相咬合的齿轮，**用手指直接把齿轮本体转起来**
/// （不是滑动里面的数字 —— 里面的数字只是读数窗口，固定朝上不跟着转）。
///
/// 三条物理约定：
/// 1. **转动任意一个齿轮，另外两个的齿圈按齿数比跟着转**（刚性耦合：一轮走过
///    n 个齿，整列都走过 n 个齿；相邻外啮合反向、隔一个同向）。
/// 2. **只有被手指转的那个齿轮会改数字**，从动轮只转齿圈、数值不动。
/// 3. 松手吸附到最近的齿位（每个齿 = 一个档位），落位时响一声。
///
/// 选中的日期 = 该年 · 该月 · 当月第 N 周的周一（永不出现非法日期）。
/// 音效常开（2026-10-08 起不再提供开关）。
///
/// 初始角度**不能是 0**：必须用 [_GearDatePickerState._solvePhase] 递推出来的
/// 初相位，否则 t=0 就齿顶齿、每转半个齿距再撞一次（表现为穿模 / 卡顿）。
/// 推导与穷举证明见 `不推送/验证脚本/2026-10-05/tmp_verify_gear_geometry.dart`。
class GearDatePicker extends StatefulWidget {
  /// 初始选中日期（内部会归一到所在周的周一）
  final DateTime initialDate;

  /// 日期变化回调（转动停稳约 200ms 后触发，避免拖动中反复查库）
  final ValueChanged<DateTime>? onDateChanged;

  const GearDatePicker({
    super.key,
    required this.initialDate,
    this.onDateChanged,
  });

  @override
  State<GearDatePicker> createState() => _GearDatePickerState();
}

class _GearDatePickerState extends State<GearDatePicker>
    with SingleTickerProviderStateMixin {
  // ── 初相位（关键）──
  // φ₀ = 0（年轮一颗齿正对 +x，即指向月轮），之后：
  //   φ_{i+1} ≡ π − (2π/z_{i+1}) · (0.5 + φ_i · z_i / 2π)   (mod 2π/z_{i+1})
  // 结果：年 0 / 月 −π/20（−9°）/ 周 0
  static const double _kPhaseYear = 0.0;
  static final double _kPhaseMonth =
      _solvePhase(_kPhaseYear, _kTeethYear, _kTeethMonth);
  static final double _kPhaseWeek =
      _solvePhase(_kPhaseMonth, _kTeethMonth, _kTeethWeek);

  static const int _kStartYear = 2020;

  /// 音效变体个数（`assets/audio/gear_tick_{1..N}.wav`）
  static const int _kSoundVariants = 3;

  late final List<int> _years;

  int _yearIdx = 0;
  int _monthIdx = 0;
  int _weekIdx = 0;

  // 三个齿圈的视觉转角（弧度）。从动轮只转齿圈、不改数值。
  double _angleYear = _kPhaseYear;
  double _angleMonth = _kPhaseMonth;
  double _angleWeek = _kPhaseWeek;

  // ── 拖动状态 ──
  /// 正在被手指转的齿轮下标，−1 = 没在拖
  int _dragGear = -1;

  /// 上一次手指相对该轮圆心的角度（弧度）
  double _dragLastFinger = 0;

  /// 主动轮自本次按下起累计转过的角度（弧度，**不回绕**，用来数齿）
  double _dragRot = 0;

  /// [_dragRot] 的硬止挡 —— 数值到端点后齿轮就转不动了
  double _dragMinRot = 0;
  double _dragMaxRot = 0;

  /// 按下瞬间的数值下标，换档时以它为基准
  int _dragStartIdx = 0;

  /// 已经响过/应用过的齿数
  int _dragSteps = 0;

  // ── 松手吸附 ──
  late final AnimationController _snapAnim;
  int _snapGear = -1;
  double _snapApplied = 0;
  double _snapTo = 0;

  Timer? _debounce;
  AudioPlayer? _player;
  int _tickSeq = 0;

  @override
  void initState() {
    super.initState();
    final thisYear = DateTime.now().year;
    _years = [
      for (var y = _kStartYear; y <= thisYear + 1; y++) y,
    ];
    final d = _normalize(widget.initialDate);
    _yearIdx = (d.year - _kStartYear).clamp(0, _years.length - 1);
    _monthIdx = d.month - 1;
    _weekIdx = _weekIndexOf(d, _weekCount(_years[_yearIdx], _monthIdx + 1));

    _snapAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )
      ..addListener(_onSnapTick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _onSnapDone();
      });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _snapAnim.dispose();
    _player?.dispose();
    super.dispose();
  }

  // ---- 日期语义：该年·该月·当月第 N 周的周一 ----

  /// 把任意日期归一到它所在（月历网格第 N 周）的那一周的周一
  static DateTime _normalize(DateTime d) {
    final first = DateTime(d.year, d.month, 1);
    final offset = first.weekday - 1; // 周一=1 → 偏移 0
    return DateTime(d.year, d.month, 1 - offset + _weekOf(d) * 7);
  }

  /// 日期落在当月网格的第几周（0-based）
  static int _weekOf(DateTime d) {
    final first = DateTime(d.year, d.month, 1);
    final offset = first.weekday - 1;
    return (offset + d.day - 1) ~/ 7;
  }

  /// 某年某月一共有几"周"（含首尾不满一周的）
  static int _weekCount(int year, int month) {
    final first = DateTime(year, month, 1);
    final days = DateTime(year, month + 1, 0).day;
    final offset = first.weekday - 1;
    return ((offset + days) + 6) ~/ 7;
  }

  /// 日期在该月网格中的周下标（带钳制）
  int _weekIndexOf(DateTime d, int weeks) => _weekOf(d).clamp(0, weeks - 1);

  /// 当前选中日期 = 第 _weekIdx 周的周一
  DateTime get _selectedDate {
    final year = _years[_yearIdx];
    final month = _monthIdx + 1;
    final first = DateTime(year, month, 1);
    final offset = first.weekday - 1;
    return DateTime(year, month, 1 - offset + _weekIdx * 7);
  }

  // ---- 数值下标读写 ----

  int _idxOf(int k) {
    if (k == 0) return _yearIdx;
    if (k == 1) return _monthIdx;
    return _weekIdx;
  }

  int _maxIdxOf(int k) {
    if (k == 0) return _years.length - 1;
    if (k == 1) return 11;
    return _weekCount(_years[_yearIdx], _monthIdx + 1) - 1;
  }

  void _setIdx(int k, int v) {
    final clamped = v.clamp(0, _maxIdxOf(k));
    if (k == 0) {
      _yearIdx = clamped;
    } else if (k == 1) {
      _monthIdx = clamped;
    } else {
      _weekIdx = clamped;
    }
  }

  /// 一个齿距对应的转角
  static double _toothOf(int k) => 2 * math.pi / _kTeeth[k];

  // ---- 齿轮传动 ----

  /// 由「上一轮的初相位」解出「下一轮的初相位」。
  ///
  /// 咬合要求：第 i 轮在角度 0（+x）出齿时，第 i+1 轮必须在角度 π（−x）出**槽**
  /// （槽在两齿正中，偏移半个齿距）。把两边的相位写成「走过的齿数 u」的线性式，
  /// 相减即可消掉 u，得到一条与时间无关的常量条件，解出上式。
  static double _solvePhase(double phiPrev, int zPrev, int zNext) {
    final pitch = 2 * math.pi / zNext;
    var v = math.pi - pitch * (0.5 + phiPrev * zPrev / (2 * math.pi));
    v -= (v / pitch).floorToDouble() * pitch; // → [0, pitch)
    if (v >= pitch / 2) v -= pitch; // → [−pitch/2, pitch/2)
    return v;
  }

  /// 逐轮独立回绕到 [0, 2π)。
  ///
  /// 齿的分布是 2π 周期的，所以逐轮回绕**不会**改变齿轮间的相对相位。
  /// 不回绕的话，长时间来回拨能累加到几千弧度，float 精度会慢慢掉。
  static double _wrap(double a) {
    const turn = 2 * math.pi;
    final r = a % turn;
    return r < 0 ? r + turn : r;
  }

  /// 把「第 [k] 轮转了 [dPhi] 弧度」这个运动传给整列齿轮。
  ///
  /// 一列外啮合齿轮是**刚性耦合**的：啮合处齿数守恒，所以任何一轮走过 `n` 个齿，
  /// 整列都走过 `n` 个齿 —— 相邻反向、隔一个同向，角度按齿数反比：
  ///
  ///     Δφ_j = dPhi · (z_k / z_j) · (−1)^(j−k)
  ///
  /// ⚠️ 不要写成「主动轮转 dPhi、被动轮一律 `−dPhi · z主/z被`」——
  /// 那等于假设每个被动轮都紧挨着主动轮，**周轮会被反向转**（真实齿轮列里
  /// 年轮与周轮隔着月轮，必须同向）。齿圈旋转对称，这个错**不报错**。
  void _applyRotation(int k, double dPhi) {
    if (dPhi == 0) return;
    final angles = [_angleYear, _angleMonth, _angleWeek];
    for (var j = 0; j < 3; j++) {
      final sign = ((j - k) % 2 == 0) ? 1.0 : -1.0; // (−1)^(j−k)
      angles[j] = _wrap(angles[j] + dPhi * _kTeeth[k] / _kTeeth[j] * sign);
    }
    _angleYear = angles[0];
    _angleMonth = angles[1];
    _angleWeek = angles[2];
  }

  void _tick() {
    // 每个档位 = 一个齿，所以「每啮合一次响一声」在物理上就是对的；
    // 3 个音色轮换，避免听出同一个采样在重复。
    // lowLatency = SoundPool 语义：上一条还没播完就丢弃。
    final p = _player ??= AudioPlayer();
    final n = (_tickSeq++ % _kSoundVariants) + 1;
    p.play(
      AssetSource('audio/gear_tick_$n.wav'),
      mode: PlayerMode.lowLatency,
      volume: 0.45,
    );
  }

  void _scheduleNotify() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      widget.onDateChanged?.call(_selectedDate);
    });
  }

  /// 年/月变化后，周数可能变少 —— 把周轮钳回合法档位。
  ///
  /// 这是唯一会「非主动地」改变某个齿轮数值的地方，属于语义必需：
  /// 2 月只有 4 周时不能停在"第 5 周"，否则 [_selectedDate] 会落到下个月。
  /// 只改数值、**不动齿圈角度**（齿圈永远由传动链决定）。
  void _clampWeek() {
    final weeks = _weekCount(_years[_yearIdx], _monthIdx + 1);
    if (_weekIdx > weeks - 1) _weekIdx = weeks - 1;
  }

  // ---- 拖动（直接转齿轮本体）----

  static Offset _centerOf(int k) => Offset(_kCenterX[k], _kTotalH / 2);

  /// 命中哪个齿轮：落在**齿顶圆**内、且圆心最近的那个。
  ///
  /// ⚠️ 不能用矩形命中测试：三圆两两相切，包围盒在角落处**互相重叠**，
  /// 按矩形判会让角落的触摸落到上层（周轮）上 —— 明明按在年轮的空角里，
  /// 动的却是周轮。
  static int _gearAt(Offset p) {
    var best = -1;
    var bestDist = double.infinity;
    for (var k = 0; k < 3; k++) {
      final d = (p - _centerOf(k)).distance;
      if (d <= _kOuterD[k] / 2 && d < bestDist) {
        best = k;
        bestDist = d;
      }
    }
    return best;
  }

  void _onDragStart(Offset p) {
    final k = _gearAt(p);
    if (k < 0) return;
    _snapAnim.stop();
    _snapGear = -1;

    _dragGear = k;
    _dragStartIdx = _idxOf(k);
    _dragSteps = 0;
    _dragRot = 0;
    final tooth = _toothOf(k);
    // 硬止挡：数值到端点后齿轮就顶住了，手指再动也不转
    _dragMinRot = -_dragStartIdx * tooth;
    _dragMaxRot = (_maxIdxOf(k) - _dragStartIdx) * tooth;
    _dragLastFinger = (p - _centerOf(k)).direction;
    setState(() {});
  }

  void _onDragUpdate(Offset p) {
    final k = _dragGear;
    if (k < 0) return;

    final a = (p - _centerOf(k)).direction;
    var d = a - _dragLastFinger;
    // 手指绕过 ±π 时 atan2 会跳 2π，取最短路径，否则齿轮会突然倒转一圈
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d <= -math.pi) {
      d += 2 * math.pi;
    }
    _dragLastFinger = a;

    final before = _dragRot;
    _dragRot = (_dragRot + d).clamp(_dragMinRot, _dragMaxRot);
    final applied = _dragRot - before;
    // 转过半齿就换档 —— 与松手吸附同一套判据，中途松手不会跳数字
    final steps = (_dragRot / _toothOf(k)).round();
    if (applied == 0 && steps == _dragSteps) return;

    if (applied != 0) _applyRotation(k, applied);
    if (steps != _dragSteps) {
      _dragSteps = steps;
      _setIdx(k, _dragStartIdx + steps);
      if (k != 2) _clampWeek();
      _tick();
      HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  void _onDragEnd() {
    final k = _dragGear;
    if (k < 0) return;
    _dragGear = -1;

    final tooth = _toothOf(k);
    final residual = (_dragRot / tooth).round() * tooth - _dragRot;
    if (residual.abs() < 0.001) {
      _snapGear = -1;
      setState(() {});
      _scheduleNotify();
      return;
    }
    // 吸附：把主动轮补到最近的齿位。因为整列是刚性耦合的，这一下会让
    // 三个齿轮一起微动 —— 物理上正确（它们本来就连在一起）。
    _snapGear = k;
    _snapApplied = 0;
    _snapTo = residual;
    _snapAnim.forward(from: 0);
    setState(() {});
  }

  void _onSnapTick() {
    if (_snapGear < 0) return;
    final v = Curves.easeOut.transform(_snapAnim.value) * _snapTo;
    _applyRotation(_snapGear, v - _snapApplied);
    _snapApplied = v;
    setState(() {});
  }

  void _onSnapDone() {
    _snapGear = -1;
    _snapApplied = 0;
    _scheduleNotify();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeks = _weekCount(_years[_yearIdx], _monthIdx + 1);
    final gold = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final subtle =
        (isDark ? AppColors.darkTitleText : AppColors.titleText);
    // 正在被手指转 / 正在吸附的那个轮高亮一下，明确"谁在动"
    final active = _dragGear >= 0 ? _dragGear : _snapGear;

    Widget gearAt(int k, Widget child) => Positioned(
          left: _kCenterX[k] - _kOuterD[k] / 2,
          top: (_kTotalH - _kOuterD[k]) / 2,
          width: _kOuterD[k],
          height: _kOuterD[k],
          child: child,
        );

    return Column(
      children: [
        // 三个齿轮总宽 322.4，放进「ListView 20 + AppCard 16」之后
        // 只剩 362.7 - 72 ≈ 291（这台机器 1224/3.375），**仍会溢出**。
        //
        // 不能靠改小直径糊过去：换个 320dp 的窄屏还是溢出。这里用
        // FittedBox 等比缩到刚好放下 —— 齿数比、咬合相位全部保持原样，
        // 只是整体变小；宽屏时 scaleDown 不会放大。
        // 手势坐标也随之等比换算，命中判定不受影响。
        FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: _kTotalW,
            height: _kTotalH,
            child: RawGestureDetector(
              // opaque：整块方形都算命中区。真正的「能不能转」由识别器自己判
              // （只看有没有按在某个齿顶圆内），不靠矩形命中测试。
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                _GearDragRecognizer:
                    GestureRecognizerFactoryWithHandlers<_GearDragRecognizer>(
                  () => _GearDragRecognizer(),
                  (r) {
                    // ⚠️ 这里**不能**写成级联（`r..hitTest = ... ..onStart = ...`）：
                    // 箭头函数的 body 会把后面的 `..onStart` 一起吞进去，
                    // 于是它被级联到 `_gearAt(p) >= 0` 返回的 `bool` 上
                    // → `The setter 'onStart' isn't defined for the type 'bool'`。
                    r.hitTest = (p) => _gearAt(p) >= 0;
                    r.onStart = (d) => _onDragStart(d.localPosition);
                    r.onUpdate = (d) => _onDragUpdate(d.localPosition);
                    r.onEnd = (_) => _onDragEnd();
                    r.onCancel = _onDragEnd;
                  },
                ),
              },
              child: Stack(
                children: [
                  gearAt(
                    0,
                    _GearWheel(
                      angle: _angleYear,
                      teeth: _kTeethYear,
                      diameter: _kOutYear,
                      gold: gold,
                      isDark: isDark,
                      active: active == 0,
                      label: '${_years[_yearIdx]}',
                      unit: '年',
                    ),
                  ),
                  gearAt(
                    1,
                    _GearWheel(
                      angle: _angleMonth,
                      teeth: _kTeethMonth,
                      diameter: _kOutMonth,
                      gold: gold,
                      isDark: isDark,
                      active: active == 1,
                      label: '${_monthIdx + 1}',
                      unit: '月',
                    ),
                  ),
                  gearAt(
                    2,
                    _GearWheel(
                      angle: _angleWeek,
                      teeth: _kTeethWeek,
                      diameter: _kOutWeek,
                      gold: gold,
                      isDark: isDark,
                      active: active == 2,
                      label: '${_weekIdx + 1}',
                      unit: '周',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '按住齿轮拖动 · 只有被转的那个齿轮会改数字（$weeks 周）',
          style: TextStyle(
            fontSize: 11,
            color: subtle.withValues(alpha: 0.42),
          ),
        ),
      ],
    );
  }
}

/// 单个齿轮轮盘：外圈是 CustomPaint 画的齿圈（随转动角旋转），
/// 中心是**固定朝上的数值读数**。
///
/// 读数不跟齿圈转 —— 转的是齿轮，数字是窗口里的读数。
/// 从动轮"被带着转"的视觉就靠这里：**只有 `angle` 变，label 不动**。
class _GearWheel extends StatelessWidget {
  final double angle;
  final int teeth;

  /// 齿顶圆直径（= 布局尺寸）
  final double diameter;
  final Color gold;
  final bool isDark;

  /// 是否正在被手指转动（或正在吸附）
  final bool active;
  final String label;
  final String unit;

  const _GearWheel({
    required this.angle,
    required this.teeth,
    required this.diameter,
    required this.gold,
    required this.isDark,
    required this.active,
    required this.label,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg =
        isDark ? AppColors.darkCardBackgroundAlt : AppColors.cardBackgroundAlt;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;

    // 数值窗口按**齿根圆**取，保证落在齿轮本体内、不压到齿圈
    final rootD = diameter - 2 * _kToothHeight;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedCustomPaint(
              angle: angle,
              teeth: teeth,
              diameter: diameter,
              ringColor: gold.withValues(alpha: active ? 0.95 : 0.55),
              fillColor: cardBg,
            ),
          ),
          // 数值读数（不随齿圈旋转）
          SizedBox(
            width: rootD * 0.92,
            height: rootD * 0.84,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(fontSize: 10, color: gold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「只有按在某个齿轮的齿顶圆内才算数」的拖动识别器。
///
/// ## 为什么不能直接用 `GestureDetector(onPanUpdate:)`
/// 齿轮检索器住在回顾页的 `ListView` 里。那个容器的竖向拖动识别器 slop 只有
/// `kTouchSlop`(18px)，而 pan 要 `kPanSlop`(36px) —— 手指一动就被父级抢走，
/// 齿轮**永远转不动**（竖向拖 = 滚列表）。
///
/// ## 解法
/// 按下时先看是不是按在某个齿轮上：
/// - 是 → 立刻 `resolve(accepted)` 抢下手势，父级拿不到这一串事件；
/// - 否 → **根本不进竞技场**（不调 `super`），父级滚动照常。
///
/// 与星座图 `_DialPanGestureRecognizer` 同一范式（`diary_constellation.dart`）。
/// 代价：按在齿轮上时页面滚不动 —— 但这正是用户想要的，他正在转齿轮。
class _GearDragRecognizer extends PanGestureRecognizer {
  /// 命中判定。识别器实例是被复用的，闭包每帧重设，所以这里读的是最新状态。
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

/// 转角变化的齿圈。shouldRepaint 只比角度 / 齿数 / 直径，静止时不重绘。
class AnimatedCustomPaint extends StatelessWidget {
  final double angle;
  final int teeth;
  final double diameter;
  final Color ringColor;
  final Color fillColor;

  const AnimatedCustomPaint({
    super.key,
    required this.angle,
    required this.teeth,
    required this.diameter,
    required this.ringColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GearPainter(
        angle: angle,
        teeth: teeth,
        diameter: diameter,
        ringColor: ringColor,
        fillColor: fillColor,
      ),
    );
  }
}

/// 单个齿的轮廓（指向 +x，以齿中心线为对称轴）。
///
/// 梯形 + 齿顶圆角 + 齿根过渡 —— 圆角矩形看着像"方齿贴片"，
/// 梯形外窄内宽才像真齿。齿厚约 0.56 齿距、槽宽约 0.44 齿距（留一点侧隙）。
Path _toothPath(double rTip, double rRoot, double wRoot, double wTip) {
  return Path()
    ..moveTo(rRoot * math.cos(wRoot), rRoot * math.sin(wRoot))
    ..lineTo(rTip * math.cos(wTip), rTip * math.sin(wTip))
    // 齿顶圆角：控制点略微外扩，形成一个圆头
    ..quadraticBezierTo(
      rTip + (rTip - rRoot) * 0.08,
      0,
      rTip * math.cos(-wTip),
      rTip * math.sin(-wTip),
    )
    ..lineTo(rRoot * math.cos(-wRoot), rRoot * math.sin(-wRoot))
    // 齿根过渡：控制点落在齿根圆上，让齿根贴着根圆
    ..quadraticBezierTo(
      rRoot,
      0,
      rRoot * math.cos(wRoot),
      rRoot * math.sin(wRoot),
    )
    ..close();
}

class _GearPainter extends CustomPainter {
  final double angle;
  final int teeth;
  final double diameter;
  final Color ringColor;
  final Color fillColor;

  _GearPainter({
    required this.angle,
    required this.teeth,
    required this.diameter,
    required this.ringColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.shortestSide / 2; // 齿顶圆半径

    // 由齿顶圆反推模数：d_顶 = m·(z+2) → m = 2·outer/(z+2)
    final module = 2 * outer / (teeth + 2);
    final rRoot = outer - (module * 2.25); // 齿根圆 = 齿顶圆 − 全齿高
    final pitch = 2 * math.pi / teeth; // 齿距角

    // ── 1. 齿轮本体（齿根圆）+ 轮毂装饰环 ──
    canvas.drawCircle(center, rRoot, Paint()..color = fillColor);
    canvas.drawCircle(
      center,
      rRoot,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = ringColor,
    );
    // 再往里会被数值读数盖住，只描一圈做视觉收口
    canvas.drawCircle(
      center,
      rRoot * 0.90,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = ringColor.withValues(alpha: 0.25),
    );

    // ── 2. 齿 ──
    final wRoot = pitch * 0.28; // 齿根半宽（弧度）
    final wTip = pitch * 0.17; // 齿顶半宽（弧度）
    final path = _toothPath(outer, rRoot, wRoot, wTip);

    // 12 档明暗（量化后预生成，避免每帧几十次 HSL 转换）
    final hsl = HSLColor.fromColor(ringColor);
    final shades = List<Color>.generate(
      12,
      (k) => hsl
          .withLightness((hsl.lightness * (0.62 + 0.55 * ((k + 0.5) / 12)))
              .clamp(0.0, 1.0))
          .toColor(),
    );
    final toothPaint = Paint();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    for (var i = 0; i < teeth; i++) {
      canvas.save();
      canvas.rotate(i * pitch);
      final world = angle + i * pitch; // 该齿在世界坐标里的实际角度
      final lum = 0.5 + 0.5 * math.cos(world - _kLightAngle);
      toothPaint.color = shades[(lum * 12).floor().clamp(0, 11)];
      canvas.drawPath(path, toothPaint);
      canvas.restore();
    }
    canvas.restore();

    // ── 3. 轴心铆钉 ──
    canvas.drawCircle(center, 2.4, Paint()..color = ringColor);
  }

  @override
  bool shouldRepaint(_GearPainter old) =>
      old.angle != angle ||
      old.teeth != teeth ||
      old.diameter != diameter ||
      old.ringColor != ringColor ||
      old.fillColor != fillColor;
}
