import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/watercolor_background.dart';
import '../../../core/widgets/watercolor_decoration.dart';

/// 欢迎页（参考图3）
/// 首次启动时显示，引导用户进入应用
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const WelcomeScreen({super.key, required this.onComplete});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
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

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WatercolorBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // 装饰层（花朵、星星）
              if (!isDark) const WatercolorDecorations(opacity: 0.4),

              // 内容
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // 插画区域（留出图片占位）
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildIllustration(accentColor),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 标题
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Text(
                              '手写日记',
                              style: AppTextStyles.handwritingTitle.copyWith(
                                color: textColor,
                                fontSize: 36,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '记录生活中的美好瞬间',
                              style: TextStyle(
                                fontSize: 15,
                                color: subtleColor,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // 开始按钮
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: GestureDetector(
                        onTap: _complete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentColor,
                                accentColor.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            '开始写日记',
                            style: TextStyle(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 跳过按钮
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: TextButton(
                        onPressed: _complete,
                        child: Text(
                          '跳过',
                          style: TextStyle(
                            fontSize: 14,
                            color: subtleColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 插画区域（使用实际图片资源）
  Widget _buildIllustration(Color accentColor) {
    return Image.asset(
      'assets/decorations/welcome_illustration.png',
      width: 280,
      height: 280,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.menu_book_rounded,
          size: 72,
          color: accentColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
