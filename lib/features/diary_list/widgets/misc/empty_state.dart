import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class EmptyState extends StatefulWidget {
  final String? message;

  const EmptyState({super.key, this.message});

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final textColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final cardBg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    return Center(
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 水彩风格圆形装饰（参考图3插画风格）
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.15),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 装饰性花朵
                        Positioned(
                          top: 10,
                          right: 14,
                          child: Icon(
                            Icons.local_florist,
                            size: 16,
                            color: AppColors.pink.withValues(alpha: 0.5),
                          ),
                        ),
                        Positioned(
                          bottom: 14,
                          left: 12,
                          child: Icon(
                            Icons.favorite,
                            size: 12,
                            color: AppColors.blue.withValues(alpha: 0.4),
                          ),
                        ),
                        Positioned(
                          top: 20,
                          left: 16,
                          child: Icon(
                            Icons.star,
                            size: 10,
                            color: AppColors.goldAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        // 主图标
                        Icon(
                          Icons.edit_note_rounded,
                          size: 48,
                          color: accentColor.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    widget.message ?? '这天没有写日记',
                    style: AppTextStyles.handwritingTitle.copyWith(
                      color: textColor,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      '记录生活中的美好瞬间',
                      style: AppTextStyles.label.copyWith(
                        color: subtleColor,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '每一天都值得被记住',
                    style: AppTextStyles.cardDate.copyWith(
                      color: subtleColor.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
