/// 日记洞察的**纯逻辑**：标签推荐、心情走势分桶、日期文案。
///
/// 抽出来的理由和 `OrbGeometry` / `DiaryWriteGuard` 一样：
/// 这些是「算错了肉眼也看不出来、但结果会悄悄失真」的地方。
/// 放在纯 Dart 里（不依赖 `dart:ui`）就能在纯 Dart VM 里逐条断言。
///
/// `DiaryMcpServer` 只负责取数据与组 JSON，**所有判定规则都在这里**。
library;

/// 一条标签推荐。
class TagSuggestion {
  /// 标签本身（统一小写 —— App 存标签时也是小写）
  final String tag;

  /// 库里是否已经用过这个标签
  final bool fromExisting;

  /// 用过多少次（[fromExisting] 为 false 时恒为 0）
  final int usedCount;

  /// 给模型看的推荐理由
  final String reason;

  const TagSuggestion({
    required this.tag,
    required this.fromExisting,
    required this.usedCount,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'from_existing': fromExisting,
        'used_count': usedCount,
        'reason': reason,
      };
}

/// 一个心情点（= 一篇日记）
class EmotionPoint {
  final DateTime at;
  final String mood;
  final int intensity;

  const EmotionPoint({
    required this.at,
    required this.mood,
    required this.intensity,
  });
}

/// 走势里的一个时间桶
class EmotionBucket {
  /// 桶起始日 `YYYY-MM-DD`
  final String start;
  final int count;
  final double avgIntensity;
  final Map<String, int> moods;

  const EmotionBucket({
    required this.start,
    required this.count,
    required this.avgIntensity,
    required this.moods,
  });

  Map<String, dynamic> toJson() => {
        'start': start,
        'count': count,
        'avg_intensity': avgIntensity,
        'moods': moods,
      };
}

/// 心情走势的整体结论
class EmotionTrend {
  final int entryCount;
  final double averageIntensity;
  final Map<String, int> moodCounts;
  final int bucketDays;
  final List<EmotionBucket> series;

  /// `up`（后半段强度更高）/ `down` / `flat` / `unknown`（数据太少）
  final String trend;

  /// 给模型看的趋势说明
  final String trendDetail;

  const EmotionTrend({
    required this.entryCount,
    required this.averageIntensity,
    required this.moodCounts,
    required this.bucketDays,
    required this.series,
    required this.trend,
    required this.trendDetail,
  });
}

class DiaryInsight {
  DiaryInsight._();

  /// 最多推荐几个标签。再多用户反而挑不出来。
  static const int maxSuggestions = 5;

  /// 趋势判定阈值：前后半段平均强度差多少才算「变了」。
  ///
  /// 1~5 的刻度上，差 0.5 大致是「有感」的最小量级。
  /// 定小了会把噪声当趋势，定大了永远报 flat。
  static const double trendThreshold = 0.5;

  static const List<String> weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

  /// `DateTime.weekday` 是 1=周一…7=周日
  static String weekdayName(int weekday) {
    if (weekday < 1 || weekday > 7) return '';
    return '星期${weekdayNames[weekday - 1]}';
  }

  static String two(int n) => n.toString().padLeft(2, '0');

  static String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

  /// 关键词 → 候选标签的兜底词典。
  ///
  /// 只在「正文里没写 #标签、也没命中已有标签池」时才用得上。
  /// 刻意保持小：标签应该长成用户自己的样子，不该被一张大词表带跑。
  static const Map<String, List<String>> tagKeywords = {
    '工作': ['加班', '开会', '项目', '上班', '同事', '老板', '客户', '汇报', '绩效', '离职'],
    '学习': ['考试', '复习', '看书', '读书', '课程', '论文', '作业', '笔记', '学习'],
    '运动': ['跑步', '健身', '游泳', '打球', '瑜伽', '骑车', '爬山', '散步', '运动'],
    '美食': ['吃了', '好吃', '做饭', '餐厅', '外卖', '火锅', '咖啡', '奶茶', '早餐', '午饭', '晚饭'],
    '旅行': ['旅行', '旅游', '出差', '机场', '高铁', '酒店', '景点'],
    '家人': ['妈妈', '爸爸', '父母', '家里', '奶奶', '爷爷', '孩子', '儿子', '女儿'],
    '朋友': ['朋友', '同学', '聚会', '约了'],
    '宠物': ['猫', '狗', '宠物', '喵'],
    '心情': ['开心', '难过', '焦虑', '平静', 'emo', '好累', '烦', '治愈', '感动'],
    '健康': ['生病', '感冒', '医院', '吃药', '体检', '失眠', '头疼'],
    '天气': ['下雨', '晴天', '阴天', '下雪', '降温', '台风'],
    '电影': ['电影', '电视剧', '追剧', '影院', '综艺'],
    '音乐': ['音乐', '演唱会', '耳机'],
    '游戏': ['游戏', '上分'],
    '购物': ['买了', '快递', '下单', '逛街'],
  };

