import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/diary_entry.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../../shared/widgets/app_card.dart';
import '../../diary_list/providers/diary_list_provider.dart';
import '../../statistics/providers/statistics_provider.dart';
import '../../../shared/widgets/segmented_toggle.dart';
import '../widgets/gear_date_picker.dart';
import '../../statistics/services/statistics_service.dart';
import '../../statistics/widgets/mood_trend_chart.dart';
import '../../statistics/widgets/mood_distribution_chart.dart';
import '../../statistics/widgets/word_count_trend.dart';
import '../../statistics/widgets/tag_cloud_widget.dart';
import '../widgets/time_distribution.dart';
import '../widgets/yearly_heatmap.dart';
import '../widgets/calendar_view.dart';
import '../widgets/most_memorable_card.dart';
import '../widgets/diary_constellation.dart';
import '../widgets/streak_card.dart';
import 'yearly_report_screen.dart';

/// 回顾页
///
/// 改版前这里是 **11 张各自独立的卡片**，一路往下平铺：连续天数、本周、
/// 月统计、月历、星座、心情趋势、心情分布、字数趋势、写作时间、标签云……
/// 问题不在数量，而在**没有层级**——每张卡都一样重，用户看不出该先看什么，
/// 而且每张卡自带一层「白底 + 阴影 + 20 圆角」，页面被边框切得稀碎。
///
/// 改版后收敛为 5 块，按「叙事 → 归档 → 洞察」排：
/// 1. **最值得重读**（primary）—— 全页唯一露出正文的地方
/// 2. **连续写作 + 本周**（hero，合并卡）—— 一句话讲完「你有没在坚持」
/// 3. **本月统计**（primary）
/// 4. **写作年历**（primary）—— 年盘 / 月历切换，共用一张卡
/// 5. **数据洞察**（quiet，分组卡）—— 5 个子图表收进同一张卡，可折叠
class ReviewScreen extends StatefulWidget {
  final ValueChanged<String>? onTagTapped;

  const ReviewScreen({super.key, this.onTagTapped});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final DiaryRepository _repository = DiaryRepository();
  bool _weekLoading = true;

  /// 本周写作情况：从「周日」起的连续 7 天，`true` 表示那天有记录
  ///
  /// 注意起算日是**周日**（`weekday % 7` 让周日的 0 落在首位），
  /// 与 `StreakCard` 里 `['日','一',...]` 的星期标签顺序一致。
  List<bool> _weekDays = [];

  /// 全年每天的字数与心情，供星座图
  Map<int, ({int words, String mood})> _dailyStats = {};

  /// 全年字数最多的一篇，供「最值得重读」
  DiaryEntry? _highlight;

  /// 已折叠的分组（key 为分组标识）
  final Set<String> _collapsed = <String>{};

  /// 年历卡当前视图：0 = 星座年盘，1 = 月历，2 = 齿轮检索器
  int _calendarMode = 0;

  /// 齿轮检索器当前选中的日期（该周周一）
  DateTime? _gearSelectedDate;

  static const String _kInsights = 'insights';

  @override
  void initState() {
    super.initState();
    _loadReviewExtras();
  }

  /// 加载回顾页专属数据（provider 不提供的部分）
  ///
  /// 三件事并发：
  /// 1. 本周哪几天有记录 —— 用一次 `getMonthDayStats` 拿整月，**不逐天查库**
  /// 2. 全年每日字数+心情（星座图）
  /// 3. 全年字数最多的一篇（最值得重读）
  Future<void> _loadReviewExtras() async {
    final now = DateTime.now();
    final year = now.year;

    final results = await Future.wait([
      _repository.getMonthDayStats(now.year, now.month),
      StatisticsService.getYearDailyStats(year),
      StatisticsService.getLongestEntryOfYear(year),
    ]);
    if (!mounted) return;

    final monthStats = results[0] as Map<int, ({int count, String mood})>;
    final dailyStats = results[1] as Map<int, ({int words, String mood})>;
    final highlight = results[2] as DiaryEntry?;

    // 本周：从本周日到今天，看哪几天在 monthStats 里
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final weekDays = <bool>[];
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      // 跨月时该天不在本月统计里 → 视为无记录（回退不查库）
      final inMonth = date.year == now.year && date.month == now.month;
      weekDays.add(inMonth && monthStats.containsKey(date.day));
    }

