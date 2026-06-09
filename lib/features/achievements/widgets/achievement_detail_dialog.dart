import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/achievement.dart';

class AchievementDetailDialog extends StatefulWidget {
  final Achievement achievement;

  const AchievementDetailDialog({super.key, required this.achievement});

  static Future<void> show(BuildContext context, Achievement achievement) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => AchievementDetailDialog(achievement: achievement),
    );
  }

  @override
  State<AchievementDetailDialog> createState() =>
      _AchievementDetailDialogState();
}

class _AchievementDetailDialogState extends State<AchievementDetailDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
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
    final bgColor =
        isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor =
        isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final unlocked = widget.achievement.isUnlocked;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: unlocked
                    ? goldColor.withValues(alpha: 0.3)
                    : subtleColor.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 图标
                Text(
                  widget.achievement.icon,
                  style: TextStyle(
                    fontSize: 56,
                    color:
                        unlocked ? null : Colors.grey.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 16),
                // 名称
                Text(
                  widget.achievement.name,
                  style: AppTextStyles.heading.copyWith(
                    color: unlocked
                        ? textColor
                        : subtleColor.withValues(alpha: 0.6),
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // 描述
                Text(
                  widget.achievement.description,
                  style: AppTextStyles.body.copyWith(
                    color: unlocked
                        ? subtleColor
                        : subtleColor.withValues(alpha: 0.4),
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // 解锁状态
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? goldColor.withValues(alpha: 0.1)
                        : subtleColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unlocked
                        ? '已解锁 · ${_formatDate(widget.achievement.unlockedAt!)}'
                        : '未解锁',
                    style: TextStyle(
                      fontSize: 12,
                      color: unlocked
                          ? goldColor
                          : subtleColor.withValues(alpha: 0.5),
                      fontWeight:
                          unlocked ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 关闭按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          unlocked ? goldColor : subtleColor.withValues(alpha: 0.3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('关闭'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