  /// 从正文里抠出 `#标签` 的**唯一真相来源**。
  ///
  /// `App` 保存时（`DiaryWriteProvider.save`）与工具推荐标签时
  /// （`DiaryMcpServer._cleanTags`）都走这里 —— 规则不一致会导致
  /// 「推荐了但保存时又不算」这种最难查的错。
  ///
  /// ## ⚠️ 为什么必须显式带上 CJK 范围（2026-10-05 修）
  ///
  /// 原来写的是 `\B#\w+`。但 Dart 的 `\w` 等价于 `[A-Za-z0-9_]`，
  /// **不含任何中日韩字符** —— 于是 `今天#跑步` 一个标签都抽不出来，
  /// 中文用户写 `#标签` 等于白写。实测：
  ///
  /// | 输入 | 旧规则 | 现在 |
  /// |---|---|---|
  /// | `今天#跑步 很开心` | `[]` | `[跑步]` |
  /// | `#跑步` | `[]` | `[跑步]` |
  /// | `今天#run 了` | `[run]` | `[run]` |
  /// | `abc#def` | `[]` | `[]`（`\B` 挡住了，这是故意的） |
  ///
  /// `\B` 保留：它让 `abc#def`、`http://x#y` 这种「# 紧跟在词后面」的
  /// 情况不被误当成标签。
  ///
  /// 覆盖范围是 CJK 统一汉字基本区（`U+4E00–U+9FFF`），
  /// 不包含扩展 B 区的生僻字 —— 那已经超出「标签」的合理用途。
  static List<String> hashTagsIn(String content) =>
      RegExp(r'\B#([\w\u4e00-\u9fff]+)')
          .allMatches(content)
          .map((m) => m.group(1)!.toLowerCase())
          .toList();

