import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/diary_entry.dart';
import '../../statistics/services/statistics_service.dart';
import '../../statistics/services/year_report_service.dart';
import '../models/year_summary.dart';
import '../widgets/diary_constellation.dart';
import '../widgets/most_memorable_card.dart';
import 'report_page.dart';

/// 翻页式年报（「你的这一年」）
///
/// 借鉴 Spotify Wrapped / 网易云年度报告：**全屏翻页，一页一件事**。
///
/// 与回顾页的分工：
/// - 回顾页 = **常驻仪表盘**，随时看当前状态（近 N 天趋势 + 当月统计）
/// - 年报页 = **一次性仪式**，整年快照，讲一个完整的故事
///
/// 数据全部来自 `YearReportService`，5 个聚合查询，不加载 entry 实体。
class YearlyReportScreen extends StatefulWidget {
  final int? year;

  const YearlyReportScreen({super.key, this.year});

  /// 打开年报
  static Future<void> open(BuildContext context, {int? year}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YearlyReportScreen(year: year),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<YearlyReportScreen> createState() => _YearlyReportScreenState();
}

class _YearlyReportScreenState extends State<YearlyReportScreen> {
  late final int _year;
  final PageController _controller = PageController();

  YearSummary? _summary;
  Map<int, ({int words, String mood})> _dailyStats = {};
  bool _loading = true;

  /// 当前页（用于底部进度点）
  int _page = 0;

  /// 页面列表缓存 —— 只在数据加载完成后构建一次
  List<Widget>? _pages;

  int get _pageCount => _pages?.length ?? 0;

