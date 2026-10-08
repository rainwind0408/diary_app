import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/diary_repository.dart';
import '../providers/achievement_provider.dart';
import '../models/achievement.dart';
import '../services/garden_arranger.dart';
import '../widgets/streak_progress.dart';
import '../widgets/growth_garden.dart';
import '../widgets/achievement_grid.dart';
import '../widgets/achievement_timeline.dart';

/// 成就页
///
/// 结构从「4 段等大网格」改成了三层叙事：
/// 1. **成长花园**（主角）——把成就收集隐喻成植物生长，一眼看出花园有多满
/// 2. **下一个成就**（牵引）——只指一个目标，给明确进度
/// 3. **成就图鉴 + 时间轴**（归档）——分类网格降级为可折叠的查阅入口
///
/// 右上角可在「花园」与「时间轴」两个视图间切换。
class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  int _streakDays = 0;
  int _totalEntries = 0;
  bool _loadingData = true;

  /// false = 花园视图，true = 时间轴视图
  bool _showTimeline = false;

  /// 图鉴里已展开的分类（默认全部折叠：花园才是主角，图鉴是查阅入口）
  final Set<AchievementCategory> _expandedCategories = <AchievementCategory>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = DiaryRepository();
    final streak = await repo.getStreakDays();
    final entries = await repo.getAllEntries();
    if (!mounted) return;

    setState(() {
      _streakDays = streak;
      _totalEntries = entries.length;
      _loadingData = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AchievementProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final achievements = provider.achievements;

    return Column(
      children: [
        _buildAppBar(context, provider, isDark),
        Expanded(
          child: provider.loading || _loadingData
              ? Center(
                  child: CircularProgressIndicator(
                    color:
                        isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                  ),
                )
              : _showTimeline
                  ? AchievementTimeline(
                      achievements: achievements,
                      streakDays: _streakDays,
                    )
                  : _buildGardenView(provider, achievements),
        ),
      ],
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    AchievementProvider provider,
    bool isDark,
  ) {
    final subtleColor =
        isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Container(
      padding:
          EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 12, 8),
      child: Row(
        children: [
          Text(
            '我的成就',
            style: AppTextStyles.heading.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            ),
          ),
          const Spacer(),
          Text(
            '${provider.unlockedCount}/${provider.totalCount}',
            style: AppTextStyles.label.copyWith(color: subtleColor),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: _showTimeline ? '看花园' : '看时间轴',
            onPressed: () => setState(() => _showTimeline = !_showTimeline),
            icon: Icon(
              _showTimeline ? Icons.local_florist_outlined : Icons.timeline,
              size: 22,
              color: subtleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGardenView(
    AchievementProvider provider,
    List<Achievement> achievements,
  ) {
    final goal = GardenArranger.nextGoal(achievements);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        // 1. 成长花园：主角
        GrowthGarden(achievements: achievements),
        const SizedBox(height: 16),

        // 2. 下一个成就：牵引
        StreakProgress(
          streakDays: _streakDays,
          goal: goal,
          currentValue: goal == null
              ? null
              : GardenArranger.currentValue(
                  goal,
                  totalEntries: _totalEntries,
                  streakDays: _streakDays,
                  featureUsage: const {},
                ),
          targetValue: goal == null ? null : GardenArranger.targetValue(goal),
        ),
        const SizedBox(height: 24),

        // 3. 图鉴：分类网格下沉，作为查阅入口
        _buildSectionLabel('成就图鉴'),
        const SizedBox(height: 12),
        _buildCategory(provider, AchievementCategory.writing),
        const SizedBox(height: 18),
        _buildCategory(provider, AchievementCategory.streak),
        const SizedBox(height: 18),
        _buildCategory(provider, AchievementCategory.feature),
        const SizedBox(height: 18),
        _buildCategory(provider, AchievementCategory.special),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      '── $text ──',
      style: AppTextStyles.label.copyWith(
        color: isDark ? AppColors.darkTitleText : AppColors.titleText,
        fontSize: 13,
      ),
    );
  }

  Widget _buildCategory(
    AchievementProvider provider,
    AchievementCategory category,
  ) {
    final items = provider.getByCategory(category);
    final unlocked = items.where((a) => a.isUnlocked).length;
    final open = _expandedCategories.contains(category);

    return AchievementGrid(
      title: GardenArranger.categoryLabel(category),
      achievements: items,
      expanded: open,
      countLabel: '$unlocked / ${items.length}',
      onToggle: () => setState(() {
        if (open) {
          _expandedCategories.remove(category);
        } else {
          _expandedCategories.add(category);
        }
      }),
    );
  }
}
