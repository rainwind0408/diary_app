/// 写操作的字段白名单与上限 —— **纯 Dart**，可离线逐条断言。
///
/// ## 为什么是代码而不是提示词
///
/// 提示词能绕过，白名单绕不过。模型能写哪些字段、能写多长、能写到哪一天，
/// 必须由这里钉死。
library;

class DiaryWriteGuard {
  DiaryWriteGuard._();

  /// 允许模型写的字段。
  static const Set<String> writableFields = {
    'title',
    'content',
    'mood',
    'mood_intensity',
    'mood_note',
    'tags',
    'created_at',
  };

  /// 模型**绝不能**写的字段。
  ///
  /// - `id` —— 主键
  /// - `is_locked` / `pin_hash` —— 让模型能改锁定状态等于把 PIN 保护废掉
  /// - `word_count` —— 由 `WordCounter` 算，让模型填必然算错
  /// - `images` / `audios` / `stickers` —— **绝对定位**数据，
  ///   模型写一次就可能把整页排版毁掉
  /// - `updated_at` —— 由系统填
  static const Set<String> forbiddenFields = {
    'id',
    'is_locked',
    'pin_hash',
    'word_count',
    'images',
    'audios',
    'stickers',
    'updated_at',
  };

  /// 正文长度上限（字符）
  static const int maxContentLength = 20000;

  /// 标题长度上限
  static const int maxTitleLength = 100;

  /// 标签数量上限
  static const int maxTagCount = 10;

  /// 单个标签长度上限
  static const int maxTagLength = 20;

  /// `created_at` 最早可到「现在往前 2 年」。
  ///
  /// 用户说「帮我补写一篇上周三的」是合理需求；让模型写到 1970 年就是 bug。
  static const Duration maxPast = Duration(days: 365 * 2);

  /// `created_at` 最晚可到「现在往后 1 天」（容忍时区误差）
  static const Duration maxFuture = Duration(days: 1);

  // ─────────────────────────────────────────────
  // 逐字段校验（返回 null = 通过）
  // ─────────────────────────────────────────────

  static String? validateContent(String content) {
    if (content.trim().isEmpty) {
      return '正文不能为空';
    }
    if (content.length > maxContentLength) {
      return '正文太长了（${content.length} 字），上限 $maxContentLength 字。'
          '请拆成几篇，或让用户自己写。';
    }
    return null;
  }

  static String? validateTitle(String title) {
    if (title.length > maxTitleLength) {
      return '标题太长了（${title.length} 字），上限 $maxTitleLength 字。';
    }
    return null;
  }

  /// [tags] 是原始入参（类型未知），所以这里连类型一起校验
  static String? validateTags(Object? tags) {
    if (tags == null) return null;
    if (tags is! List) return 'tags 必须是字符串数组';
    if (tags.length > maxTagCount) {
      return '标签太多了（${tags.length} 个），上限 $maxTagCount 个。';
    }
    for (final tag in tags) {
      if (tag is! String) return 'tags 里必须都是字符串';
      if (tag.length > maxTagLength) {
        return '标签「${tag.length > 8 ? '${tag.substring(0, 8)}…' : tag}」'
            '太长了，单个标签上限 $maxTagLength 字。';
      }
    }
    return null;
  }

  /// `created_at` 的范围校验。
  ///
  /// [now] 由调用方传入（而不是内部取 `DateTime.now()`）——
  /// 这样这条规则可以在离线测试里逐条断言。
  static String? validateCreatedAt(DateTime at, {required DateTime now}) {
    if (at.isAfter(now.add(maxFuture))) {
      return 'created_at 不能是未来（最多允许往后 1 天）';
    }
    if (at.isBefore(now.subtract(maxPast))) {
      return 'created_at 太早了（最多允许往前 2 年）';
    }
    return null;
  }

