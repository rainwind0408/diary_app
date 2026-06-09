import 'package:flutter/material.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final int index;
  final bool enabled;

  const AnimatedCard({
    super.key,
    required this.child,
    this.index = 0,
    this.enabled = true,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    if (widget.enabled) {
      final delay = Duration(milliseconds: widget.index * 60);
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index || widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.reset();
        final delay = Duration(milliseconds: widget.index * 60);
        Future.delayed(delay, () {
          if (mounted) _controller.forward();
        });
      } else {
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}
