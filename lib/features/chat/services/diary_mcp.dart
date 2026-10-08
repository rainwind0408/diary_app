import 'dart:convert';

import '../../../core/constants/mood_constants.dart';
import '../../../core/events/diary_change_bus.dart';
import '../../../core/utils/word_counter.dart';
import '../../../data/models/diary_entry.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../diary_write/services/audio_service.dart';
import '../../diary_write/services/image_service.dart';
import '../models/ai_provider.dart';
import '../models/diary_insight.dart';
import '../models/diary_write_guard.dart';
import '../models/media_marker.dart';
import '../models/tool_confirmation.dart';
import 'ai_config_store.dart';
import 'diary_media_service.dart';
import 'image_gen_service.dart';
import 'tool_confirmation_gate.dart';

class DiaryMcpServer {
  final DiaryRepository _repo;
  final ImageGenService _imageGen;

  DiaryMcpServer(this._repo, {ImageGenService? imageGen})
      : _imageGen = imageGen ?? ImageGenService();

  /// 生图工具名（供调用方识别工具结果里的图片标记）
  static const String imageToolName = 'generate_image';

  /// 媒体工具名。调用方（`ChatProvider`）靠这三个名字决定要不要做额外处理。
  static const String mediaListToolName = 'get_diary_media';
  static const String viewImageToolName = 'view_diary_image';
  static const String transcribeAudioToolName = 'transcribe_diary_audio';

  /// 写工具名。**这些工具在执行前必须过 [ToolConfirmationGate]。**
  static const String createDiaryToolName = 'create_diary';
  static const String appendDiaryToolName = 'append_to_diary';
  static const String updateDiaryToolName = 'update_diary';
  static const String deleteDiaryToolName = 'delete_diary';

  /// 时间与回忆类工具名（P5-5）
  static const String currentTimeToolName = 'get_current_time';
  static const String onThisDayToolName = 'get_on_this_day';
  static const String recentDiariesToolName = 'get_recent_diaries';
  static const String emotionTrendToolName = 'get_emotion_trend';
  static const String suggestTagsToolName = 'suggest_tags';

  static const Set<String> _writeToolNames = {
    createDiaryToolName,
    appendDiaryToolName,
    updateDiaryToolName,
    deleteDiaryToolName,
  };

  /// 新建日记时，「60 秒内内容完全一样就不重复创建」的窗口。
  ///
  /// 真实风险：模型调了 `create_diary`，网络抖动导致响应丢失，模型重试 ——
  /// 于是建出两篇一模一样的日记。这是最便宜也最有效的兜底。
  static const Duration duplicateWindow = Duration(seconds: 60);

  /// 获取所有工具定义（传给 LLM API 的 tools 参数）。
  ///
  /// 没配生图厂商时**不暴露** `generate_image` —— 否则模型可能一本正经地
  /// 调用它、然后拿到一个错误，用户看到的就是「AI 说它画了但其实什么都没画」。
  List<Map<String, dynamic>> getToolDefinitions() {
    if (_imageGenAvailable) return _toolDefinitions;
    return _toolDefinitions
        .where((t) => (t['function'] as Map)['name'] != imageToolName)
        .toList();
  }

  bool get _imageGenAvailable {
    final provider =
        AiConfigStore.cached?.activeProvider(AiCapability.image);
    return provider != null && provider.hasApiKey;
  }

  /// 统一执行入口
  Future<String> execute(String toolName, Map<String, dynamic> arguments) async {
    final handler = _toolHandlers[toolName];
    if (handler == null) {
      return jsonEncode({'error': '未知工具: $toolName'});
    }

    // 先把「本该是整数」的参数归一化。
    // 有些网关会把 JSON 里的 `7` 序列化成 `7.0`，于是每个 handler 里的
    // `args['x'] as int` 都会抛。集中在这里修一次，比散在十来个地方强。
    final args = _normalizeIntArgs(arguments);

    // ★ 写操作先过确认门：把「要写什么」算成人类可读的摘要给用户看。
    //   这一步是**只读**的（_preview 不碰数据库），用户点了确认才真写。
    if (_writeToolNames.contains(toolName)) {
      final preview = await _preview(toolName, args);
      if (preview.error != null) {
        return jsonEncode({'error': preview.error});
      }
      final request = preview.request;
      if (request == null) {
        // 理论上到不了这里（error 与 request 必有一个非空）。
        // 真到了也绝不能带着 null 往下走 —— 那会变成一次「点了确认才崩」。
        return jsonEncode({'error': '这次操作无法生成确认信息，已取消'});
      }
      final approved = await ToolConfirmationGate.request(request);
      if (!approved) {
        // ★ 返回形状很关键：不能给 `{"error": ...}` ——
        //   模型会把它理解成「失败了，再试一次」，于是反复弹确认卡片。
        //   必须显式告诉它「是用户主动取消的，不要重试」。
        return jsonEncode({
          'cancelled': true,
          'message': '用户取消了这次操作，没有做任何改动。'
              '不要重试，简单回应一句「好的，没有改动」即可。',
        });
      }
    }

    try {
      return await handler(args);
    } catch (e) {
      return jsonEncode({'error': '工具执行失败: $e'});
    }
  }

  /// 会被 `as int` 直接解引用的参数名
  static const Set<String> _intArgKeys = {
    'diary_id',
    'index',
    'months',
    'mood_intensity',
  };

  /// 把 `7.0` 这种「整数被序列化成了浮点」还原成 `7`。
  ///
  /// 只动 `double` 且值本身是整数的；`7.5` 原样留着，让校验层去报错。
  static Map<String, dynamic> _normalizeIntArgs(Map<String, dynamic> args) {
    var changed = false;
    final out = Map<String, dynamic>.from(args);
    for (final key in _intArgKeys) {
      final value = out[key];
      if (value is double && value == value.roundToDouble()) {
        out[key] = value.toInt();
        changed = true;
      }
    }
    return changed ? out : args;
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
    mediaListToolName: (args) => _getDiaryMedia(args['diary_id'] as int),
    viewImageToolName: (args) => _viewDiaryImage(
      args['diary_id'] as int,
      args['index'] as int,
    ),
    transcribeAudioToolName: (args) => _transcribeDiaryAudio(
      args['diary_id'] as int,
      args['index'] as int,
      (args['confirm_long'] as bool?) ?? false,
    ),

    // === 时间与回忆（P5-5）===
    currentTimeToolName: (_) => _getCurrentTime(),
    onThisDayToolName: (args) => _getOnThisDay(
      (args['years'] as int?) ?? 3,
      args['date'] as String?,
    ),
    recentDiariesToolName: (args) => _getRecentDiaries(
      (args['limit'] as int?) ?? 5,
    ),
    emotionTrendToolName: (args) => _getEmotionTrend(
      (args['days'] as int?) ?? 30,
    ),
    suggestTagsToolName: (args) => _suggestTags(
      args['content'] as String,
      title: args['title'] as String?,
    ),

    // === 写操作（都要过确认门，见 execute）===
    createDiaryToolName: (args) => _createDiary(args),
    appendDiaryToolName: (args) => _appendToDiary(
      args['diary_id'] as int,
      args['content'] as String,
    ),
    updateDiaryToolName: (args) => _updateDiary(args),
    deleteDiaryToolName: (args) => _deleteDiary(args['diary_id'] as int),

    imageToolName: (args) => _generateImage(
      args['prompt'] as String?,
      referencePath: args['reference_path'] as String?,
    ),
  };

