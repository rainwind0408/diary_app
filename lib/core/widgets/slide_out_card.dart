import 'package:flutter/material.dart';

class SlideOutCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismissed;
  final bool triggerDismiss;
  final Duration duration;
  final Offset slideOffset;

  const SlideOutCard({
    super.key,
    required this.child,
    required this.onDismissed,
    this.triggerDismiss = false,
    this.duration = const Duration(milliseconds: 350),
    this.slideOffset = const Offset(1.0, 0.0),
  });

  @override
  State<SlideOutCard> createState() => _SlideOutCardState();
}

class _SlideOutCardState extends State<SlideOutCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: widget.slideOffset,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInBack,
    ));
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_dismissed) {
        _dismissed = true;
        widget.onDismissed();
      }
    });
  }

  @override
  void didUpdateWidget(SlideOutCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerDismiss && !oldWidget.triggerDismiss && !_dismissed) {
      _controller.forward();
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
