import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/achievement.dart';
import '../services/garden_arranger.dart';

/// 成就时间轴
///
/// 把「什么时候拿到什么」按时间正序铺成一条竖线。
/// 与花园视图互补：花园看的是「总量有多满」，时间轴看的是「这一路怎么走来的」。
///
/// 数据来源是 `Achievement.unlockedAt`，早已存在于 model 与数据库，零 schema 变更。
class AchievementTimeline extends StatelessWidget {
  final List<Achievement> achievements;
  final int streakDays;

  const AchievementTimeline({
    super.key,
    required this.achievements,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    final timeline = GardenArranger.timelineOrder(achievements);

    if (timeline.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌱', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 14),
              Text(
                '时间轴还是空的',
                style: AppTextStyles.cardTitle.copyWith(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '写下第一篇日记，这里就会长出第一个节点',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: subtleColor, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    final groups = GardenArranger.groupByMonth(timeline);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 20, 28),
      itemCount: groups.length,
      itemBuilder: (context, gi) {
        final group = groups[gi];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 月份分段标题
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 12),
              child: Text(
                '${group.year} 年 ${group.month} 月',
                style: AppTextStyles.label.copyWith(
                  color: goldColor,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            for (var i = 0; i < group.items.length; i++)
              _buildNode(
                context,
                group.items[i],
                isLast: gi == groups.length - 1 &&
                    i == group.items.length - 1,
                goldColor: goldColor,
                textColor: textColor,
                subtleColor: subtleColor,
                isDark: isDark,
              ),
          ],
        );
      },
    );
  }

  Widget _buildNode(
    BuildContext context,
    Achievement a, {
    required bool isLast,
    required Color goldColor,
    required Color textColor,
    required Color subtleColor,
    required bool isDark,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 竖线上的节点
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: goldColor.withValues(alpha: isDark ? 0.16 : 0.12),
                  border: Border.all(
                    color: goldColor.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                child: Text(a.icon, style: const TextStyle(fontSize: 14)),
              ),
              // 连接线（最后一个不画）
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: goldColor.withValues(alpha: 0.22),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // 内容
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 6 : 22, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.name,
                          style: AppTextStyles.cardTitle.copyWith(
                            color: textColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _formatDate(a.unlockedAt!),
                        style: TextStyle(fontSize: 11, color: subtleColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    a.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtleColor.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