  // ===== 隐私边界（硬编码，不靠提示词） =====

  /// 读一篇日记，并把「不存在」与「被锁定」分开报。
  ///
  /// 锁定日记一律不可读 —— 这条规则必须落在代码里。写进提示词是没用的：
  /// 模型可以绕过提示词，工具层却绕不过。
  Future<({DiaryEntry? entry, String? error})> _readable(int id) async {
    final entry = await _repo.getEntryById(id);
    if (entry == null) {
      return (entry: null, error: '未找到 ID 为 $id 的日记');
    }
    if (entry.isLocked) {
      return (
        entry: null,
        error: '这篇日记已被锁定，我无法读取它的内容。'
            '请先在日记列表里解锁，或换一篇没锁的。',
      );
    }
    return (entry: entry, error: null);
  }

  /// 剔掉锁定日记。
  ///
  /// ⚠️ 这是**补上的现存缺陷**：在 P5-3 之前，`search_diaries` 会把锁定日记的
  /// 标题和正文片段直接交给模型 —— 用户以为锁上就没人能看了。
  ///
  /// 只用在**会返回日记内容**的工具上（搜索 / 按日期 / 按心情 / 按标签）。
  /// 纯计数类统计（总数、连续天数、时间分布、字数趋势）**刻意不过滤**：
  /// 它们不吐出任何内容，而且必须与 App 自己的「统计 / 成就 / 回顾」页
  /// 保持一致 —— 否则会出现「AI 说 42 篇、成就页说 45 篇」这种更让人困惑的事。
  static List<DiaryEntry> _visible(Iterable<DiaryEntry> entries) =>
      entries.where((e) => !e.isLocked).toList();

  /// 把异常转成能直接给模型看的一句话（去掉 Dart 自动加的 `Exception: `）
  static String _plain(Object error) {
    final raw = error.toString();
    const prefix = 'Exception: ';
    return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
  }

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

