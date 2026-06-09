import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/diary_repository.dart';
import '../providers/achievement_provider.dart';
import '../models/achievement.dart';
import '../widgets/streak_progress.dart';
import '../widgets/achievement_grid.dart';

class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  int _streakDays = 0;
  List<bool> _weekDays = [];
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = DiaryRepository();
    final streak = await repo.getStreakDays();
    if (!mounted) return;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = <bool>[];
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final entries = await repo.getEntriesByDate(day);
      weekDays.add(entries.isNotEmpty);
      if (!mounted) return;
    }

    setState(() {
      _streakDays = streak;
      _weekDays = weekDays;
      _loadingData = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AchievementProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // AppBar
        Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 8, 20, 8),
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
                style: AppTextStyles.label.copyWith(
                  color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: provider.loading || _loadingData
              ? Center(
                  child: CircularProgressIndicator(
                    color:
                        isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Streak card
                    StreakProgress(
                      streakDays: _streakDays,
                      weekDays: _weekDays,
                    ),
                    const SizedBox(height: 20),

                    // Achievements by category
                    _buildCategorySection(
                      '写作成就',
                      provider.getByCategory(AchievementCategory.writing),
                    ),
                    const SizedBox(height: 20),
                    _buildCategorySection(
                      '连续写作',
                      provider.getByCategory(AchievementCategory.streak),
                    ),
                    const SizedBox(height: 20),
                    _buildCategorySection(
                      '功能使用',
                      provider.getByCategory(AchievementCategory.feature),
                    ),
                    const SizedBox(height: 20),
                    _buildCategorySection(
                      '特殊成就',
                      provider.getByCategory(AchievementCategory.special),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(String title, List<Achievement> achievements) {
    return AchievementGrid(title: title, achievements: achievements);
  }
}
