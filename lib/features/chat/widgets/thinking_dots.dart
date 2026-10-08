import 'package:flutter/material.dart';

/// 「正在思考」的三点跳动指示器。
///
/// 三个点用同一个 [AnimationController] 驱动，各自错开 1/3 个周期，
/// 形成依次起伏的波浪 —— 比单个转圈更能表达「AI 在组织语言」。
///
/// 只在等待回复时挂载，所以常驻动画不会白烧帧。
class ThinkingDots extends StatefulWidget {
  final Color color;
  final double dotSize;

  const ThinkingDots({
    super.key,
    required this.color,
    this.dotSize = 6,
  });

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, _buildDot),
        );
      },
    );
  }

  Widget _buildDot(int index) {
    // 每个点错开 1/3 周期；三角波让「亮→暗」的往返线性、不突兀
    final t = (_controller.value + index / 3) % 1.0;
    final wave = t < 0.5 ? t * 2 : (1 - t) * 2;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.3),
      child: Opacity(
        opacity: 0.28 + wave * 0.72,
        child: Container(
          width: widget.dotSize,
          height: widget.dotSize,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
