import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SwipeActionCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final VoidCallback? onLock;
  final VoidCallback? onUnlock;
  final bool isLocked;
  final bool triggerDismiss;
  final VoidCallback? onDismissed;

  const SwipeActionCard({
    super.key,
    required this.child,
    required this.onDelete,
    this.onLock,
    this.onUnlock,
    this.isLocked = false,
    this.triggerDismiss = false,
    this.onDismissed,
  });

  @override
  State<SwipeActionCard> createState() => _SwipeActionCardState();
}

class _SwipeActionCardState extends State<SwipeActionCard>
    with SingleTickerProviderStateMixin {
  double _dragExtent = 0;
  bool _isExpanded = false;
  static const double _actionWidth = 140; // 两个按钮各 70
  static const double _threshold = 60;

  late AnimationController _dismissController;
  late Animation<Offset> _dismissSlide;
  late Animation<double> _dismissFade;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _dismissController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _dismissSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _dismissController,
      curve: Curves.easeInBack,
    ));
    _dismissFade = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _dismissController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _dismissController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_dismissed) {
        _dismissed = true;
        widget.onDismissed?.call();
      }
    });
  }

  @override
  void didUpdateWidget(SwipeActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerDismiss && !oldWidget.triggerDismiss && !_dismissed) {
      _dismissController.forward();
    }
  }

  @override
  void dispose() {
    _dismissController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // 只允许左滑（负值）
    _dragExtent += details.primaryDelta!;
    _dragExtent = _dragExtent.clamp(-_actionWidth, 0);
    setState(() {});
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragExtent.abs() > _threshold) {
      // 展开
      setState(() {
        _dragExtent = -_actionWidth;
        _isExpanded = true;
      });
    } else {
      // 收起
      setState(() {
        _dragExtent = 0;
        _isExpanded = false;
      });
    }
  }

  void _collapse() {
    setState(() {
      _dragExtent = 0;
      _isExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    return SlideTransition(
      position: _dismissSlide,
      child: FadeTransition(
        opacity: _dismissFade,
        child: GestureDetector(
          onTap: _isExpanded ? _collapse : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // 底层：操作按钮
                Positioned.fill(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 加密/解锁按钮
                      SizedBox(
                        width: 70,
                        child: Material(
                          color: goldColor.withValues(alpha: 0.15),
                          child: InkWell(
                            onTap: () {
                              _collapse();
                              if (widget.isLocked) {
                                widget.onUnlock?.call();
                              } else {
                                widget.onLock?.call();
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.isLocked
                                      ? Icons.lock_open
                                      : Icons.lock_outline,
                                  color: goldColor,
                                  size: 20,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.isLocked ? '解锁' : '加密',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: goldColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 删除按钮
                      SizedBox(
                        width: 70,
                        child: Material(
                          color: AppColors.deleteRed.withValues(alpha: 0.15),
                          child: InkWell(
                            onTap: () {
                              _collapse();
                              widget.onDelete();
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: AppColors.deleteRed,
                                  size: 20,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '删除',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.deleteRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 上层：卡片内容
                Transform.translate(
                  offset: Offset(_dragExtent, 0),
                  child: GestureDetector(
                    onHorizontalDragUpdate: _onDragUpdate,
                    onHorizontalDragEnd: _onDragEnd,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