    setState(() {
      _weekDays = weekDays;
      _dailyStats = dailyStats;
      _highlight = highlight;
      _weekLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StatisticsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // AppBar：只留标题与年报入口。
        // 原先这里还塞着「7天/14天/30天」切换，它其实是**图表的参数**，
        // 放在页面级 AppBar 上属于层级错位 —— 已移进「数据洞察」分组卡的卡头。
        Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 8, 20, 8),
          child: Row(
            children: [
              Text(
                '回顾',
                style: AppTextStyles.heading.copyWith(
                  color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                ),
              ),
              const Spacer(),
              YearReportButton(year: DateTime.now().year),
            ],
          ),
        ),

        Expanded(
          child: provider.loading || _weekLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color:
                        isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 1. 最值得重读：整个页面唯一露出正文的地方，放最前面
                    if (_highlight != null) ...[
                      MostMemorableCard(
                        entry: _highlight!,
                        onRead: () => openHighlightEntry(context, _highlight!),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                    ],

                    // 2. 连续写作 + 本周（合并卡）
                    StreakCard(
                      streakDays: provider.streakDays,
                      weekDays: _weekDays,
                    ),
                    const SizedBox(height: AppDimensions.lg),

                    // 3. 本月统计
                    _buildMonthlyStatsCard(isDark, provider.monthlyStats),
                    const SizedBox(height: AppDimensions.lg),

                    // 4. 写作年历（年盘 / 月历共用一张卡）
                    _buildYearCalendarCard(isDark, provider),
                    const SizedBox(height: AppDimensions.lg),

                    // 5. 数据洞察（分组卡，可折叠）
                    _buildInsightsCard(isDark, provider),
                  ],
                ),
        ),
      ],
    );
  }

  /// 写作年历：星座年盘与月历二选一，共用一张卡
  ///
  /// 之前这两块是**两张独立卡片**上下叠着，都在表达「今年的记录分布」，
  /// 一个圆盘一个方格，用户得同时看两遍。改成切换后，一次只看一种视图，
  /// 页面少了一层。
  Widget _buildYearCalendarCard(bool isDark, StatisticsProvider provider) {
    final now = DateTime.now();
    final hasConstellation = _dailyStats.isNotEmpty;
    final showConstellation = hasConstellation && _calendarMode == 0;

    Widget body;
    if (showConstellation) {
      body = DiaryConstellation(
        dailyStats: _dailyStats,
        isLeapYear: isLeapYear(now.year),
        bare: true,
      );
    } else if (_calendarMode == 2) {
      // 齿轮检索器：三齿轮咬合选年/月/周，下方日历显示该月并高亮选中周
      final selected = _gearSelectedDate ?? now;
      body = Column(
        children: [
          GearDatePicker(
            initialDate: selected,
            onDateChanged: (d) => setState(() => _gearSelectedDate = d),
          ),
          const SizedBox(height: AppDimensions.md),
          CalendarView(
            bare: true,
            initialMonth: DateTime(selected.year, selected.month),
            selectedDate: selected,
            onDateSelected: (date) => setState(() => _gearSelectedDate = date),
          ),
        ],
      );
    } else if (!hasConstellation && provider.yearlyDates.isNotEmpty) {
      // 极端情况下拿不到每日统计时，退回原来的方格热力图
      body = YearlyHeatmap(entryDates: provider.yearlyDates);
    } else {
      body = const CalendarView(bare: true);
    }

    return AppCard(
      tier: CardTier.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '写作年历',
                style: AppTextStyles.cardTitle.copyWith(
                  color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              // 拿不到全年统计时无从画年盘，那时不显示切换器
              if (hasConstellation)
                SegmentedToggle(
                  labels: const ['年盘', '月历', '齿轮'],
                  index: _calendarMode,
                  onChanged: (i) => setState(() => _calendarMode = i),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          body,
        ],
      ),
    );
  }

  /// 数据洞察：5 个子图表收进同一张卡
  ///
  /// 为什么用「共享容器」而不是「每张图各占一张卡」：
  /// 亮色模式下背景永远铺整幅水彩图，卡片一旦半透明正文对比度就崩
  /// （实测 30 张背景图无一张能达 WCAG AA）。所以「轻」不能靠透出背景，
  /// 只能靠**减少卡片数量**——把 5 张卡合成 1 张，内部用分隔线分区。
  Widget _buildInsightsCard(bool isDark, StatisticsProvider provider) {
    final subtleColor =
        isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    final hasMoodTrend = provider.moodTrend.values.any((v) => v.isNotEmpty);
    final hasMoodDist = provider.moodDistribution.isNotEmpty;
    final hasWords = provider.wordCountTrend.values.any((v) => v > 0);
    final hasTime = provider.timeDistribution.values.any((v) => v > 0);
    final hasTags = provider.tagCloud.isNotEmpty;

    // 一项数据都没有 → 整张卡不出现，而不是留个空壳
    if (!hasMoodTrend && !hasMoodDist && !hasWords && !hasTime && !hasTags) {
      return const SizedBox.shrink();
    }

    final blocks = <Widget>[
      if (hasMoodTrend)
        MoodTrendChart(moodTrend: provider.moodTrend, bare: true),
      if (hasMoodDist)
        MoodDistributionChart(
            moodStats: provider.moodDistribution, bare: true),
      if (hasWords) WordCountTrend(trendData: provider.wordCountTrend, bare: true),
      if (hasTime) TimeDistribution(timeStats: provider.timeDistribution, bare: true),
      if (hasTags)
        TagCloudWidget(
          tagData: provider.tagCloud,
          bare: true,
          onTagTapped: (tag) {
            context.read<DiaryListProvider>().filterByTag(tag);
            widget.onTagTapped?.call(tag);
          },
        ),
    ];

    final collapsed = _collapsed.contains(_kInsights);

    return AppCard(
      tier: CardTier.quiet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '数据洞察',
                style: AppTextStyles.cardTitle.copyWith(
                  color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              // 趋势天数只影响图表，折叠时一并收起
              if (!collapsed) ...[
                SegmentedToggle(
                  labels: const ['7天', '14天', '30天'],
                  index: const [7, 14, 30].indexOf(provider.trendDays),
                  onChanged: (i) => provider.setTrendDays(const [7, 14, 30][i]),
                ),
                const SizedBox(width: 6),
              ],
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  if (collapsed) {
                    _collapsed.remove(_kInsights);
                  } else {
                    _collapsed.add(_kInsights);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedRotation(
                    turns: collapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.expand_more,
                      size: 22,
                      color: subtleColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 用 AnimatedSize 而不是 AnimatedCrossFade：后者内部是 Stack，
          // 放进 ListView 里的 Column 时高度无界，容易炸 layout。
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: collapsed
                ? const SizedBox(width: double.infinity)
                // 图表内部大量 9~11px 小字，系统/全局大字号下会挤压溢出，
                // 因此图表区局部钳制缩放：尊重缩小，上限 1.15。
                : MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: MediaQuery.textScalerOf(context).clamp(
                        minScaleFactor: 0.8,
                        maxScaleFactor: 1.15,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppDimensions.md),
                      child: Column(
                        children: [
                          for (var i = 0; i < blocks.length; i++) ...[
                            if (i > 0) ...[
                              const SizedBox(height: AppDimensions.lg),
                              Container(
                                height: 1,
                                color: subtleColor.withValues(alpha: 0.10),
                              ),
                              const SizedBox(height: AppDimensions.lg),
                            ],
                            blocks[i],
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatsCard(bool isDark, Map<String, int> monthlyStats) {
    final goldColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final count = monthlyStats['count'] ?? 0;
    final words = monthlyStats['total_words'] ?? 0;
    final now = DateTime.now();

    return AppCard(
      tier: CardTier.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${now.month}月统计',
            style: AppTextStyles.cardTitle.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.edit_note,
                  value: '$count',
                  label: '篇日记',
                  color: goldColor,
                  subtleColor: subtleColor,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: subtleColor.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.text_fields,
                  value: words.toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (m) => '${m[1]},'),
                  label: '总字数',
                  color: goldColor,
                  subtleColor: subtleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color subtleColor;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.subtleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'MaShanZheng',
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: subtleColor)),
      ],
    );
  }
}
