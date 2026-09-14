import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/achievement.dart';

/// 「下一个成就」前置卡
///
/// 取代原先那条「连续天数 + 一条全局进度条」。
/// 原来的做法有个根本问题：**进度条不知道该指向哪**——它只反映连续天数，
/// 却长得像在追踪所有成就，用户看完不知道「我离下一个还差什么」。
///
/// 改成聚焦单个目标后：
/// - 只说一件事：下一个能拿的成就是什么
/// - 能数值化的给「当前 / 目标 · 还差多少」，不能的退回描述文案
/// - 连续天数降级成一个次要徽章，不再是主角
class StreakProgress extends StatelessWidget {
  final int streakDays;

  /// 下一个可争取的成就；全部解锁时为 null
  final Achievement? goal;

  /// 用户在该成就维度上的当前值；无法数值化时为 null
  final int? currentValue;

  /// 该成就的门槛值；无法数值化时为 null
  final int? targetValue;

  const StreakProgress({
    super.key,
    required this.streakDays,
    this.goal,
    this.currentValue,
    this.targetValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor =
        isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    final g = goal;

    // 进度：两边都能数值化时才算得出来
    final hasGauge = g != null &&
        currentValue != null &&
        targetValue != null &&
        targetValue! > 0;
    final progress =
        hasGauge ? (currentValue! / targetValue!).clamp(0.0, 1.0) : null;
    final remaining =
        hasGauge ? (targetValue! - currentValue!).clamp(0, targetValue!) : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
      ),
      child: g == null
          ? _buildAllDone(goldColor, textColor, subtleColor)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '下一个成就',
                      style: AppTextStyles.label.copyWith(
                        color: subtleColor,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    // 连续天数降级成小徽章
                    if (streakDays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: goldColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '连续 $streakDays 天',
                          style: TextStyle(
                            fontSize: 11,
                            color: goldColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 目标图标：未解锁 → 去色剪影
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 0.42, 0,
                      ]),
                      child: Text(g.icon, style: const TextStyle(fontSize: 34)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.name,
                            style: AppTextStyles.cardTitle.copyWith(
                              color: textColor,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _subtitle(
                              g,
                              progress: progress,
                              remaining: remaining,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: subtleColor,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (progress != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        backgroundColor: subtleColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(goldColor),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${currentValue!} / ${targetValue!}　·　${(progress * 100).round()}%',
                    style: TextStyle(fontSize: 11, color: goldColor),
                  ),
                ] else
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 13,
                        color: subtleColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '这一株靠自己长出来，条件藏在日复一日里',
                          style: TextStyle(
                            fontSize: 11,
                            color: subtleColor.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }

  String _subtitle(
    Achievement g, {
    required double? progress,
    required int? remaining,
  }) {
    if (remaining != null && remaining <= 0) return '已达成，正在为你点亮';
    if (progress != null) return '${g.description}　·　还差 $remaining';
    return g.description;
  }

  Widget _buildAllDone(Color goldColor, Color textColor, Color subtleColor) {
    return Column(
      children: [
        const Text('🌳', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 10),
        Text(
          '花园已经开满了',
          style: AppTextStyles.cardTitle.copyWith(
            color: textColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '所有成就都已解锁，接下来只要继续写',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: subtleColor, height: 1.5),
        ),
      ],
    );
  }
}
