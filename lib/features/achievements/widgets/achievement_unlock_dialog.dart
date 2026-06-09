import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/achievement.dart';

class AchievementUnlockDialog extends StatefulWidget {
  final Achievement achievement;

  const AchievementUnlockDialog({super.key, required this.achievement});

  static Future<void> show(BuildContext context, Achievement achievement) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => AchievementUnlockDialog(achievement: achievement),
    );
  }

  @override
  State<AchievementUnlockDialog> createState() =>
      _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState extends State<AchievementUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🎉 恭喜解锁！',
                  style: AppTextStyles.heading.copyWith(
                    color: goldColor,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.achievement.icon,
                  style: const TextStyle(fontSize: 56),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.achievement.name,
                  style: AppTextStyles.heading.copyWith(
                    color: textColor,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.achievement.description,
                  style: AppTextStyles.body.copyWith(
                    color: isDark
                        ? AppColors.darkSubtleText
                        : AppColors.subtleText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('继续写作'),
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