  @override
  void initState() {
    super.initState();
    _year = widget.year ?? DateTime.now().year;
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      YearReportService.build(_year),
      StatisticsService.getYearDailyStats(_year),
    ]);
    if (!mounted) return;
    final summary = results[0] as YearSummary;
    setState(() {
      _summary = summary;
      _dailyStats = results[1] as Map<int, ({int words, String mood})>;
      _pages = _buildPages(summary);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading || _summary == null || pages == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            )
          : Stack(
              children: [
                // 翻页主体
                PageView(
                  controller: _controller,
                  onPageChanged: (p) => setState(() => _page = p),
                  children: pages,
                ),

                // 顶部关闭
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 24),
                        tooltip: '关闭',
                      ),
                    ),
                  ),
                ),

                // 底部进度点
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _buildDots(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 不显示空页：没有数据的页会被跳过
  List<Widget> _buildPages(YearSummary s) {
    final pages = <Widget>[];

    // ① 封面
    pages.add(ReportPage(
      eyebrow: '折花日记',
      hero: '${s.year}',
      unit: '你的这一年',
      caption: '翻一翻，看看这 ${s.activeDays} 天里\n你留下了什么',
      footnote: '左右滑动',
      gradient: const [Color(0xFFF6D6E4), Color(0xFFD9C2EC)],
      foreground: const Color(0xFF4A3550),
    ));

    // ② 写了多少篇
    pages.add(ReportPage(
      eyebrow: '${s.year} · 第一部分',
      hero: '',
      rollTo: s.entries,
      unit: '篇日记',
      caption: '平均每篇 ${s.avgWordsPerEntry} 字，\n你把日子一页一页折了起来',
      gradient: const [Color(0xFFCFE3F5), Color(0xFFB7D3EE)],
      foreground: const Color(0xFF1F3A52),
    ));

    // ③ 写了多少字
    pages.add(ReportPage(
      eyebrow: '${s.year} · 第二部分',
      hero: '',
      rollTo: s.words,
      unit: '个字',
      caption: '如果每个字是一粒沙，\n这已经是一片能走很久的滩涂',
      footnote: _novelEquivalent(s.words),
      gradient: const [Color(0xFFFBE3C8), Color(0xFFF5CFA4)],
      foreground: const Color(0xFF5A3A18),
    ));

    // ④ 最常在几点写
    if (s.peakHour != null) {
      pages.add(ReportPage(
        eyebrow: '${s.year} · 写作时刻',
        hero: s.peakHourLabel,
        caption: s.peakHourPoetic,
        footnote: '这一年里，这个时辰出现的次数最多',
        gradient: const [Color(0xFF3B3A63), Color(0xFF5B4A78)],
        foreground: const Color(0xFFF5EFE6),
      ));
    }

    // ⑤ 最常的情绪
    if (s.topMood.isNotEmpty) {
      final label = moodLabelOf(s.topMood);
      pages.add(ReportPage(
        eyebrow: '${s.year} · 心情底色',
        hero: s.topMood,
        unit: label,
        caption: '这一年，你最多的心情是「$label」。\n${_moodLine(label)}',
        footnote: '共出现 ${s.topMoodCount} 次',
        gradient: const [Color(0xFFD8EFD5), Color(0xFFB8E0B4)],
        foreground: const Color(0xFF254D22),
      ));
    }

    // ⑥ 最长的连续
    if (s.longestStreak > 0) {
      pages.add(ReportPage(
        eyebrow: '${s.year} · 坚持',
        hero: '',
        rollTo: s.longestStreak,
        unit: '天连续写作',
        caption: '中间没有断过。\n${_streakLine(s.longestStreak)}',
        gradient: const [Color(0xFFFFD9C9), Color(0xFFFFBFA8)],
        foreground: const Color(0xFF5C2A1A),
      ));
    }

    // ⑦ 日记星座图
    if (_dailyStats.isNotEmpty) {
      pages.add(ReportPage(
        eyebrow: '${s.year} · 星座',
        hero: '✨',
        caption: '把每一天按日期铺成一圈，\n亮一点，是那天写得多一点',
        extra: _buildConstellation(),
        gradient: const [Color(0xFF2A2A45), Color(0xFF4A3E63)],
        foreground: const Color(0xFFF2EDE4),
      ));
    }

    // ⑧ 最值得重读
    final highlight = s.highlightEntry;
    if (highlight != null) {
      pages.add(ReportPage(
        eyebrow: '${s.year} · 最值得重读',
        hero: '',
        caption: '这一年你写得最长的一篇',
        extra: _buildHighlight(highlight),
        gradient: const [Color(0xFFF7E7D3), Color(0xFFEFD6BC)],
        foreground: const Color(0xFF4A3320),
      ));
    }

    // ⑨ 收官
    pages.add(ReportPage(
      eyebrow: '${s.year} · 到此',
      hero: '🌸',
      caption: '这一年就翻到这里。\n接下来的日子，慢慢写。',
      footnote: '折花日记',
      gradient: const [Color(0xFFF6D6E4), Color(0xFFD9C2EC)],
      foreground: const Color(0xFF4A3550),
    ));

    return pages;
  }

  /// 星座图：白底卡片包一层，避免深色渐变上直接画点看不清
  Widget _buildConstellation() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
      ),
      child: DiaryConstellation(
        dailyStats: _dailyStats,
        isLeapYear: isLeapYear(_year),
      ),
    );
  }

  Widget _buildHighlight(DiaryEntry entry) {
    return MostMemorableCard(
      entry: entry,
      onRead: () => openHighlightEntry(context, entry),
    );
  }

  Widget _buildDots() {
    final total = _pageCount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.9 : 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  /// 字数换算成「相当于几本小说」
  /// 把字数折算成「读起来有多长」的一句人话
  ///
  /// 注意：**这里返回的是完整的一句话**，调用方不要再拼量词前缀 ——
  /// 早期版本写成 `'相当于一部 ${_novelEquivalent(...)} 的小说'`，
  /// 而本函数在字数少时会返回「一篇长散文」，拼出来就是
  /// 「相当于一部一篇长散文的小说」这种病句。量词必须跟数值一起决定。
  static String _novelEquivalent(int words) {
    // 按一本中篇 10 万字估算
    final books = words / 100000;
    if (books < 0.2) return '相当于一篇长散文';
    if (books < 1) return '相当于半本书';
    if (books < 3) return '相当于 ${books.toStringAsFixed(1)} 部中篇';
    return '相当于 ${books.round()} 部中篇';
  }

  static String _moodLine(String label) {
    switch (label) {
      case '开心':
        return '愿这样的日子多一些。';
      case '平静':
        return '平静是很难得的底色。';
      case '兴奋':
        return '有很多事让你眼睛发亮。';
      case '难过':
        return '写下来之后，会轻一点。';
      case '焦虑':
        return '把它写出来，本身就是一种安顿。';
      case '生气':
        return '有些情绪，需要一个出口。';
      case '孤独':
        return '至少还有这里听你说。';
      case '压力':
        return '你已经扛下了很多。';
      case '感动':
        return '被触动过很多次，是件好事。';
      case '怀念':
        return '有些人和事，值得反复想起。';
      default:
        return '这就是你这一年的温度。';
    }
  }

  static String _streakLine(int days) {
    if (days >= 100) return '百日如一，这不只是习惯。';
    if (days >= 30) return '一个月，足够让一件事变成生活。';
    if (days >= 14) return '两周的连续，已经有了惯性。';
    if (days >= 7) return '一周不断，是个不错的开始。';
    return '连续几天，已经很好了。';
  }
}

/// 年报入口按钮（回顾页右上角用）
class YearReportButton extends StatelessWidget {
  final int? year;

  const YearReportButton({super.key, this.year});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pinkColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;

    return GestureDetector(
      onTap: () => YearlyReportScreen.open(context, year: year),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: pinkColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 14, color: pinkColor),
            const SizedBox(width: 5),
            Text(
              '我的年报',
              style: TextStyle(
                fontSize: 12,
                color: pinkColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
