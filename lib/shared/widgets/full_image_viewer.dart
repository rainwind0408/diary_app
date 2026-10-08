import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 通用全屏图片查看器（**多图**版）
///
/// 黑底沉浸式展示 + 双指缩放 + 双击放大 + 左右滑动切换 + 点击右上角关闭。
/// 日记详情页与首页封面图卡片共用，避免各写一份。
///
/// ## 三个必须记住的行为约定
///
/// 1. **小图也要占满屏幕**。
///    老版本用 `Center(child: InteractiveViewer(child: Image))`，`Center` 给的是
///    **松约束**，`Image` 于是在松约束下取「固有尺寸 ÷ devicePixelRatio」，
///    而 `constrainSizeAndAttemptToPreserveAspectRatio` **只缩小、不放大** ——
///    结果大照片正常、小图（截图 / AI 生的小图）缩在屏幕中间一小块。
///    现在改成 `SizedBox.expand` 给**紧约束**，大小图都按 `BoxFit.contain` 撑满。
///
/// 2. **缩放必须自己抢手势，不能交给 `InteractiveViewer`**（见下）。
///
/// 3. **放大后左右拖动是平移，不是翻页**。
///    只要当前页被放大（scale > 1.01），就把 `PageView` 的 physics 换成
///    [NeverScrollableScrollPhysics]，缩回 1.0 再恢复。
///
/// ## ★ 为什么不用 `InteractiveViewer`
///
/// 它内部那个 `ScaleGestureRecognizer` 和 `PageView` 的水平拖动识别器是
/// **纯竞速**关系，而且是它输：
///
/// | 识别器 | 接受条件 |
/// |---|---|
/// | `PageView` 的水平拖动 | 单指**横向**位移 > `kTouchSlop`（18px） |
/// | `ScaleGestureRecognizer` | 双指**跨度**变化 > `kScaleSlop`（18px）<br>或焦点位移 > `kPanSlop`（36px） |
///
/// 手指一动，18px 那个先到 —— 翻页赢了，缩放被饿死。这不是调参能解决的：
/// `scale.dart` 的 `_advanceStateMachine` 里**没有**「双指按下就立刻接受」这条捷径
/// （本机 Flutter 3.44 实测确认）。这是 Flutter 的已知问题
/// [flutter/flutter#68594](https://github.com/flutter/flutter/issues/68594)，
/// 维护者原话 "There is a race between the zoom in/out and the page scrolling"，至今未修。
///
/// 解法：自己写一个 `ScaleGestureRecognizer` 子类，**第二根手指一按下就
/// `resolve(accepted)`** 把竞技场当场锁死（父级识别器直接被判负）；
/// 而单指、且未放大时**根本不接受**，把翻页完整让给 `PageView`。
/// 于是两条路互不干扰，不再有竞速。
///
/// 代价：变换矩阵要自己算（缩放以焦点为不动点 + 平移夹在边界内），
/// 不能白拿 `InteractiveViewer` 的那套。但换来的是**确定性** —— 值。
class FullImageViewer extends StatefulWidget {
  /// 要展示的图片，至少一张（空列表不要调用 [show]）
  final List<File> files;

  /// 初始展示第几张
  final int initialIndex;

  /// 与 [files] 等长的 Hero tag 列表，可为 null。
  ///
  /// ★ 只有**当前页**会挂 Hero：`PageView` 里多页共享同一个 tag 会直接抛
  /// `There are multiple heroes that share the same tag`。
  final List<String?> heroTags;

  const FullImageViewer({
    super.key,
    required this.files,
    this.initialIndex = 0,
    this.heroTags = const [],
  });

