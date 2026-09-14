import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/achievement.dart';

/// 成就解锁仪式
///
/// 解锁这一刻是成就系统唯一真正的高光时刻，值得给足反馈：
/// - **光晕**：图标背后一圈扩散的光环，把注意力钉在图标上
/// - **粒子飞散**：14 颗小光点从中心向外飞，方向与时长由固定 seed 决定
///   （确定性生成 → 每次动画一致，不会看起来像随机噪声）
/// - **触感**：中强度震动，让「解锁」这件事在物理上也成立
///
/// 动画全部由一个 1.6s 的 controller 驱动：0~0.55 是入场弹性缩放，
/// 0.25~1.0 是粒子与光晕的扩散段。
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

  /// 粒子方向与距离，确定性生成（seed 固定 → 每次一致）
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    final rnd = math.Random(20260914);
    _particles = List.generate(14, (i) {
      final angle = (i / 14) * 2 * math.pi + rnd.nextDouble() * 0.35;
      final distance = 58.0 + rnd.nextDouble() * 44.0;
      return _Particle(
        angle: angle,
        distance: distance,
        size: 3.0 + rnd.nextDouble() * 3.5,
        delay: rnd.nextDouble() * 0.22,
      );
    });

    _controller.forward();
    // 解锁值得一次明确的触感反馈
    HapticFeedback.mediumImpact();
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
                // 图标 + 光晕 + 粒子
                SizedBox(
                  width: 150,
                  height: 130,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final t = _controller.value;
                      // 扩散段：0.25 → 1.0
                      final burst =
                          ((t - 0.25) / 0.75).clamp(0.0, 1.0);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // 光晕：一圈随 burst 扩散淡出的圆
                          if (burst > 0)
                            Opacity(
                              opacity: (1 - burst) * 0.45,
                              child: Container(
                                width: 70 + burst * 80,
                                height: 70 + burst * 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: goldColor.withValues(alpha: 0.18),
                                ),
                              ),
                            ),
                          // 粒子
                          for (final p in _particles)
                            _buildParticle(p, burst, goldColor),
                          // 图标本体
                          child!,
                        ],
                      );
                    },
                    child: Text(
                      widget.achievement.icon,
                      style: const TextStyle(fontSize: 56),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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

  Widget _buildParticle(_Particle p, double burst, Color goldColor) {
    // 每颗粒子有自己的起步延迟，形成先后飞散的感觉
    final local = ((burst - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
    if (local <= 0) return const SizedBox.shrink();

    final dx = math.cos(p.angle) * p.distance * Curves.easeOut.transform(local);
    final dy = math.sin(p.angle) * p.distance * Curves.easeOut.transform(local);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: (1 - local) * 0.9,
        child: Container(
          width: p.size,
          height: p.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: goldColor,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final double delay;

  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
  });
}