    // === 日记里的图片与录音 ===
    {
      'type': 'function',
      'function': {
        'name': mediaListToolName,
        'description': '列出某篇日记里的图片和录音清单（序号、文件名、大小、时长），'
            '但**不含内容**。只在用户问「这篇日记有哪些图 / 录音」时用。'
            '要让模型真的看到图片，用 view_diary_image；'
            '要读录音里说了什么，用 transcribe_diary_audio。',
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
    {
      'type': 'function',
      'function': {
        'name': viewImageToolName,
        'description': '查看某篇日记里的第 N 张图片（N 从 1 开始）。'
            '当用户问「我上次发的那张照片是什么样」「看看这篇日记的配图」时调用。'
            '调用后图片会真的出现在你的视野里，再据此回答。'
            '**一次只能看一张**，需要多张就分多次调用。',
        'parameters': {
          'type': 'object',
          'properties': {
            'diary_id': {
              'type': 'integer',
              'description': '日记 ID',
            },
            'index': {
              'type': 'integer',
              'description': '第几张图片，从 1 开始',
            },
          },
          'required': ['diary_id', 'index'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': transcribeAudioToolName,
        'description': '把某篇日记里的第 N 段录音转成文字（N 从 1 开始），'
            '然后基于转写文本回答用户。'
            '录音超过 5 分钟时本工具会先返回 needs_confirmation，'
            '这时**必须先问用户要不要转写**，用户同意后再带 confirm_long=true 调用一次。',
        'parameters': {
          'type': 'object',
          'properties': {
            'diary_id': {
              'type': 'integer',
              'description': '日记 ID',
            },
            'index': {
              'type': 'integer',
              'description': '第几段录音，从 1 开始',
            },
            'confirm_long': {
              'type': 'boolean',
              'description': '长录音时用户是否已确认要转写；短录音不需要传',
            },
          },
          'required': ['diary_id', 'index'],
        },
      },
    },

    // === 写日记（每次都要用户确认）===
    {
      'type': 'function',
      'function': {
        'name': createDiaryToolName,
        'description': '新建一篇日记。用户说「帮我记一下…」「写一篇今天的日记」时用。'
            '标题可以留空，系统会按正文生成。'
            '⚠️ 如果用户说的是「在今天的日记里加一句」，请改用 append_to_diary —— '
            '那更常见，也不会产生一堆零碎的新记录。',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': '标题，可留空'},
            'content': {'type': 'string', 'description': '正文，支持换行'},
            'mood': {
              'type': 'string',
              'description': '心情 emoji，如 😊 😢 😌，可留空',
            },
            'mood_note': {'type': 'string', 'description': '心情备注，可留空'},
            'mood_intensity': {
              'type': 'integer',
              'description': '心情强度 1~5，默认 3',
            },
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': '标签，最多 10 个',
            },
            'created_at': {
              'type': 'string',
              'description': '日记时间，格式 YYYY-MM-DD HH:mm；'
                  '省略则用当前时间。补写过去的日记时才填。',
            },
          },
          'required': ['content'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': appendDiaryToolName,
        'description': '在某篇已有日记的正文末尾追加一段内容，**保留原文**。'
            '用户说「在今天的日记里加一句…」「补充一下」时优先用这个，'
            '不要为了一句补充就新建一篇日记。',
        'parameters': {
          'type': 'object',
          'properties': {
            'diary_id': {'type': 'integer', 'description': '日记 ID'},
            'content': {'type': 'string', 'description': '要追加的内容'},
          },
          'required': ['diary_id', 'content'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': updateDiaryToolName,
        'description': '修改某篇日记的指定字段。**只传要改的字段**，其余保持不变。'
            '用户说「把标题改成…」「那篇日记的心情改成开心」时用。',
        'parameters': {
          'type': 'object',
          'properties': {
            'diary_id': {'type': 'integer', 'description': '日记 ID'},
            'title': {'type': 'string', 'description': '新标题'},
            'content': {
              'type': 'string',
              'description': '新的完整正文（会**整体替换**旧正文，请谨慎）',
            },
            'mood': {'type': 'string', 'description': '新的心情 emoji'},
            'mood_note': {'type': 'string', 'description': '新的心情备注'},
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': '新的标签列表（会整体替换旧标签）',
            },
          },
          'required': ['diary_id'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': deleteDiaryToolName,
        'description': '删除一篇日记。这是**不可恢复**的操作，'
            '只应在用户明确说「删掉」「删除那篇」时调用。'
            '不确定是哪一篇就先搜索、把候选念给用户听，'
            '**不要自行推测 ID**。',
        'parameters': {
          'type': 'object',
          'properties': {
            'diary_id': {'type': 'integer', 'description': '日记 ID'},
          },
          'required': ['diary_id'],
        },
      },
    },

    // === 时间与回忆（P5-5）===
    {
      'type': 'function',
      'function': {
        'name': currentTimeToolName,
        'description': '获取当前日期、时间和星期。'
            '⚠️ 只要问题里出现「今天 / 昨天 / 这周 / 上周 / 最近 / 上个月 / 去年」'
            '这类相对时间，**必须先调这个工具**再算日期区间 —— '
            '你的训练数据里的日期是旧的，直接猜一定会算错。',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': onThisDayToolName,
        'description': '「去年的今天」—— 查往年的同月同日写了什么日记。'
            '用户说「去年的今天」「前年的今天我在干嘛」「同日回忆」时用。'
            '这是日记 App 最有情绪价值的查询，值得主动提一句。',
        'parameters': {
          'type': 'object',
          'properties': {
            'years': {
              'type': 'integer',
              'description': '往前回溯几年，默认 3，最多 10',
            },
            'date': {
              'type': 'string',
              'description': '要查的日期 YYYY-MM-DD；省略则用今天',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': recentDiariesToolName,
        'description': '按时间倒序取最近写的几篇日记。'
            '用户说「我最近写了什么」「看看最新那几篇」时用。'
            '注意这是**全局最近**；如果要看某一天的，用 get_diaries_by_date。',
        'parameters': {
          'type': 'object',
          'properties': {
            'limit': {
              'type': 'integer',
              'description': '取几篇，默认 5，最多 20',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': emotionTrendToolName,
        'description': '看一段时间里的心情走势：每天的心情 emoji 与强度、'
            '心情分布、以及前后半段的对比（变好 / 变差 / 持平）。'
            '用户问「我最近心情怎么样」「这一个月情绪有什么变化」时用。'
            '**只看数字看不出情绪时不要用它替代阅读原文** —— '
            '它给的是趋势，不是内容。',
        'parameters': {
          'type': 'object',
          'properties': {
            'days': {
              'type': 'integer',
              'description': '回溯多少天，默认 30，最多 365',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': suggestTagsToolName,
        'description': '根据一段正文推荐 3~5 个标签，并标出哪些是**库里已经用过的**'
            '（优先复用已有标签，别造新词）。'
            '用户说「帮我打标签」「这篇该加什么标签」时用。'
            '⚠️ 只推荐，**不要擅自把标签写进日记** —— 要写请用 update_diary。',
        'parameters': {
          'type': 'object',
          'properties': {
            'content': {'type': 'string', 'description': '日记正文'},
            'title': {'type': 'string', 'description': '标题，可留空'},
          },
          'required': ['content'],
        },
      },
    },

    // === 生图 ===
    {
      'type': 'function',
      'function': {
        'name': imageToolName,
        'description': '根据文字描述生成一张图片并显示在对话里。'
            '仅当用户**明确要求画图 / 生成图片 / 来一张…**时调用，'
            '不要因为回答里提到「画面」就擅自调用。'
            'prompt 请写得具体：主体、风格、氛围、配色。'
            '⚠️ 如果这次调用的目的是「照着某张图改」，而参考图不可用或图生图失败，'
            '**必须如实告诉用户参考没成功**，不要偷偷改成纯文字生成、'
            '然后宣称「照着你那张画的」—— 那样用户会以为改的是自己的照片。',
        'parameters': {
          'type': 'object',
          'properties': {
            'prompt': {
              'type': 'string',
              'description': '图片描述，越具体越好',
            },
            'reference': {
              'type': 'string',
              'enum': ['recent_user_image', 'none'],
              'description': '要参考的图片。用户说「照着这张」「把我发的照片画成…」'
                  '「基于我发的图」时填 recent_user_image —— '
                  '系统会自动取对话里最近一张用户发的图片做图生图；'
                  '纯文字生成填 none。',
            },
            'as_cover': {
              'type': 'boolean',
              'description': '是否把这张图同时放到首页顶部的封面位。'
                  '**仅在用户明确说「当封面 / 放到首页 / 首页那张图」时才传 true**；'
                  '其余情况一律不传（默认 false）—— 否则会莫名其妙改掉用户首页。'
                  '注意：封面位上的图是临时的，用户重启应用后就会消失。',
            },
          },
          'required': ['prompt'],
        },
      },
    },
  ];

  // ===== 具体工具实现 =====

  Future<String> _searchDiaries(String keyword) async {
    // 锁定日记不参与搜索 —— 见 [_visible]
    final entries = _visible(await _repo.searchEntries(keyword));
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
    final allEntries = _visible(await _repo.getAllEntries());
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
    final found = await _readable(id);
    if (found.entry == null) {
      return jsonEncode({'error': found.error});
    }
    final entry = found.entry!;
    return jsonEncode({
      'id': entry.id,
      'title': entry.title,
      'content': entry.content,
      'mood': entry.mood,
      'mood_intensity': entry.moodIntensity,
      'mood_note': entry.moodNote,
      'tags': entry.tags,
      'word_count': entry.wordCount,
      // ⚠️ 只给数量、不给内容。以前这里叫 image_count / audio_count，
      // 模型看到数字会以为它已经知道图片里是什么了，于是直接编内容。
      // 改成一句「要看得调哪个工具」的提示，把它推去真正取一次。
      'media_hint': _mediaHint(entry),
      'created_at': entry.createdAt.toIso8601String(),
      'updated_at': entry.updatedAt.toIso8601String(),
    });
  }

  /// 描述一篇日记里的媒体**数量**与**下一步该调什么工具**。
  ///
  /// 刻意不做文件系统检查（这里只读数据库里的计数）——
  /// `get_diary_by_id` 是高频工具，不该为一句提示去 stat 每个文件。
  /// 真实可读数量由 `get_diary_media` 给出。
  static String _mediaHint(DiaryEntry entry) {
    final images = entry.images.length;
    final audios = entry.audios.length;
    if (images == 0 && audios == 0) {
      return '这篇日记没有图片或录音。';
    }
    final parts = <String>[];
    if (images > 0) parts.add('$images 张图片');
    if (audios > 0) parts.add('$audios 段录音');
    return '这篇日记有${parts.join('、')}，但这里只有数量、看不到内容。'
        '要用 view_diary_image 看图片、用 transcribe_diary_audio 读录音，'
        '或先用 get_diary_media 拿一份清单。';
  }

  Future<String> _getDiariesByMood(String mood) async {
    final allEntries = _visible(await _repo.getAllEntries());
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
    final entries = _visible(await _repo.getEntriesByTag(tag));
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

  /// 心情分布。
  ///
  /// ⚠️ 走 [_visible] 而不是 `_repo.getMoodStats()` —— **心情 emoji 是内容派生的**，
  /// 锁定日记不该通过它泄露出去。纯数字统计（总数 / 连续天数 / 时间分布 /
  /// 字数趋势）**刻意不过滤**：它们不吐出任何文本，而且必须与 App 自己的
  /// 「统计 / 成就 / 回顾」页保持一致，否则会出现「AI 说 42 篇、成就页说 45 篇」。
  Future<String> _getMoodStats() async {
    final counts = <String, int>{};
    for (final entry in _visible(await _repo.getAllEntries())) {
      if (entry.mood.isEmpty) continue;
      counts[entry.mood] = (counts[entry.mood] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return jsonEncode({'moods': {}, 'message': '暂无心情数据'});
    }
    return jsonEncode({'moods': counts});
  }

  /// 标签统计。理由同 [_getMoodStats] —— **标签名本身就是内容**
  /// （有人会写「离婚」「体检报告」这种标签）。
  Future<String> _getTagStats() async {
    final counts = <String, int>{};
    for (final entry in _visible(await _repo.getAllEntries())) {
      for (final tag in entry.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) {
      return jsonEncode({'tags': {}, 'message': '暂无标签数据'});
    }
    final sorted = Map.fromEntries(
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
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

  // ===== 时间与回忆（P5-5）=====

  /// 截断长文本给工具返回用。工具结果会原样进模型上下文，不截会烧 token。
  static String _truncate(String text, int max) =>
      text.length > max ? '${text.substring(0, max)}...' : text;

  /// 当前日期 / 时间 / 星期。
  ///
  /// **这是刚需，不是锦上添花。** 在它之前，模型没有任何办法知道「今天几号」，
  /// 只能拿训练数据里的日期猜 —— 「上周写了什么」这类问题**必然算错区间**。
  Future<String> _getCurrentTime() async {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final abs = offset.abs();
    final sign = offset.isNegative ? '-' : '+';

    return jsonEncode({
      'date': DiaryInsight.ymd(now),
      'time': '${DiaryInsight.two(now.hour)}:${DiaryInsight.two(now.minute)}',
      'weekday': DiaryInsight.weekdayName(now.weekday),
      'iso': now.toIso8601String(),
      'utc_offset':
          '$sign${DiaryInsight.two(abs.inHours)}:${DiaryInsight.two(abs.inMinutes % 60)}',
      'yesterday': DiaryInsight.ymd(now.subtract(const Duration(days: 1))),
      'tomorrow': DiaryInsight.ymd(now.add(const Duration(days: 1))),
      'hint': '算「今天 / 昨天 / 这周 / 上周 / 上个月 / 最近 N 天」的区间时，'
          '一律以这里的时间为基准 —— 不要用训练数据里的日期。',
    });
  }

  /// 「去年的今天」—— 查往年同月同日的日记。
  ///
  /// 日记类 App 最有情绪价值的查询，实现却几乎零成本。
  Future<String> _getOnThisDay(int years, String? date) async {
    final span = years.clamp(1, 10);

    DateTime target;
    final raw = (date ?? '').trim();
    if (raw.isNotEmpty) {
      final parsed = DiaryWriteGuard.parseFlexibleDate(raw);
      if (parsed == null) {
        return jsonEncode({'error': 'date 格式无法识别，请用 YYYY-MM-DD'});
      }
      target = parsed;
    } else {
      target = DateTime.now();
    }

    final results = <Map<String, dynamic>>[];
    for (final entry in _visible(await _repo.getAllEntries())) {
      final at = entry.createdAt;
      if (at.month != target.month || at.day != target.day) continue;
      final yearsAgo = target.year - at.year;
      if (yearsAgo < 1 || yearsAgo > span) continue;
      results.add({
        'id': entry.id,
        'years_ago': yearsAgo,
        'year': at.year,
        'title': entry.title,
        'content': _truncate(entry.content, 300),
        'mood': entry.mood,
        'tags': entry.tags,
        if (entry.images.isNotEmpty || entry.audios.isNotEmpty)
          'media': {
            'images': entry.images.length,
            'audios': entry.audios.length,
          },
      });
    }
    results.sort(
      (a, b) => (a['years_ago'] as int).compareTo(b['years_ago'] as int),
    );

    return jsonEncode({
      'date': DiaryInsight.ymd(target),
      'searched_years': span,
      'results': results,
      'total': results.length,
      if (results.isEmpty) 'message': '往年这一天没有写过日记。',
    });
  }

  /// 按时间倒序取最近写的几篇。
  Future<String> _getRecentDiaries(int limit) async {
    final n = limit.clamp(1, 20);
    final all = _visible(await _repo.getAllEntries())
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final results = all.take(n).map((e) => {
          'id': e.id,
          'title': e.title,
          'content': _truncate(e.content, 200),
          'mood': e.mood,
          'tags': e.tags,
          'word_count': e.wordCount,
          'created_at': e.createdAt.toIso8601String(),
          'media': {
            'images': e.images.length,
            'audios': e.audios.length,
          },
        }).toList();

    return jsonEncode({
      'results': results,
      'total': results.length,
      'has_more': all.length > n,
    });
  }

  /// 心情走势。
  ///
  /// ⚠️ 走 [_visible] —— **心情 emoji 是内容派生的**，锁定日记不该从这里漏出去。
  /// 分桶与趋势判定在纯 Dart 的 [DiaryInsight.emotionTrend] 里（可离线断言）。
  Future<String> _getEmotionTrend(int days) async {
    final n = days.clamp(1, 365);
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final start =
        DateTime(today.year, today.month, today.day).subtract(Duration(days: n - 1));

    final points = _visible(await _repo.getAllEntries())
        .where((e) => !e.createdAt.isBefore(start) && !e.createdAt.isAfter(end))
        .map((e) => EmotionPoint(
              at: e.createdAt,
              mood: e.mood,
              intensity: e.moodIntensity,
            ))
        .toList();

    final trend = DiaryInsight.emotionTrend(
      points: points,
      start: start,
      end: end,
      days: n,
    );

    final range = {
      'start': DiaryInsight.ymd(start),
      'end': DiaryInsight.ymd(end),
      'days': n,
    };

    if (trend.entryCount == 0) {
      return jsonEncode({
        'range': range,
        'entry_count': 0,
        'message': '这段时间没有写过日记，看不出心情走势。',
      });
    }

    return jsonEncode({
      'range': range,
      'entry_count': trend.entryCount,
      'average_intensity': trend.averageIntensity,
      'mood_counts': trend.moodCounts,
      'bucket_days': trend.bucketDays,
      'series': trend.series.map((b) => b.toJson()).toList(),
      'trend': trend.trend,
      'trend_detail': trend.trendDetail,
      'hint': 'trend=up 只说明后半段心情**强度更高**，不等于「更开心」—— '
          '要结合 mood_counts 和 series 里的 emoji 一起看。',
    });
  }

  /// 根据正文推荐标签。
  ///
  /// **只推荐，不写库** —— 要写请让模型走 `update_diary`（那会过确认门）。
  /// 排序规则在纯 Dart 的 [DiaryInsight.suggestTags] 里（可离线断言）。
  ///
  /// ⚠️ 已有标签池走 [_visible]：**标签名本身就是内容**
  /// （有人会写「离婚」「体检报告」这种），锁定日记的标签不能从这里漏出去。
  Future<String> _suggestTags(String content, {String? title}) async {
    final body = content.trim();
    if (body.isEmpty) return jsonEncode({'error': 'content 是空的'});

    final pool = <String, int>{};
    for (final entry in _visible(await _repo.getAllEntries())) {
      for (final tag in entry.tags) {
        pool[tag] = (pool[tag] ?? 0) + 1;
      }
    }

    final suggestions = DiaryInsight.suggestTags(
      content: body,
      title: title ?? '',
      existingTags: pool,
    );

    return jsonEncode({
      'suggestions': suggestions.map((s) => s.toJson()).toList(),
      'existing_tag_pool_size': pool.length,
      'hint': suggestions.isEmpty
          ? '没找到合适的候选，可以直接问用户想加什么标签。'
          : '优先用 from_existing=true 的 —— 复用已有标签能让统计更整齐。'
              '这只是建议：**不要擅自写进日记**，要写请用 update_diary 并让用户确认。',
    });
  }

  // ===== 写操作：预览（只读）=====

  /// 生成「这次要写什么」的人类可读摘要。
  ///
  /// **只读**：只查、只算，一个字都不落库。返回的 request 交给
  /// [ToolConfirmationGate] 挂起等用户点确认；用户点了确认之后
  /// [execute] 才会去调 [_createDiary] 这些真正写库的函数。
  ///
  /// 校验刻意放在这里（而不是写函数里）：
  /// 1. 参数不合法时**根本不弹卡片** —— 用户不该被一个注定失败的确认框打扰；
  /// 2. 预览与实际写入共用同一份解析结果，不会出现「卡片显示 A、实际写了 B」。
  Future<({ToolConfirmationRequest? request, String? error})> _preview(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    try {
      final now = DateTime.now();

      // 字段白名单 / 长度上限 / 日期范围 —— 纯函数，可离线断言
      final guardError = DiaryWriteGuard.validateArgs(args, now: now);
      if (guardError != null) return (request: null, error: guardError);

      switch (toolName) {
        case createDiaryToolName:
          return await _previewCreate(args, now);
        case appendDiaryToolName:
          return await _previewAppend(args);
        case updateDiaryToolName:
          return await _previewUpdate(args);
        case deleteDiaryToolName:
          return await _previewDelete(args);
      }
      return (request: null, error: '未知写工具: $toolName');
    } catch (e) {
      // 预览阶段出的任何错都不该变成一次「弹卡片然后崩」
      return (request: null, error: _plain(e));
    }
  }

  Future<({ToolConfirmationRequest? request, String? error})> _previewCreate(
    Map<String, dynamic> args,
    DateTime now,
  ) async {
    final content = (args['content'] as String).trim();
    final rawTitle = args['title'];
    final title = rawTitle is String ? rawTitle.trim() : '';

    // 幂等：60 秒内已有一篇正文完全相同的日记 → 不重复创建。
    // 真实场景是「模型调了 create_diary，响应丢了，于是重试」。
    final dup = await _findRecentDuplicate(content, now);
    if (dup != null) {
      return (
        request: null,
        error: '最近 60 秒内已经有一篇内容完全相同的日记（ID ${dup.id}'
            '《${dup.title}》），已跳过，没有重复创建。'
            '这不是失败：请直接告诉用户「已经记好了」，不要换种说法再试一次。',
      );
    }

    final mood = _stringOf(args['mood']);
    final lines = <ConfirmationLine>[
      ConfirmationLine(
        label: '标题',
        value: title.isEmpty ? '（自动生成）' : title,
      ),
      ConfirmationLine(
        label: '正文',
        value: excerpt(content),
        emphasize: true,
      ),
      if (mood.isNotEmpty)
        ConfirmationLine(label: '心情', value: _moodText(mood)),
      if (args['tags'] is List && (args['tags'] as List).isNotEmpty)
        ConfirmationLine(
          label: '标签',
          value: (args['tags'] as List).join('、'),
        ),
      if (args['created_at'] != null)
        ConfirmationLine(
          label: '时间',
          value: _stringOf(args['created_at']),
        ),
      ConfirmationLine(
        label: '字数',
        value: '${WordCounter.count(content)} 字',
      ),
    ];

    return (
      request: ToolConfirmationRequest(
        toolName: createDiaryToolName,
        risk: ToolRisk.write,
        title: '新建一篇日记',
        lines: lines,
      ),
      error: null,
    );
  }

  Future<({ToolConfirmationRequest? request, String? error})> _previewAppend(
    Map<String, dynamic> args,
  ) async {
    final id = _asInt(args['diary_id']);
    if (id == null) return (request: null, error: '缺少 diary_id 参数');

    final found = await _readable(id);
    if (found.entry == null) return (request: null, error: found.error);
    final entry = found.entry!;

    final added = (args['content'] as String).trim();
    final merged = _appendContent(entry.content, added);

    return (
      request: ToolConfirmationRequest(
        toolName: appendDiaryToolName,
        risk: ToolRisk.write,
        title: '追加到《${entry.title}》',
        lines: [
          ConfirmationLine(
            label: '追加',
            value: excerpt(added),
            emphasize: true,
          ),
          ConfirmationLine(
            label: '位置',
            value: '正文末尾（原有内容保留）',
          ),
          ConfirmationLine(
            label: '字数',
            value: '${WordCounter.count(entry.content)} → '
                '${WordCounter.count(merged)} 字',
          ),
        ],
      ),
      error: null,
    );
  }

  Future<({ToolConfirmationRequest? request, String? error})> _previewUpdate(
    Map<String, dynamic> args,
  ) async {
    final id = _asInt(args['diary_id']);
    if (id == null) return (request: null, error: '缺少 diary_id 参数');

    final found = await _readable(id);
    if (found.entry == null) return (request: null, error: found.error);
    final entry = found.entry!;

    final lines = <ConfirmationLine>[];

    // 正文的**最终值** —— 提取 #标签时要用它，而不是旧正文。
    // 用旧正文的话，卡片上显示的标签会和实际写进去的不一致。
    final effectiveContent = args.containsKey('content')
        ? (args['content'] as String).trim()
        : entry.content;

    if (args.containsKey('title')) {
      final next = _stringOf(args['title']).trim();
      final normalized = next.isEmpty ? '无标题' : next;
      if (normalized != entry.title) {
        lines.add(ConfirmationLine(
          label: '标题',
          value: diffLine(entry.title, normalized),
        ));
      }
    }

    if (args.containsKey('content')) {
      final next = (args['content'] as String).trim();
      if (next != entry.content) {
        lines.add(ConfirmationLine(
          label: '正文',
          value: diffLine(entry.content, next),
          emphasize: true,
        ));
      }
    }

    if (args.containsKey('mood')) {
      final next = _stringOf(args['mood']).trim();
      if (next != entry.mood) {
        lines.add(ConfirmationLine(
          label: '心情',
          value: diffLine(_moodText(entry.mood), _moodText(next)),
        ));
      }
    }

    if (args.containsKey('mood_note')) {
      final next = _stringOf(args['mood_note']).trim();
      if (next != entry.moodNote) {
        lines.add(ConfirmationLine(
          label: '心情备注',
          value: diffLine(entry.moodNote, next),
        ));
      }
    }

    if (args.containsKey('mood_intensity')) {
      final next = args['mood_intensity'] as int;
      if (next != entry.moodIntensity) {
        lines.add(ConfirmationLine(
          label: '强度',
          value: '${entry.moodIntensity} → $next（1~5）',
        ));
      }
    }

    if (args.containsKey('tags')) {
      final next = _cleanTags(args['tags'], effectiveContent);
      if (!_sameList(next, entry.tags)) {
        lines.add(ConfirmationLine(
          label: '标签',
          value: diffLine(
            entry.tags.isEmpty ? '（无）' : entry.tags.join('、'),
            next.isEmpty ? '（无）' : next.join('、'),
          ),
        ));
      }
    }

    if (lines.isEmpty) {
      return (
        request: null,
        error: '传入的字段和现在的值完全一样，没有需要修改的地方，'
            '所以没有改动。请直接告诉用户「和现在一样，没改」，不要重试。',
      );
    }

    return (
      request: ToolConfirmationRequest(
        toolName: updateDiaryToolName,
        risk: ToolRisk.write,
        title: '修改《${entry.title}》',
        lines: lines,
      ),
      error: null,
    );
  }

  Future<({ToolConfirmationRequest? request, String? error})> _previewDelete(
    Map<String, dynamic> args,
  ) async {
    final id = _asInt(args['diary_id']);
    if (id == null) return (request: null, error: '缺少 diary_id 参数');

    final found = await _readable(id);
    if (found.entry == null) return (request: null, error: found.error);
    final entry = found.entry!;

    final media = <String>[];
    if (entry.images.isNotEmpty) media.add('${entry.images.length} 张图片');
    if (entry.audios.isNotEmpty) media.add('${entry.audios.length} 段录音');

    final mediaText = media.join('、');
    final warning = mediaText.isEmpty
        ? '删除后无法恢复。'
        : '删除后无法恢复。这篇日记里的 $mediaText 也会一起删掉。';

    return (
      request: ToolConfirmationRequest(
        toolName: deleteDiaryToolName,
        risk: ToolRisk.destructive,
        title: '删除《${entry.title}》',
        lines: [
          ConfirmationLine(
            label: '正文',
            value: excerpt(entry.content),
          ),
          ConfirmationLine(
            label: '写于',
            value: _readableTime(entry.createdAt),
          ),
          if (media.isNotEmpty)
            ConfirmationLine(
              label: '一并删除',
              value: mediaText,
            ),
        ],
        warning: warning,
      ),
      error: null,
    );
  }

  // ===== 写操作：真正落库 =====

  /// 新建日记。参数已在 [_previewCreate] 里校验过，这里只负责组装与落库。
  Future<String> _createDiary(Map<String, dynamic> args) async {
    final now = DateTime.now();
    final content = (args['content'] as String).trim();
    final rawTitle = args['title'];
    final title = rawTitle is String ? rawTitle.trim() : '';

    // created_at 已在预览阶段解析过并确认格式合法，这里重解析一次即可
    final rawCreatedAt = args['created_at'];
    final createdAt = rawCreatedAt is String
        ? (DiaryWriteGuard.parseFlexibleDate(rawCreatedAt) ?? now)
        : now;

    final mood = _stringOf(args['mood']).trim();

    final entry = DiaryEntry(
      title: title.isEmpty ? '无标题' : title,
      content: content,
      mood: mood,
      moodIntensity: (args['mood_intensity'] as int?) ?? 3,
      moodNote: _stringOf(args['mood_note']).trim(),
      moodLabel: _moodLabelOf(mood),
      // 字数一律由代码算 —— 让模型填必然算错
      wordCount: WordCounter.count(content),
      tags: _cleanTags(args['tags'], content),
      createdAt: createdAt,
      updatedAt: now,
    );

    final id = await _repo.insertEntry(entry);
    DiaryChangeBus.notifyChanged();

    return jsonEncode({
      'ok': true,
      'diary_id': id,
      'title': entry.title,
      'word_count': entry.wordCount,
      'created_at': entry.createdAt.toIso8601String(),
      'message': '已经写好了。简单说一句记下了什么就行，'
          '不要把正文原样再念一遍。',
    });
  }

  /// 在正文末尾追加内容，保留原文。
  Future<String> _appendToDiary(int id, String content) async {
    final found = await _readable(id);
    if (found.entry == null) {
      return jsonEncode({'error': found.error});
    }
    final entry = found.entry!;
    final added = content.trim();
    if (added.isEmpty) {
      return jsonEncode({'error': '要追加的内容是空的，没有改动'});
    }

    final merged = _appendContent(entry.content, added);
    final updated = entry.copyWith(
      content: merged,
      wordCount: WordCounter.count(merged),
      updatedAt: DateTime.now(),
    );
    await _repo.updateEntry(updated);
    DiaryChangeBus.notifyChanged();

    return jsonEncode({
      'ok': true,
      'diary_id': id,
      'title': entry.title,
      'word_count': updated.wordCount,
      'message': '已经追加到《${entry.title}》的末尾了。',
    });
  }

  /// 局部修改。**只改传进来的字段**，其余原样保留。
  Future<String> _updateDiary(Map<String, dynamic> args) async {
    final id = _asInt(args['diary_id']);
    if (id == null) return jsonEncode({'error': '缺少 diary_id 参数'});

    final found = await _readable(id);
    if (found.entry == null) {
      return jsonEncode({'error': found.error});
    }
    final entry = found.entry!;

    // ⚠️ 关键：这里刻意用 `containsKey` 而不是 `?? 原值` ——
    // 模型说「把心情改成空」时给的是 `mood: ""`，那不是「没传」。
    String title = entry.title;
    if (args.containsKey('title')) {
      final t = _stringOf(args['title']).trim();
      title = t.isEmpty ? '无标题' : t;
    }

    String content = entry.content;
    if (args.containsKey('content')) {
      content = (args['content'] as String).trim();
    }

    final moodChanged = args.containsKey('mood');
    String mood = entry.mood;
    if (moodChanged) mood = _stringOf(args['mood']).trim();

    String moodNote = entry.moodNote;
    if (args.containsKey('mood_note')) {
      moodNote = _stringOf(args['mood_note']).trim();
    }

    int intensity = entry.moodIntensity;
    if (args.containsKey('mood_intensity')) {
      intensity = args['mood_intensity'] as int;
    }

    List<String> tags = entry.tags;
    if (args.containsKey('tags')) {
      tags = _cleanTags(args['tags'], content);
    }

    final updated = entry.copyWith(
      title: title,
      content: content,
      mood: mood,
      moodIntensity: intensity,
      moodNote: moodNote,
      // 只在心情真的被改时才重算标签 —— 否则会把用户在 App 里
      // 手动写的心情描述（`moodLabel`）悄悄抹成空串
      moodLabel: moodChanged ? _moodLabelOf(mood) : entry.moodLabel,
      tags: tags,
      wordCount: WordCounter.count(content),
      updatedAt: DateTime.now(),
    );

    await _repo.updateEntry(updated);
    DiaryChangeBus.notifyChanged();

    return jsonEncode({
      'ok': true,
      'diary_id': id,
      'title': updated.title,
      'word_count': updated.wordCount,
      'message': '已经改好了。简单说一句改了什么就行。',
    });
  }

  /// 删除日记，**连同它的图片与录音文件**。
  ///
  /// 顺序很关键：先删文件、再删库。反过来的话，库里一删就再也拿不到
  /// 文件名了，图片和录音会永远留在磁盘上变成孤儿文件。
  Future<String> _deleteDiary(int id) async {
    final found = await _readable(id);
    if (found.entry == null) {
      return jsonEncode({'error': found.error});
    }
    final entry = found.entry!;

    final failed = await _deleteMediaFiles(entry);

    await _repo.deleteEntry(id);
    DiaryChangeBus.notifyChanged();

    return jsonEncode({
      'ok': true,
      'diary_id': id,
      'title': entry.title,
      'message': '已经删除《${entry.title}》了。',
      // 文件删不掉不该让整次删除失败（日记本身确实已经删了），
      // 但要如实说明，免得用户以为磁盘上干净了
      if (failed.isNotEmpty)
        'warning': '有 ${failed.length} 个媒体文件没能删掉（可能已被手动清理过）：'
            '${failed.join('、')}',
    });
  }

  /// 删掉一篇日记对应的图片与录音文件。返回**失败的文件名**列表。
  ///
  /// 单个文件失败不抛出 —— 一个删不掉的图片不该阻止整篇日记被删除。
  static Future<List<String>> _deleteMediaFiles(DiaryEntry entry) async {
    final failed = <String>[];
    for (final image in entry.images) {
      try {
        await ImageService.deleteImage(image.path);
      } catch (_) {
        failed.add(image.path);
      }
    }
    for (final audio in entry.audios) {
      try {
        await DiaryAudioService.deleteAudio(audio.path);
      } catch (_) {
        failed.add(audio.path);
      }
    }
    return failed;
  }

  // ===== 写操作的小工具 =====

  /// 「最近 [duplicateWindow] 内已有正文完全相同的日记」→ 返回那一篇。
  ///
  /// 只比 [DiaryEntry.content]，不看标题 —— 标题是模型自己起的，
  /// 重试时可能不一样，正文才是「用户到底说了什么」。
  ///
  /// ⚠️ 走 [_visible]：锁定日记的标题不该因为一次去重检查而泄露出去。
  Future<DiaryEntry?> _findRecentDuplicate(String content, DateTime now) async {
    if (content.isEmpty) return null;
    final threshold = now.subtract(duplicateWindow);
    for (final entry in _visible(await _repo.getAllEntries())) {
      if (entry.content.trim() != content) continue;
      if (entry.createdAt.isBefore(threshold)) continue;
      return entry;
    }
    return null;
  }

  /// 追加时正文的合并规则。预览与写入共用这一个函数，保证两者一致。
  static String _appendContent(String old, String added) {
    final base = old.trimRight();
    if (base.isEmpty) return added;
    return '$base\n$added';
  }

  /// 合并「模型显式给的标签」与「正文里的 #标签」，与 App 内保存行为一致。
  ///
  /// `#标签` 的抽取规则统一走 [DiaryInsight.hashTagsIn]（含中文）。
  static List<String> _cleanTags(Object? raw, String content) {
    final manual = <String>[];
    if (raw is List) {
      for (final tag in raw) {
        if (tag is String && tag.trim().isNotEmpty) {
          manual.add(tag.trim().toLowerCase());
        }
      }
    }
    return {...manual, ...DiaryInsight.hashTagsIn(content)}
        .take(DiaryWriteGuard.maxTagCount)
        .toList();
  }

  /// emoji → 中文标签。认不出来就返回空串（**不编造**）。
  static String _moodLabelOf(String emoji) {
    if (emoji.isEmpty) return '';
    return MoodConstants.findByEmoji(emoji)?['label'] ?? '';
  }

  /// 给用户看的「😊 开心」；认不出的 emoji 就原样显示。
  static String _moodText(String emoji) {
    if (emoji.isEmpty) return '（无）';
    final label = _moodLabelOf(emoji);
    return label.isEmpty ? emoji : '$emoji $label';
  }

  /// JSON 里的整数。有些网关会把 `7` 序列化成 `7.0`，所以 `num` 也接住。
  static int? _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  /// 宽松取字符串（模型偶尔给 null 或数字）
  static String _stringOf(Object? raw) => raw is String ? raw : '';

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _readableTime(DateTime at) =>
      '${at.year}-${_two(at.month)}-${_two(at.day)} '
      '${_two(at.hour)}:${_two(at.minute)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  // ===== 日记里的图片与录音 =====

  /// 列出某篇日记的媒体清单（**不含内容**）。
  Future<String> _getDiaryMedia(int diaryId) async {
    final found = await _readable(diaryId);
    if (found.entry == null) {
      return jsonEncode({'error': found.error});
    }
    final entry = found.entry!;
    final images = await DiaryMediaService.imagesOf(entry);
    final audios = await DiaryMediaService.audiosOf(entry);

    return jsonEncode({
      'diary_id': entry.id,
      'title': entry.title,
      'image_count': images.length,
      'audio_count': audios.length,
      'images': images.map((e) => e.toJson()).toList(),
      'audios': audios.map((e) => e.toJson()).toList(),
      'hint': (images.isEmpty && audios.isEmpty)
          ? '这篇日记里没有可读取的图片或录音。'
          : '看图片请调用 $viewImageToolName(diary_id, index)；'
              '读录音请调用 $transcribeAudioToolName(diary_id, index)。',
    });
  }

  /// 把某张图片送进模型视野。
  ///
  /// 返回 [MediaMarker] —— 调用方（`ChatProvider`）解析后追加一条 `role=user`
  /// 的消息把图片挂上去。这是让模型「看见」日记图片的唯一通路：
  /// 图片只能出现在 user 消息里，而 tool 消息的 content 必须是字符串。
  Future<String> _viewDiaryImage(int diaryId, int index) async {
    if (index < 1) {
      return jsonEncode({'error': 'index 从 1 开始'});
    }
    final found = await _readable(diaryId);
    if (found.entry == null) {
      return jsonEncode({'error': found.error});
    }
    final entry = found.entry!;

    final item = await DiaryMediaService.imageAt(entry, index);
    if (item == null) {
      final total = (await DiaryMediaService.imagesOf(entry)).length;
      return jsonEncode({
        'error': total == 0
            ? '这篇日记里没有可读取的图片'
            : '这篇日记只有 $total 张可读取的图片，没有第 $index 张',
      });
    }

    return MediaMarker(
      imagePaths: [item.absPath],
      caption: '日记《${entry.title}》里的第 ${item.index} 张图片',
    ).toMarker();
  }

  /// 转写某段录音。
  ///
  /// 聊天模型吃不了音频，所以只能**在工具内部调一次 STT**，把转写文本返回。
  /// 长录音要先过 `confirm_long`：转写是第二次付费请求，不该被无意触发。
  Future<String> _transcribeDiaryAudio(
    int diaryId,
    int index,
    bool confirmLong,
  ) async {
    if (index < 1) {
      return jsonEncode({'error': 'index 从 1 开始'});
    }
    final found = await _readable(diaryId);
    if (found.entry == null) {
      return jsonEncode({'error': found.error});
    }
    final entry = found.entry!;

    final item = await DiaryMediaService.audioAt(entry, index);
    if (item == null) {
      final total = (await DiaryMediaService.audiosOf(entry)).length;
      return jsonEncode({
        'error': total == 0
            ? '这篇日记里没有可读取的录音'
            : '这篇日记只有 $total 段可读取的录音，没有第 $index 段',
      });
    }

    final durationMs = item.durationMs ?? 0;
    if (durationMs > DiaryMediaService.longAudioThresholdMs && !confirmLong) {
      return jsonEncode({
        'needs_confirmation': true,
        'duration': formatDuration(durationMs),
        'message': '这段录音有 ${formatDuration(durationMs)}，转写会产生一次额外的'
            '识别请求（要花钱、也要等一会儿）。请先问用户要不要转写；'
            '用户同意后带 confirm_long=true 再调用一次。',
      });
    }

    try {
      final text = await DiaryMediaService.transcribe(item.absPath);
      return jsonEncode({
        'diary_id': entry.id,
        'index': item.index,
        'duration': formatDuration(durationMs),
        'text': text,
      });
    } catch (e) {
      // 未配 STT 厂商 / 识别失败：**如实报错**，绝不返回空串 ——
      // 空串会让模型顺着空白编出一段根本不存在的录音内容。
      return jsonEncode({'error': _plain(e)});
    }
  }

  /// 生图。返回 [ImageGenResult.toMarker] 形式的标记字符串 ——
  /// 里面带 path，调用方据此把图片挂到这条工具消息上显示出来。
  ///
  /// [referencePath] 由调用方（ChatProvider）注入 —— 工具层是无状态的，
  /// 看不到会话消息，所以模型只说「参考用户最近发的图」，真正的路径得由
  /// 上层补进来。
  Future<String> _generateImage(String? prompt, {String? referencePath}) async {
    final text = (prompt ?? '').trim();
    if (text.isEmpty) {
      return jsonEncode({'error': '缺少 prompt 参数：请描述想生成的画面'});
    }
    final result = await _imageGen.generateAndStore(
      text,
      referenceImagePath: referencePath,
    );
    return result.toMarker();
  }
}