  /// 以全屏弹窗形式打开图片列表。
  ///
  /// [files] 为空时**不弹**（直接返回），避免出现一个纯黑的空页面。
  static Future<void> show(
    BuildContext context,
    List<File> files, {
    int initialIndex = 0,
    List<String?>? heroTags,
  }) {
    if (files.isEmpty) return Future<void>.value();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => FullImageViewer(
        files: files,
        initialIndex: initialIndex,
        heroTags: heroTags ?? const [],
      ),
    );
  }

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  late final PageController _pageController;
  late int _current;

  /// 当前页是否被放大 —— 放大时禁用翻页，把水平拖动让给图片平移
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.files.length - 1);
    _pageController = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 只有当前页返回 tag，其余页一律 null（见 [FullImageViewer.heroTags] 注释）
  String? _tagAt(int index) {
    if (index != _current) return null;
    if (index >= widget.heroTags.length) return null;
    return widget.heroTags[index];
  }

  void _onZoomChanged(bool zoomed) {
    if (zoomed == _zoomed || !mounted) return;
    setState(() => _zoomed = zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.files.length;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            // 放大时锁住翻页，缩回 1.0 自动恢复
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: total,
            onPageChanged: (index) => setState(() {
              _current = index;
              // 换页后新页是未放大的，复位这个标记 ——
              // 否则从放大页划到下一页会继续被锁住，滑不动。
              _zoomed = false;
            }),
            itemBuilder: (_, index) => _ZoomablePage(
              key: ValueKey(widget.files[index].path),
              file: widget.files[index],
              heroTag: _tagAt(index),
              onZoomChanged: _onZoomChanged,
            ),
          ),
          if (total > 1) _buildPageIndicator(context, total),
          _buildCloseButton(context),
        ],
      ),
    );
  }

  /// 右上角关闭按钮（放在状态栏下方，保证可点）
  Widget _buildCloseButton(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 16,
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white, size: 28),
        tooltip: '关闭',
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  /// 底部居中的页码角标，如 `3 / 12`
  Widget _buildPageIndicator(BuildContext context, int total) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).padding.bottom + 24,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 0.5,
            ),
          ),
          child: Text(
            '${_current + 1} / $total',
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// 单页：自带变换矩阵，并把「是否已放大」上报给外层。
///
/// ★ 为什么每页各持一个 [TransformationController]，而不是外层共用一个：
/// 共用一个的话，第 2 页会**继承第 1 页的缩放与位移**，翻过去就是一张
/// 已经被放大且偏到角落的图。`PageView.builder` 会销毁离屏页，
/// 所以放在这里天然做到「每页独立、离开即复位」。
class _ZoomablePage extends StatefulWidget {
  final File file;
  final String? heroTag;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomablePage({
    super.key,
    required this.file,
    required this.heroTag,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage>
    with SingleTickerProviderStateMixin {
  static const double _kMinScale = 1.0;
  static const double _kMaxScale = 5.0;

  /// 双击放到的倍数（再双击回到 1.0）
  static const double _kDoubleTapScale = 2.5;

  final TransformationController _transform = TransformationController();
  bool _zoomed = false;

  /// 当前页尺寸，用于把平移夹在边界内
  Size _viewport = Size.zero;

  // ── 手势起点快照 ──
  Matrix4 _baseMatrix = Matrix4.identity();
  Offset _startFocal = Offset.zero;
  double _startScale = 1.0;

  // ── 双击动画 ──
  late final AnimationController _anim;
  Animation<Matrix4>? _tween;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_handleTransform);
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        final t = _tween;
        if (t != null) _transform.value = t.value;
      });
  }

  @override
  void dispose() {
    _transform.removeListener(_handleTransform);
    _transform.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _handleTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  // ---- 变换矩阵 ----

  /// 把矩阵夹到合法范围：缩放 ∈ [1, 5]，且图片始终盖满视口。
  ///
  /// 矩阵只有平移 + 等比缩放（没有旋转），所以 `storage[12]/[13]` 就是
  /// 平移量，直接夹即可：
  ///   tx ∈ [w·(1−s), 0]、ty ∈ [h·(1−s), 0]
  /// —— 左边取 `w·(1−s)` 是「图片右边缘贴住视口右边缘」，右边取 0 是
  /// 「图片左边缘贴住视口左边缘」，中间任意位置都盖得住。
  Matrix4 _clamp(Matrix4 m, double scale) {
    final vp = _viewport;
    final tx = m.storage[12].clamp(vp.width * (1 - scale), 0.0);
    final ty = m.storage[13].clamp(vp.height * (1 - scale), 0.0);
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  /// 以 [focal] 为不动点、从单位矩阵缩放到 [scale]
  Matrix4 _matrixZoomAt(double scale, Offset focal) {
    final m = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
    return _clamp(m, scale);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _anim.stop();
    _baseMatrix = _transform.value.clone();
    _startFocal = d.localFocalPoint;
    _startScale = _baseMatrix.getMaxScaleOnAxis();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final target = (_startScale * d.scale).clamp(_kMinScale, _kMaxScale);
    final k = target / _startScale;
    final f = d.localFocalPoint;

    // 以「起始焦点」为不动点缩放，再让焦点跟着手指走（这就是平移的来源）
    final m = Matrix4.identity()
      ..translateByDouble(f.dx, f.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-_startFocal.dx, -_startFocal.dy, 0, 1);

    _transform.value = _clamp(m.multiplied(_baseMatrix), target);
  }

  /// 双击：未放大 → 放大到 [_kDoubleTapScale] 并以双击点为不动点；
  /// 已放大 → 回到 1.0。
  void _handleDoubleTap(Offset focal) {
    final current = _transform.value.getMaxScaleOnAxis();
    final target = current > 1.01 ? _kMinScale : _kDoubleTapScale;
    final to = target == _kMinScale
        ? Matrix4.identity()
        : _matrixZoomAt(target, focal);

    _tween = Matrix4Tween(begin: _transform.value.clone(), end: to).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.file(
      widget.file,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const _BrokenImage(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;

        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            _ZoomPanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<_ZoomPanGestureRecognizer>(
              () => _ZoomPanGestureRecognizer(),
              (r) {
                // ★ 这些闭包每帧重设：识别器实例是被复用的，
                //   闭包里带的是当前 State 的实时状态，不能只在构造时绑一次。
                r.isZoomed = () => _zoomed;
                r.onDoubleTap = _handleDoubleTap;
                r.onStart = _onScaleStart;
                r.onUpdate = _onScaleUpdate;
              },
            ),
          },
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _transform,
              builder: (context, child) => Transform(
                transform: _transform.value,
                child: child,
              ),
              child: SizedBox.expand(
                // ★ 紧约束：小图会被放大到「按 contain 撑满屏幕」，不再是中间一小块
                child: widget.heroTag == null
                    ? image
                    : Hero(tag: widget.heroTag!, child: image),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 缩放 / 平移 / 双击识别器 —— **只在「双指」或「已放大」时抢手势**。
///
/// ## 为什么不直接用 `InteractiveViewer` 的那套
/// 见 [FullImageViewer] 顶部的表格：它和 `PageView` 的水平拖动是纯竞速，必输。
///
/// ## 抢法
/// - **双指按下**（`_active.length >= 2`）→ 立刻 `resolve(accepted)`：
///   此刻竞技场还是 open 的，这次 accept 记成 eagerWinner，等 pointer-down
///   派发结束、arena 关闭时立刻生效；父级（`PageView`）的识别器必然排在其后、直接判负。
/// - **已放大 + 单指** → 同样立刻接受，让单指拖动变成平移而不是翻页。
/// - **未放大 + 单指** → **完全不接受**，把这一串事件完整让给 `PageView` 翻页。
///
/// ## 双击
/// 不走 `DoubleTapGestureRecognizer`：那个会把竞技场**按住 300ms** 不放，
/// 翻页要等它超时才生效，滑动会明显发粘。这里自己记「上一次抬起的时间与位置」，
/// 够快够近就当成双击 —— 而且**不接受手势**，因为双击本来就没有位移，
/// 不接受也不会被 `PageView` 抢走什么。
class _ZoomPanGestureRecognizer extends ScaleGestureRecognizer {
  /// 当前是否已放大（放大后单指应该是平移）
  bool Function()? isZoomed;

  /// 双击回调（参数是双击点的局部坐标）
  void Function(Offset localPosition)? onDoubleTap;

  static const Duration _kDoubleTapWindow = Duration(milliseconds: 300);
  static const double _kDoubleTapSlop = 40;

  final Set<int> _active = <int>{};
  Duration? _lastTapUpTime;
  Offset? _lastTapUpPos;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _active.add(event.pointer);

    final lastTime = _lastTapUpTime;
    final lastPos = _lastTapUpPos;
    if (lastTime != null &&
        lastPos != null &&
        event.timeStamp - lastTime < _kDoubleTapWindow &&
        (event.localPosition - lastPos).distance < _kDoubleTapSlop) {
      _lastTapUpTime = null;
      _lastTapUpPos = null;
      onDoubleTap?.call(event.localPosition);
      return;
    }

    if (_active.length >= 2 || (isZoomed?.call() ?? false)) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerUpEvent) {
      _active.remove(event.pointer);
      _lastTapUpTime = event.timeStamp;
      _lastTapUpPos = event.localPosition;
    } else if (event is PointerCancelEvent) {
      _active.remove(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _active.remove(pointer);
    super.rejectGesture(pointer);
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
          SizedBox(height: 12),
          Text('图片已无法读取', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}
