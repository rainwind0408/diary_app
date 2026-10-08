import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../achievements/data/achievement_defs.dart';
import '../../achievements/models/achievement.dart';
import '../../achievements/services/garden_arranger.dart';

/// 「连续写作 + 本周」合并卡
///
/// 原先这是**两张卡**：一张「连续 N 天 + 一条进度条」，一张「本周写作 7 个圆点」。
/// 两张讲的其实是同一件事 —— 最近有没有坚持写。拆成两张等于让用户在脑子里
/// 自己把两件事关联起来，还白占一屏高度。合并后叙事变成一句话：
/// **「你连续写了 N 天，最近这一周是这样。」**
///
/// 里程碑数据统一来自 [AchievementDefs] 的 `streak` 分类。
/// 这里以前另有一份写死的 `_milestones` 常量表（7 档、含 365 天），
/// 与成就页的定义（5 档、最大 100 天）各说各话 —— 同一件事两个数据源，
/// 迟早对不上。现在成就页与回顾页读的是同一个列表。
class StreakCard extends StatelessWidget {
  /// 当前连续写作天数
  final int streakDays;

  /// 本周 7 天是否写过（**从周日开始**，与表头 日一二三四五六 对齐）
  final List<bool> weekDays;

  const StreakCard({
    super.key,
    required this.streakDays,
    required this.weekDays,
  });

  /// 连续里程碑：成就定义里「连续」一档，按门槛升序
  ///
  /// 门槛值统一走 [GardenArranger.targetValue]，不在这里另写一份数字。
  static final List<Achievement> _milestones = () {
    final list =
        AchievementDefs.getByCategory(AchievementCategory.streak).toList();
    list.sort((a, b) => (GardenArranger.targetValue(a) ?? 0)
        .compareTo(GardenArranger.targetValue(b) ?? 0));
    return list;
  }();

  /// 已达成的最高里程碑；连第一档都没到时为 null
  Achievement? get _reached {
    Achievement? result;
    for (final m in _milestones) {
      if (streakDays >= (GardenArranger.targetValue(m) ?? 0)) {
        result = m;
      } else {
        break;
      }
    }
    return result;
  }

  /// 下一个待达成的里程碑；全部达成时为 null
  Achievement? get _next {
    for (final m in _milestones) {
      if (streakDays < (GardenArranger.targetValue(m) ?? 0)) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    final reached = _reached;
    final next = _next;
    final nextTarget = next == null ? null : GardenArranger.targetValue(next);
    final reachedDays =
        reached == null ? 0 : (GardenArranger.targetValue(reached) ?? 0);

    // 进度按「上一档 → 下一档」的区间算，而不是拿绝对天数除总目标：
    // 后者在刚跨过一档时会几乎不动，看着像卡住了。
    double? progress;
    String progressLabel;
    if (next == null || nextTarget == null) {
      progress = null;
      progressLabel = '连续里程碑已全部达成';
    } else {
      final span = nextTarget - reachedDays;
      progress = span <= 0
          ? 1.0
          : ((streakDays - reachedDays) / span).clamp(0.0, 1.0);
      progressLabel = '距「${next.name}」还差 ${nextTarget - streakDays} 天';
    }

    final weekCount = weekDays.where((d) => d).length;

    return AppCard(
      tier: CardTier.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '连续写作',
            style: AppTextStyles.label.copyWith(
              color: subtleColor,
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppDimensions.md),

          // 大数字 + 当前称号
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                reached?.icon ?? '📝',
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$streakDays',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: streakDays > 0 ? goldColor : subtleColor,
                            fontFamily: 'MaShanZheng',
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '天',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtleColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reached == null
                          ? '写下第一篇，开始你的连续'
                          : '已达成「${reached.name}」· ${reached.description}',
                      style: AppTextStyles.label.copyWith(
                        color: subtleColor,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (progress != null) ...[
            const SizedBox(height: AppDimensions.md),
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
              progressLabel,
              style: TextStyle(fontSize: 11, color: subtleColor),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              progressLabel,
              style: TextStyle(fontSize: 11, color: subtleColor),
            ),
          ],

          const SizedBox(height: AppDimensions.lg),
          Container(height: 1, color: subtleColor.withValues(alpha: 0.15)),
          const SizedBox(height: AppDimensions.md),

          // 本周
          Row(
            children: [
              Text(
                '本周',
                style: AppTextStyles.cardTitle.copyWith(
                  color: textColor,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '写了 $weekCount / 7 天',
                style: TextStyle(fontSize: 11, color: subtleColor),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final hasWritten = i < weekDays.length && weekDays[i];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasWritten ? goldColor : Colors.transparent,
                      border: Border.all(
                        color: hasWritten
                            ? goldColor
                            : subtleColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: hasWritten
                        ? Icon(
                            Icons.check,
                            size: 17,
                            color: isDark
                                ? AppColors.darkCardBackground
                                : AppColors.cardBackground,
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    const ['日', '一', '二', '三', '四', '五', '六'][i],
                    style: TextStyle(fontSize: 12, color: subtleColor),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
