/// 悬浮球的几何计算 —— **纯 Dart**，不依赖 Flutter，便于离线测试。
///
/// 为什么单独抽出来：拖动钳制与左右吸附是这条链路里最容易算错、
/// 又最难靠肉眼发现问题的地方（差 8px 在手机上根本看不出来，
/// 但会让球压住底部导航栏或者飘出屏幕）。放在纯 Dart 里可以逐条断言。
library;

/// 一个不依赖 `dart:ui` 的二维点。
///
/// 不用 `Offset` 的原因：它来自 `dart:ui`，一旦引入这个文件就没法在纯 Dart VM
/// 里跑测试 —— 而几何逻辑恰恰是最该被测试的部分。
class OrbPoint {
  final double x;
  final double y;

  const OrbPoint(this.x, this.y);

  OrbPoint copyWith({double? x, double? y}) =>
      OrbPoint(x ?? this.x, y ?? this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrbPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'OrbPoint(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

class OrbGeometry {
  OrbGeometry._();

  /// 球的直径。
  ///
  /// 比 Material FAB（56）小一档 —— 它不该抢主操作（底部中间那个「写日记」）。
  static const double orbSize = 52;

  /// 球与屏幕左右边缘的最小间距
  static const double edgeGap = 8;

  /// 球与顶部（状态栏下方）的最小间距
  static const double topGap = 8;

  /// 底部额外预留：底部导航栏 + 系统手势区
  static const double bottomReserveBase = 76;

  /// 吸附动画时长（与 `AnimatedPositioned` 的 duration 保持一致）
  static const Duration snapDuration = Duration(milliseconds: 200);

  /// 把坐标钳制进可用区域。
  ///
  /// [width] / [height] 是**逻辑像素**的屏幕尺寸；
  /// [topInset] 用 `MediaQuery.viewPadding.top`（不要用 `padding` ——
  /// 键盘弹起时 `viewInsets` 会变，但球的坐标不该跟着跳）；
  /// [bottomInset] 用 `MediaQuery.viewPadding.bottom`。
  static OrbPoint clamp(
    OrbPoint p, {
    required double width,
    required double height,
    double topInset = 0,
    double bottomInset = 0,
  }) {
    final minX = edgeGap;
    final maxX = width - orbSize - edgeGap;
    final minY = topInset + topGap;
    final maxY = height - bottomInset - bottomReserveBase - orbSize;

    return OrbPoint(
      // 屏幕比球还窄（极端情况 / 分屏）时 maxX < minX，取 minX 兜底，
      // 不能让它变成负数坐标飘出屏幕
      _clampDouble(p.x, minX, maxX < minX ? minX : maxX),
      _clampDouble(p.y, minY, maxY < minY ? minY : maxY),
    );
  }

  /// 松手后吸附到最近的左 / 右边缘。
  ///
  /// **只吸左右，竖向自由** —— 这是 QQ / 微信的惯例，用户不用为
  /// 「停在哪一行」纠结。
  static OrbPoint snapToEdge(OrbPoint p, {required double width}) {
    final maxX = width - orbSize - edgeGap;
    final center = p.x + orbSize / 2;
    return OrbPoint(center < width / 2 ? edgeGap : (maxX < edgeGap ? edgeGap : maxX), p.y);
  }

  /// 默认落点：右下角，避开底部导航栏。
  static OrbPoint defaultPosition({
    required double width,
    required double height,
    double bottomInset = 0,
  }) =>
      clamp(
        OrbPoint(width - orbSize - edgeGap, height - bottomInset - bottomReserveBase - orbSize),
        width: width,
        height: height,
        bottomInset: bottomInset,
      );

  /// 序列化成 `"x,y"`（存 SharedPreferences）。
  ///
  /// 用 `toStringAsFixed(1)` 而不是原始 double —— 后者会写出
  /// `123.45000000000002` 这种垃圾串，且不同平台小数表示不一致。
  static String serialize(OrbPoint p) =>
      '${p.x.toStringAsFixed(1)},${p.y.toStringAsFixed(1)}';

  /// 反序列化；任何异常都返回 null，由调用方回退到默认位置。
  ///
  /// 这里**不做钳制** —— 存进去时的屏幕尺寸和读出来时可能不同（旋转、分屏），
  /// 钳制交给调用方在拿到当前尺寸后再做一次。
  static OrbPoint? parse(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final x = double.tryParse(parts[0].trim());
    final y = double.tryParse(parts[1].trim());
    if (x == null || y == null) return null;
    if (x.isNaN || y.isNaN || x.isInfinite || y.isInfinite) return null;
    return OrbPoint(x, y);
  }

  static double _clampDouble(double v, double min, double max) {
    if (v.isNaN) return min;
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }
}
