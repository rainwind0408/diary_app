import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/toast.dart';
import '../../diary_encrypt/widgets/pin_input_dialog.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../diary_encrypt/services/pin_service.dart';
import '../../diary_detail/screens/diary_detail_screen.dart';
import '../../weather/providers/seasonal_provider.dart';
import '../../achievements/providers/achievement_provider.dart';
import '../providers/date_filter_provider.dart';
import '../providers/diary_list_provider.dart';
import '../widgets/misc/empty_state.dart';
import '../widgets/filters/search_bar.dart';
import '../widgets/filters/tag_cloud.dart';
import '../widgets/misc/card_flow_view.dart';
import '../widgets/misc/greeting_banner.dart';
import '../widgets/misc/cover_photo_banner.dart';
import '../widgets/misc/collapsible_calendar.dart';
import '../services/greeting_service.dart';
import '../../../data/models/diary_entry.dart';

class DiaryListScreen extends StatefulWidget {
  final VoidCallback? onNavigateToWrite;

  const DiaryListScreen({super.key, this.onNavigateToWrite});

  @override
  State<DiaryListScreen> createState() => DiaryListScreenState();
}

class DiaryListScreenState extends State<DiaryListScreen> {
  bool _searchMode = false;
  int _streakDays = 0;
  List<bool> _weekDays = [];

