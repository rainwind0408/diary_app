import 'dart:convert';
import '../../../data/repositories/diary_repository.dart';

class DiaryMcpServer {
  final DiaryRepository _repo;

  DiaryMcpServer(this._repo);

  /// 获取所有工具定义（传给 LLM API 的 tools 参数）
  List<Map<String, dynamic>> getToolDefinitions() => _toolDefinitions;

  /// 统一执行入口
  Future<String> execute(String toolName, Map<String, dynamic> arguments) async {
    final handler = _toolHandlers[toolName];
    if (handler == null) {
      return jsonEncode({'error': '未知工具: $toolName'});
    }
    try {
      return await handler(arguments);
    } catch (e) {
      return jsonEncode({'error': '工具执行失败: $e'});
    }
  }

  // ===== 工具注册表 =====

  late final Map<String, Future<String> Function(Map<String, dynamic>)> _toolHandlers = {
    'search_diaries': (args) => _searchDiaries(args['keyword'] as String),
    'get_diaries_by_date': (args) => _getDiariesByDate(
      args['start_date'] as String,
      args['end_date'] as String,
    ),
    'get_diary_by_id': (args) => _getDiaryById(args['diary_id'] as int),
    'get_diaries_by_mood': (args) => _getDiariesByMood(args['mood'] as String),
    'get_diaries_by_tag': (args) => _getDiariesByTag(args['tag'] as String),
    'get_diary_count': (_) => _getDiaryCount(),
    'get_mood_stats': (_) => _getMoodStats(),
    'get_tag_stats': (_) => _getTagStats(),
    'get_writing_streak': (_) => _getWritingStreak(),
    'get_time_distribution': (_) => _getTimeDistribution(),
    'get_word_count_trend': (args) => _getWordCountTrend(
      (args['months'] as int?) ?? 6,
    ),
  };

  // ===== 工具 Schema 定义 =====

