import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../../data/models/diary_entry.dart';
import '../../statistics/widgets/mood_distribution_chart.dart';
import '../widgets/mood_calendar.dart';

class MoodDetailScreen extends StatefulWidget {
  const MoodDetailScreen({super.key});

  @override
  State<MoodDetailScreen> createState() => _MoodDetailScreenState();
}

class _MoodDetailScreenState extends State<MoodDetailScreen> {
  final DiaryRepository _repository = DiaryRepository();
  List<DiaryEntry> _allEntries = [];
  bool _loading = true;
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final entries = await _repository.getAllEntries();
    if (mounted) {
      setState(() {
        _allEntries = entries;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final goldColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20,
              color: isDark ? AppColors.darkSubtleText : AppColors.subtleText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '心情统计',
          style: AppTextStyles.heading.copyWith(
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: goldColor),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Overview stats
                  _buildOverview(isDark, goldColor),
                  const SizedBox(height: 16),

                  // Mood distribution chart
                  MoodDistributionChart(moodStats: _getMoodStats()),
                  const SizedBox(height: 16),

                  // Mood calendar
                  _buildMonthSelector(isDark, goldColor),
                  const SizedBox(height: 8),
                  MoodCalendar(
                    month: _currentMonth,
                    dayMoods: _getMonthMoods(_currentMonth),
                  ),
                  const SizedBox(height: 16),

                  // Top moods
                  _buildTopMoods(isDark, goldColor),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildOverview(bool isDark, Color goldColor) {
    final entriesWithMood = _allEntries.where((e) => e.mood.isNotEmpty).length;
    final totalEntries = _allEntries.length;
    final moodRate = totalEntries > 0
        ? (entriesWithMood / totalEntries * 100).round()
        : 0;

    // Most common mood
    final moodCount = <String, int>{};
    for (final entry in _allEntries) {
      if (entry.mood.isNotEmpty) {
        moodCount[entry.mood] = (moodCount[entry.mood] ?? 0) + 1;
      }
    }
    String topMood = '';
    int topCount = 0;
    moodCount.forEach((mood, count) {
      if (count > topCount) {
        topMood = mood;
        topCount = count;
      }
    });

    // Average intensity
    final entriesWithIntensity =
        _allEntries.where((e) => e.mood.isNotEmpty).toList();
    final avgIntensity = entriesWithIntensity.isNotEmpty
        ? entriesWithIntensity
                .map((e) => e.moodIntensity)
                .reduce((a, b) => a + b) /
            entriesWithIntensity.length
        : 0.0;

    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final borderColor = isDark ? AppColors.darkDividerLine : AppColors.dividerLine;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _buildStatItem(
            '记录率',
            '$moodRate%',
            Icons.mood,
            goldColor,
            subtleColor,
          ),
          Container(
            width: 1,
            height: 40,
            color: borderColor.withValues(alpha: 0.3),
          ),
          _buildStatItem(
            '最常心情',
            topMood.isNotEmpty ? topMood : '-',
            Icons.favorite,
            goldColor,
            subtleColor,
          ),
          Container(
            width: 1,
            height: 40,
            color: borderColor.withValues(alpha: 0.3),
          ),
          _buildStatItem(
            '平均强度',
            avgIntensity > 0 ? avgIntensity.toStringAsFixed(1) : '-',
            Icons.speed,
            goldColor,
            subtleColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color goldColor,
    Color subtleColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: goldColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: goldColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: subtleColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(bool isDark, Color goldColor) {
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _currentMonth = DateTime(
                _currentMonth.year,
                _currentMonth.month - 1,
              );
            });
          },
          icon: Icon(Icons.chevron_left, color: subtleColor),
        ),
        Text(
          '${_currentMonth.year}年${_currentMonth.month}月',
          style: AppTextStyles.cardTitle.copyWith(
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
          ),
        ),
        IconButton(
          onPressed: () {
            final next = DateTime(
              _currentMonth.year,
              _currentMonth.month + 1,
            );
            if (!next.isAfter(DateTime.now())) {
              setState(() => _currentMonth = next);
            }
          },
          icon: Icon(Icons.chevron_right, color: subtleColor),
        ),
      ],
    );
  }

  Map<int, String> _getMonthMoods(DateTime month) {
    final result = <int, String>{};
    for (final entry in _allEntries) {
      if (entry.createdAt.year == month.year &&
          entry.createdAt.month == month.month &&
          entry.mood.isNotEmpty) {
        result[entry.createdAt.day] = entry.mood;
      }
    }
    return result;
  }

  Map<String, int> _getMoodStats() {
    final moodCount = <String, int>{};
    for (final entry in _allEntries) {
      if (entry.mood.isNotEmpty) {
        moodCount[entry.mood] = (moodCount[entry.mood] ?? 0) + 1;
      }
    }
    return moodCount;
  }

  Widget _buildTopMoods(bool isDark, Color goldColor) {
    final moodCount = <String, int>{};
    for (final entry in _allEntries) {
      if (entry.mood.isNotEmpty) {
        moodCount[entry.mood] = (moodCount[entry.mood] ?? 0) + 1;
      }
    }

    final sorted = moodCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) {
      return const SizedBox.shrink();
    }

    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final borderColor = isDark ? AppColors.darkDividerLine : AppColors.dividerLine;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '心情排行',
            style: AppTextStyles.cardTitle.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.take(5).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final mood = entry.value;
            final percentage = _allEntries.isNotEmpty
                ? (mood.value / _allEntries.length * 100).round()
                : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(mood.key, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: mood.value / sorted.first.value,
                        backgroundColor: goldColor.withValues(alpha: 0.1),
                        valueColor:
                            AlwaysStoppedAnimation(goldColor.withValues(alpha: 0.6)),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${mood.value}次 ($percentage%)',
                    style: TextStyle(
                      fontSize: 11,
                      color: subtleColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
