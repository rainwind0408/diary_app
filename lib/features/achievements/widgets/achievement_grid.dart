import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/achievement.dart';
import 'achievement_badge.dart';

/// 分类成就网格
///
/// 支持可选的**折叠**：成就页的主叙事是「成长花园」，图鉴只是查阅入口，
/// 四段网格全展开会把页面拉得很长、把主角挤到看不见。
/// 折叠后每段只留一行标题 + `已解锁 / 总数`，需要时再展开。
class AchievementGrid extends StatelessWidget {
  final String title;
  final List<Achievement> achievements;

  /// 是否展开。为 null（或 [onToggle] 为 null）时**不可折叠**，始终展开。
  final bool? expanded;

  /// 点标题切换展开。为 null 时不显示折叠箭头、也不响应点击。
  final VoidCallback? onToggle;

  /// 标题右侧的计数文案，如 `3 / 5`
  final String? countLabel;

  const AchievementGrid({
    super.key,
    required this.title,
    required this.achievements,
    this.expanded,
    this.onToggle,
    this.countLabel,
  });

  bool get _foldable => onToggle != null && expanded != null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final open = !_foldable || expanded!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10, top: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '── $title ──',
                    style: AppTextStyles.label.copyWith(
                      color: textColor,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (countLabel != null)
                  Text(
                    countLabel!,
                    style: TextStyle(fontSize: 11, color: subtleColor),
                  ),
                if (_foldable) ...[
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: open ? 0 : -0.25,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: subtleColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_foldable)
          // 用 AnimatedSize 而不是 AnimatedCrossFade：后者内部是 Stack，
          // 放进 ListView 里的 Column 时高度无界，容易炸 layout。
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: open ? _buildGrid(context) : const SizedBox(width: double.infinity),
          )
        else
          _buildGrid(context),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 每行 5 个、间距 8 → 4 个间隙。
        // 旧写法 `(MediaQuery.width - 56) / 5` 把「列表左右各 20 内边距 + 16 余量」
        // 硬编成 56，外层一改内边距格子就会挤到换行。这里改读真实约束。
        final rawWidth = (constraints.maxWidth - 8 * 4) / 5;
        final itemWidth = rawWidth.clamp(44.0, 92.0);

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: achievements
              .map(
                (achievement) => SizedBox(
                  width: itemWidth,
                  child: AchievementBadge(achievement: achievement),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