  static const _toolDefinitions = [
    // === 内容查询 ===
    {
      'type': 'function',
      'function': {
        'name': 'search_diaries',
        'description': '按关键词搜索日记标题和正文，返回匹配的日记摘要列表（最多10条）。适用于用户问"有没有关于XX的日记"。',
        'parameters': {
          'type': 'object',
          'properties': {
            'keyword': {
              'type': 'string',
              'description': '搜索关键词',
            },
          },
          'required': ['keyword'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_diaries_by_date',
        'description': '获取指定日期范围内的日记列表。适用于用户问"上周写了什么"、"6月的日记"等。',
        'parameters': {
          'type': 'object',
          'properties': {
            'start_date': {
              'type': 'string',
              'description': '开始日期，格式 YYYY-MM-DD',
            },
            'end_date': {
              'type': 'string',
              'description': '结束日期，格式 YYYY-MM-DD',
            },
          },
          'required': ['start_date', 'end_date'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_diary_by_id',
        'description': '获取单篇日记的完整内容。适用于用户想查看某篇具体日记。',
        'parameters': {
          'type': 'object',
          'properties': {
            'diary_id': {
              'type': 'integer',
              'description': '日记 ID',
            },
          },
          'required': ['diary_id'],
        },
      },
    },

    // === 筛选分析 ===
    {
      'type': 'function',
      'function': {
        'name': 'get_diaries_by_mood',
        'description': '按心情 emoji 筛选日记。适用于用户问"有没有开心的日记"、"找找难过的日子"。',
        'parameters': {
          'type': 'object',
          'properties': {
            'mood': {
              'type': 'string',
              'description': '心情 emoji，如 😊 😢 😡 😰 等',
            },
          },
          'required': ['mood'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_diaries_by_tag',
        'description': '按标签筛选日记。适用于用户问"旅行相关的日记"、"看看读书笔记"。',
        'parameters': {
          'type': 'object',
          'properties': {
            'tag': {
              'type': 'string',
              'description': '标签名称',
            },
          },
          'required': ['tag'],
        },
      },
    },

    // === 统计概览 ===
    {
      'type': 'function',
      'function': {
        'name': 'get_diary_count',
        'description': '获取日记总数和本月统计数据（篇数和总字数）。适用于用户问"我写了多少篇日记"。',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_mood_stats',
        'description': '获取心情分布统计，返回各心情的出现次数。适用于用户问"我的心情怎么样"、"哪种心情最多"。',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_tag_stats',
        'description': '获取标签使用统计，返回各标签的使用次数（按使用频率降序）。适用于用户问"我最常写什么"。',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },

    // === 趋势分析 ===
    {
      'type': 'function',
      'function': {
        'name': 'get_writing_streak',
        'description': '获取当前连续写作天数。适用于用户问"我连续写了多久"。',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_time_distribution',
        'description': '获取写作时间分布（早晨/下午/晚上/深夜各写了多少篇）。适用于用户问"我一般什么时候写日记"。',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_word_count_trend',
        'description': '获取最近 N 个月的月均字数趋势。适用于用户问"我最近写得多了还是少了"。',
        'parameters': {
          'type': 'object',
          'properties': {
            'months': {
              'type': 'integer',
              'description': '统计最近几个月，默认 6',
            },
          },
        },
      },
    },
  ];

  // ===== 具体工具实现 =====

  Future<String> _searchDiaries(String keyword) async {
    final entries = await _repo.searchEntries(keyword);
    if (entries.isEmpty) {
      return jsonEncode({'results': [], 'message': '未找到匹配的日记'});
    }
    final results = entries.take(10).map((e) => {
      'id': e.id,
      'title': e.title,
      'content': e.content.length > 200
          ? '${e.content.substring(0, 200)}...'
          : e.content,
      'mood': e.mood,
      'tags': e.tags,
      'created_at': e.createdAt.toIso8601String(),
    }).toList();
    return jsonEncode({'results': results, 'total': entries.length});
  }

  Future<String> _getDiariesByDate(String startDate, String endDate) async {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate).add(const Duration(days: 1));
    final allEntries = await _repo.getAllEntries();
    final filtered = allEntries.where((e) =>
      !e.createdAt.isBefore(start) && e.createdAt.isBefore(end)
    ).toList();
    if (filtered.isEmpty) {
      return jsonEncode({'results': [], 'message': '该日期范围内没有日记'});
    }
    final results = filtered.map((e) => {
      'id': e.id,
      'title': e.title,
      'content': e.content.length > 200
          ? '${e.content.substring(0, 200)}...'
          : e.content,
      'mood': e.mood,
      'tags': e.tags,
      'created_at': e.createdAt.toIso8601String(),
    }).toList();
    return jsonEncode({'results': results, 'total': filtered.length});
  }

  Future<String> _getDiaryById(int id) async {
    final entry = await _repo.getEntryById(id);
    if (entry == null) {
      return jsonEncode({'error': '未找到 ID 为 $id 的日记'});
    }
    return jsonEncode({
      'id': entry.id,
      'title': entry.title,
      'content': entry.content,
      'mood': entry.mood,
      'mood_intensity': entry.moodIntensity,
      'mood_note': entry.moodNote,
      'tags': entry.tags,
      'word_count': entry.wordCount,
      'image_count': entry.images.length,
      'audio_count': entry.audios.length,
      'created_at': entry.createdAt.toIso8601String(),
      'updated_at': entry.updatedAt.toIso8601String(),
    });
  }

  Future<String> _getDiariesByMood(String mood) async {
    final allEntries = await _repo.getAllEntries();
    final filtered = allEntries.where((e) => e.mood == mood).toList();
    if (filtered.isEmpty) {
      return jsonEncode({'results': [], 'message': '没有找到心情为 $mood 的日记'});
    }
    final results = filtered.take(20).map((e) => {
      'id': e.id,
      'title': e.title,
      'content': e.content.length > 150
          ? '${e.content.substring(0, 150)}...'
          : e.content,
      'mood': e.mood,
      'tags': e.tags,
      'created_at': e.createdAt.toIso8601String(),
    }).toList();
    return jsonEncode({'results': results, 'total': filtered.length});
  }

  Future<String> _getDiariesByTag(String tag) async {
    final entries = await _repo.getEntriesByTag(tag);
    if (entries.isEmpty) {
      return jsonEncode({'results': [], 'message': '没有标签为「$tag」的日记'});
    }
    final results = entries.take(20).map((e) => {
      'id': e.id,
      'title': e.title,
      'content': e.content.length > 150
          ? '${e.content.substring(0, 150)}...'
          : e.content,
      'mood': e.mood,
      'tags': e.tags,
      'created_at': e.createdAt.toIso8601String(),
    }).toList();
    return jsonEncode({'results': results, 'total': entries.length});
  }

  Future<String> _getDiaryCount() async {
    final allEntries = await _repo.getAllEntries();
    final now = DateTime.now();
    final monthlyStats = await _repo.getMonthlyStats(now);
    return jsonEncode({
      'total_count': allEntries.length,
      'this_month': monthlyStats,
    });
  }

  Future<String> _getMoodStats() async {
    final stats = await _repo.getMoodStats();
    if (stats.isEmpty) {
      return jsonEncode({'moods': {}, 'message': '暂无心情数据'});
    }
    return jsonEncode({'moods': stats});
  }

  Future<String> _getTagStats() async {
    final stats = await _repo.getAllTags();
    if (stats.isEmpty) {
      return jsonEncode({'tags': {}, 'message': '暂无标签数据'});
    }
    final sorted = Map.fromEntries(
      stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
    );
    return jsonEncode({'tags': sorted});
  }

  Future<String> _getWritingStreak() async {
    final streak = await _repo.getStreakDays();
    return jsonEncode({'streak_days': streak});
  }

  Future<String> _getTimeDistribution() async {
    final dist = await _repo.getTimeDistribution();
    return jsonEncode({'distribution': dist});
  }

  Future<String> _getWordCountTrend(int months) async {
    final allEntries = await _repo.getAllEntries();
    final now = DateTime.now();
    final trend = <Map<String, dynamic>>[];

    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      final monthEntries = allEntries.where((e) =>
        e.createdAt.isAfter(month.subtract(const Duration(days: 1))) &&
        e.createdAt.isBefore(nextMonth)
      ).toList();

      final totalWords = monthEntries.fold<int>(0, (sum, e) => sum + e.wordCount);
      final avgWords = monthEntries.isEmpty ? 0 : (totalWords / monthEntries.length).round();

      trend.add({
        'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
        'count': monthEntries.length,
        'total_words': totalWords,
        'avg_words': avgWords,
      });
    }

    return jsonEncode({'trend': trend, 'months': months});
  }
}