  /// 推荐标签。
  ///
  /// 优先级（高 → 低）：
  /// 1. 正文里自己写的 `#标签` —— 用户的意思，最高优先
  /// 2. 命中**已有标签池** —— 复用比造新词好，统计才整齐
  /// 3. 关键词词典兜底
  ///
  /// [existingTags] 是「标签 → 使用次数」。调用方必须**先过滤掉锁定日记**
  /// （标签名本身就是内容）。
  static List<TagSuggestion> suggestTags({
    required String content,
    String title = '',
    required Map<String, int> existingTags,
  }) {
    final text = '$title\n$content'.toLowerCase();
    final picked = <TagSuggestion>[];
    final seen = <String>{};

    void add(String tag, String reason) {
      final key = tag.toLowerCase().trim();
      if (key.isEmpty || seen.contains(key)) return;
      seen.add(key);
      picked.add(TagSuggestion(
        tag: key,
        fromExisting: existingTags.containsKey(key),
        usedCount: existingTags[key] ?? 0,
        reason: reason,
      ));
    }

    for (final tag in hashTagsIn(content)) {
      add(tag, '正文里已经写了这个标签');
    }

    final hit = existingTags.entries
        .where((e) => e.key.length >= 2 && text.contains(e.key))
        .toList()
      ..sort((a, b) {
        // 用得多的排前面；次数相同按标签名稳定排序，
        // 否则同一篇正文每次推荐的顺序都会变
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    for (final e in hit) {
      add(e.key, '你以前用过 ${e.value} 次');
    }

    for (final rule in tagKeywords.entries) {
      if (picked.length >= maxSuggestions) break;
      if (rule.value.any(text.contains)) {
        add(rule.key, '正文里提到了相关的内容');
      }
    }

    return picked.take(maxSuggestions).toList();
  }

  /// 走势按多少天一个桶。
  ///
  /// 一年 365 个点会把上下文烧掉，所以按跨度自动放粗。
  /// 桶数上限约 31。
  static int bucketDaysFor(int days) {
    if (days <= 31) return 1;
    if (days <= 120) return 7;
    return 30;
  }

  /// 算心情走势。**纯函数** —— 时间范围由调用方传入，不在这里取 `now`。
  static EmotionTrend emotionTrend({
    required List<EmotionPoint> points,
    required DateTime start,
    required DateTime end,
    required int days,
  }) {
    if (points.isEmpty) {
      return const EmotionTrend(
        entryCount: 0,
        averageIntensity: 0,
        moodCounts: {},
        bucketDays: 1,
        series: [],
        trend: 'unknown',
        trendDetail: '这段时间没有写过日记，看不出心情走势。',
      );
    }

    final startDay = DateTime(start.year, start.month, start.day);
    final bucketDays = bucketDaysFor(days);

    final buckets = <String, Map<String, dynamic>>{};
    final moodCounts = <String, int>{};
    var intensitySum = 0;

    for (final p in points) {
      if (p.mood.isNotEmpty) {
        moodCounts[p.mood] = (moodCounts[p.mood] ?? 0) + 1;
      }
      intensitySum += p.intensity;

      // 桶按「距 startDay 多少天」对齐，保证同一篇日记永远落在同一个桶
      final offsetDays = p.at.difference(startDay).inDays;
      final index = offsetDays < 0 ? 0 : offsetDays ~/ bucketDays;
      final key = ymd(DateTime(
        startDay.year,
        startDay.month,
        startDay.day + index * bucketDays,
      ));

      final bucket = buckets.putIfAbsent(
        key,
        () => {
          'start': key,
          'count': 0,
          'sum': 0,
          'moods': <String, int>{},
        },
      );
      bucket['count'] = (bucket['count'] as int) + 1;
      bucket['sum'] = (bucket['sum'] as int) + p.intensity;
      if (p.mood.isNotEmpty) {
        final moods = bucket['moods'] as Map<String, int>;
        moods[p.mood] = (moods[p.mood] ?? 0) + 1;
      }
    }

    final series = buckets.values.map((b) {
      final count = b['count'] as int;
      return EmotionBucket(
        start: b['start'] as String,
        count: count,
        avgIntensity: _round2((b['sum'] as int) / count),
        moods: b['moods'] as Map<String, int>,
      );
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    // 前后半段对比
    final mid = startDay.add(Duration(days: days ~/ 2));
    final firstHalf = points.where((p) => p.at.isBefore(mid)).toList();
    final secondHalf = points.where((p) => !p.at.isBefore(mid)).toList();

    var trend = 'unknown';
    var detail = '前后半段至少各要有一篇日记才看得出趋势。';
    if (firstHalf.isNotEmpty && secondHalf.isNotEmpty) {
      final firstAvg =
          firstHalf.fold<int>(0, (s, p) => s + p.intensity) / firstHalf.length;
      final secondAvg =
          secondHalf.fold<int>(0, (s, p) => s + p.intensity) /
              secondHalf.length;
      final delta = secondAvg - firstAvg;
      if (delta >= trendThreshold) {
        trend = 'up';
      } else if (delta <= -trendThreshold) {
        trend = 'down';
      } else {
        trend = 'flat';
      }
      detail = '前半段平均 ${firstAvg.toStringAsFixed(1)} → '
          '后半段 ${secondAvg.toStringAsFixed(1)}（1~5，越高越强烈）';
    }

    return EmotionTrend(
      entryCount: points.length,
      averageIntensity: _round2(intensitySum / points.length),
      moodCounts: moodCounts,
      bucketDays: bucketDays,
      series: series,
      trend: trend,
      trendDetail: detail,
    );
  }

  static double _round2(double v) => double.parse(v.toStringAsFixed(2));
}