  /// 当前展示月份的封面图路径（首张为「当前日期」的图片）
  List<String> _coverImages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntries();
      _loadStreakAndWeek();
      _loadCoverImages();
    });
  }

  /// 外部调用：刷新连续天数和本周数据
  void refreshStreak() {
    _loadStreakAndWeek();
    _loadCoverImages();
  }

  void _loadEntries() {
    final date = context.read<DateFilterProvider>().selectedDate;
    context.read<DiaryListProvider>().loadEntries(date);
  }

  /// 日期被选中（来自日历卡片）
  void _onDatePicked(DateTime date) {
    context.read<DateFilterProvider>().setDate(date);
    _loadEntries();
    _loadCoverImages();
  }

  /// 加载当前月份的封面图
  Future<void> _loadCoverImages() async {
    final date = context.read<DateFilterProvider>().selectedDate;
    final repo = DiaryRepository();
    try {
      final paths = await repo.getMonthImagePaths(date.year, date.month);
      if (!mounted) return;
      setState(() => _coverImages = paths);
    } catch (_) {
      if (!mounted) return;
      setState(() => _coverImages = []);
    }
  }

  Future<void> _loadStreakAndWeek() async {
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
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchMode = !_searchMode;
      if (!_searchMode) {
        context.read<DiaryListProvider>().clearSearch();
        _loadEntries();
      }
    });
  }

  Future<void> _handleLock(DiaryEntry entry) async {
    if (entry.id == null) return;
    final pin = await PinInputDialog.show(
      context,
      title: '设置密码',
      isSetting: true,
    );
    if (pin == null || !mounted) return;

    final hash = PinService.hashPin(pin);
    await context.read<DiaryListProvider>().lockEntry(entry.id!, hash);
    if (mounted) {
      Toast().show(context, '日记已锁定', ToastType.success);
      _checkAchievements();
    }
  }

  Future<void> _handleUnlock(DiaryEntry entry) async {
    if (entry.id == null) return;
    final pin = await PinInputDialog.show(
      context,
      title: '输入密码解锁',
    );
    if (pin == null || !mounted) return;

    if (PinService.verifyPin(pin, entry.pinHash)) {
      await context.read<DiaryListProvider>().unlockEntry(entry.id!);
      if (mounted) {
        Toast().show(context, '日记已解锁', ToastType.success);
      }
    } else if (mounted) {
      Toast().show(context, '密码错误', ToastType.error);
    }
  }

  Future<void> _checkAchievements() async {
    if (!mounted) return;
    final repo = DiaryRepository();
    final allEntries = await repo.getAllEntries();
    final streakDays = await repo.getStreakDays();
    if (!mounted) return;

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final entryDatesThisMonth = allEntries
        .where(
            (e) => e.createdAt.year == now.year && e.createdAt.month == now.month)
        .map((e) => e.createdAt.day)
        .toSet();
    final monthPerfect = entryDatesThisMonth.length >= daysInMonth;

    final featureUsage = <String, int>{
      'photo': allEntries.any((e) => e.images.isNotEmpty) ? 1 : 0,
      'audio': allEntries.any((e) => e.audios.isNotEmpty) ? 1 : 0,
      'tag': allEntries.any((e) => e.tags.isNotEmpty) ? 1 : 0,
      'lock': allEntries.any((e) => e.isLocked) ? 1 : 0,
      'total_words': allEntries.fold(0, (sum, e) => sum + e.wordCount),
      'month_perfect': monthPerfect ? 1 : 0,
    };

    final achievementProvider = context.read<AchievementProvider>();
    final newAchievements = await achievementProvider.checkAndUnlock(
      totalEntries: allEntries.length,
      streakDays: streakDays,
      featureUsage: featureUsage,
    );

    if (mounted && newAchievements.isNotEmpty) {
      for (final achievement in newAchievements) {
        if (!mounted) return;
        Toast().show(context, '🎉 解锁成就: ${achievement.name}', ToastType.success);
      }
    }
  }

  Future<void> _handleEdit(DiaryEntry entry) async {
    if (entry.isLocked) {
      final pin = await PinInputDialog.show(context, title: '输入密码查看');
      if (pin == null || !mounted) return;
      if (!PinService.verifyPin(pin, entry.pinHash)) {
        if (mounted) Toast().show(context, '密码错误', ToastType.error);
        return;
      }
    }
    if (!mounted) return;

    // 跳转到详情页
    final listProvider = context.read<DiaryListProvider>();
    final entries = listProvider.entries;
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiaryDetailScreen(
          allEntries: entries,
          initialIndex: index,
        ),
      ),
    ).then((_) {
      // 返回时刷新列表
      if (mounted) {
        final date = context.read<DateFilterProvider>().selectedDate;
        listProvider.loadEntries(date);
      }
    });
  }

  Future<void> _handleDelete(
      DiaryEntry entry, DiaryListProvider listProvider) async {
    if (entry.isLocked) {
      final pin = await PinInputDialog.show(context, title: '输入密码');
      if (pin == null || !mounted) return;
      if (!PinService.verifyPin(pin, entry.pinHash)) {
        if (mounted) Toast().show(context, '密码错误', ToastType.error);
        return;
      }
    }
    if (!mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '删除日记',
      message: '确定要删除这篇日记吗？',
    );
    if (!mounted) return;
    if (confirmed && entry.id != null) {
      await listProvider.deleteEntry(entry.id!);
      if (mounted) {
        if (listProvider.error != null) {
          Toast().show(context, '删除失败，请重试', ToastType.error);
        } else {
          Toast().show(context, '日记已删除', ToastType.success);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFilter = context.watch<DateFilterProvider>();
    final listProvider = context.watch<DiaryListProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 搜索模式下只保留搜索框与结果列表，隐藏封面图与日历
    if (_searchMode) {
      return Column(
        children: [
          _buildAppBar(isDark, listProvider),
          DiarySearchBar(
            onSearch: (keyword) => listProvider.searchEntries(keyword),
            onClear: () {
              listProvider.clearSearch();
              _loadEntries();
            },
          ),
          if (listProvider.searchKeyword.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '搜索 "${listProvider.searchKeyword}" - 找到 ${listProvider.entries.length} 条结果',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? AppColors.darkLabelText : AppColors.labelText,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildContent(listProvider, isDark)),
        ],
      );
    }

    // 常规模式：AppBar 固定，其下整体可滚动。
    // 封面图卡片与日历头条常驻；展开日历时页面自然上推，
    // 卡片轮播区保持在 viewport 最小高度之上，不会被压塌。
    return Column(
      children: [
        _buildAppBar(isDark, listProvider),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 列表内容至少占满剩余视口，避免卡片区被挤没
              final minContentHeight =
                  (constraints.maxHeight * 0.45).clamp(180.0, 420.0);

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    children: [
                      _buildGreetingBanner(),

                      CoverPhotoBanner(
                        imagePaths: _coverImages,
                        monthLabel:
                            '${dateFilter.selectedDate.year}年${dateFilter.selectedDate.month}月',
                      ),

                      // 日期导航由日历卡片唯一承担：点头条展开月历网格选日。
                      // 封面图下方不再叠加任何重复的月份文案或日期条。
                      CollapsibleCalendar(
                        selectedDate: dateFilter.selectedDate,
                        onDateSelected: _onDatePicked,
                        onMonthChanged: (_) => _loadCoverImages(),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 4, top: 4, bottom: 4),
                        child: TagCloud(
                          selectedTag: listProvider.selectedTag,
                          date: dateFilter.selectedDate,
                          onTagSelected: (tag) {
                            listProvider.filterByTag(tag,
                                date: dateFilter.selectedDate);
                            if (tag == null) _loadEntries();
                          },
                        ),
                      ),

                      // 日记内容区：保证最小高度，让卡片轮播有足够空间
                      SizedBox(
                        height: minContentHeight,
                        child: _buildContent(listProvider, isDark),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 内容区域：加载中 / 空态 / 搜索结果列表 / 卡片轮播
  Widget _buildContent(DiaryListProvider listProvider, bool isDark) {
    if (listProvider.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? AppColors.darkAccentPink : AppColors.accentPink,
        ),
      );
    }
    if (listProvider.entries.isEmpty) {
      return EmptyState(
        message: _searchMode ? '未找到匹配的日记' : null,
      );
    }
    if (_searchMode) {
      return _buildSearchList(listProvider, isDark);
    }
    return CardFlowView(
      entries: listProvider.entries,
      onEdit: (DiaryEntry entry) => _handleEdit(entry),
      onDelete: (DiaryEntry entry) => _handleDelete(entry, listProvider),
      onLock: (DiaryEntry entry) => _handleLock(entry),
      onUnlock: (DiaryEntry entry) => _handleUnlock(entry),
    );
  }

  Widget _buildAppBar(bool isDark, DiaryListProvider listProvider) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 8, 12, 8),
      child: Row(
        children: [
          // 花体标题
          Text(
            '我的日记',
            style: AppTextStyles.handwritingTitle.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            ),
          ),
          const Spacer(),
          // 搜索按钮
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(
              _searchMode ? Icons.close : Icons.search,
              size: 22,
              color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingBanner() {
    final seasonal = context.watch<SeasonalProvider>();
    final greeting = GreetingService.generate(
      time: DateTime.now(),
      weatherDescription: seasonal.weatherData?.description,
      weatherEmoji: seasonal.weatherData?.emoji,
      streakDays: _streakDays,
    );

    return GreetingBanner(
      greeting: greeting,
      streakDays: _streakDays,
      weekDays: _weekDays,
    );
  }

  /// 搜索结果使用垂直列表模式
  Widget _buildSearchList(DiaryListProvider listProvider, bool isDark) {
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final bodyColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: listProvider.entries.length,
      itemBuilder: (context, index) {
        final entry = listProvider.entries[index];
        return GestureDetector(
          onTap: () => _handleEdit(entry),
          onLongPress: () => _handleDelete(entry, listProvider),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormatter.formatShort(entry.createdAt),
                      style: TextStyle(fontSize: 12, color: subtleColor),
                    ),
                    if (entry.mood.isNotEmpty) ...[
                      const Spacer(),
                      Text(entry.mood, style: const TextStyle(fontSize: 16)),
                    ],
                  ],
                ),
                if (entry.title.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.title,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: textColor,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  entry.content,
                  style: AppTextStyles.cardBody.copyWith(
                    color: bodyColor,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