  /// 校验整个入参 Map：先查禁止字段，再逐字段查类型与上限。
  ///
  /// 返回 null = 通过。返回字符串 = 给模型看的错误说明。
  ///
  /// 未在白名单里的**其它**字段一律忽略（模型偶尔会多塞一两个键，
  /// 为此整次调用失败不值当）；只有 [forbiddenFields] 里的才显式报错 ——
  /// 那是真的想越权，必须让它知道不行。
  static String? validateArgs(
    Map<String, dynamic> args, {
    required DateTime now,
  }) {
    for (final key in args.keys) {
      if (forbiddenFields.contains(key)) {
        return '字段「$key」不允许由 AI 修改。'
            '（可写字段：${writableFields.join('、')}）';
      }
    }

    final title = args['title'];
    if (title != null) {
      if (title is! String) return 'title 必须是字符串';
      final err = validateTitle(title);
      if (err != null) return err;
    }

    final content = args['content'];
    if (content != null) {
      if (content is! String) return 'content 必须是字符串';
      final err = validateContent(content);
      if (err != null) return err;
    }

    final mood = args['mood'];
    if (mood != null && mood is! String) return 'mood 必须是字符串';

    final moodNote = args['mood_note'];
    if (moodNote != null && moodNote is! String) return 'mood_note 必须是字符串';

    final intensity = args['mood_intensity'];
    if (intensity != null) {
      if (intensity is! int) return 'mood_intensity 必须是整数';
      if (intensity < 1 || intensity > 5) return 'mood_intensity 只能是 1~5';
    }

    final tagsErr = validateTags(args['tags']);
    if (tagsErr != null) return tagsErr;

    final rawCreatedAt = args['created_at'];
    if (rawCreatedAt != null) {
      if (rawCreatedAt is! String) return 'created_at 必须是字符串（YYYY-MM-DD HH:mm）';
      final parsed = parseFlexibleDate(rawCreatedAt);
      if (parsed == null) {
        return 'created_at 格式无法识别，请用 YYYY-MM-DD 或 YYYY-MM-DD HH:mm';
      }
      final err = validateCreatedAt(parsed, now: now);
      if (err != null) return err;
    }

    return null;
  }

  /// 宽松解析模型给的日期串。
  ///
  /// 模型常见的写法：`2026-10-04`、`2026-10-04 21:30`、`2026-10-04T21:30:00`、
  /// `2026/10/04`。全都接住，接不住返回 null 让上层报错。
  ///
  /// 纯函数（不取当前时间），可离线断言。
  static DateTime? parseFlexibleDate(String raw) {
    final s = raw.trim().replaceAll('/', '-');
    if (s.isEmpty) return null;

    // 只有日期：补 00:00
    final dateOnly = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
    if (dateOnly != null) {
      final y = int.parse(dateOnly.group(1)!);
      final m = int.parse(dateOnly.group(2)!);
      final d = int.parse(dateOnly.group(3)!);
      return _safeDate(y, m, d);
    }

    final withTime =
        RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?')
            .firstMatch(s);
    if (withTime != null) {
      final y = int.parse(withTime.group(1)!);
      final mo = int.parse(withTime.group(2)!);
      final d = int.parse(withTime.group(3)!);
      final h = int.parse(withTime.group(4)!);
      final mi = int.parse(withTime.group(5)!);
      final se = int.tryParse(withTime.group(6) ?? '0') ?? 0;
      if (h > 23 || mi > 59 || se > 59) return null;
      return _safeDate(y, mo, d, h, mi, se);
    }

    return null;
  }

  /// `DateTime(y, m, d)` 对非法日期会**静默进位**（2 月 31 日 → 3 月 3 日），
  /// 这里回读一遍确认没被改过，防止模型用 `2026-02-31` 蒙混过关。
  static DateTime? _safeDate(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
    int second = 0,
  ]) {
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    final dt = DateTime(year, month, day, hour, minute, second);
    if (dt.year != year || dt.month != month || dt.day != day) return null;
    return dt;
  }
}
