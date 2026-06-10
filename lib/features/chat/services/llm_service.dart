import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class LlmProvider {
  final String name;
  final String baseUrl;
  final List<String> models;

  const LlmProvider({
    required this.name,
    required this.baseUrl,
    required this.models,
  });

  LlmProvider copyWith({
    String? name,
    String? baseUrl,
    List<String>? models,
  }) {
    return LlmProvider(
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      models: models ?? this.models,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'baseUrl': baseUrl,
        'models': models,
      };

  factory LlmProvider.fromMap(Map<String, dynamic> map) => LlmProvider(
        name: map['name'] as String,
        baseUrl: map['baseUrl'] as String,
        models: (map['models'] as List).cast<String>(),
      );
}

class LlmService {
  // ── 默认 provider（源码硬编码，作为兜底） ──
  static const _defaultProviders = [
    LlmProvider(
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1',
      models: ['deepseek-chat', 'deepseek-reasoner'],
    ),
    LlmProvider(
      name: '通义千问',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      models: ['qwen-turbo', 'qwen-plus', 'qwen-max'],
    ),
    LlmProvider(
      name: '智谱 GLM',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      models: ['glm-4-flash', 'glm-4'],
    ),
    LlmProvider(
      name: '月之暗面',
      baseUrl: 'https://api.moonshot.cn/v1',
      models: ['moonshot-v1-8k', 'moonshot-v1-32k'],
    ),
    LlmProvider(
      name: '豆包',
      baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
      models: ['doubao-1.5-pro-32k', 'doubao-1.5-lite-32k'],
    ),
  ];

  // ── 缓存（从 SharedPreferences 加载） ──
  static List<LlmProvider>? _cachedProviders;

  // ── 各厂商模型名前缀（用于过滤 API 返回的模型列表） ──
  static const _providerPrefixes = {
    'DeepSeek': 'deepseek-',
    '通义千问': 'qwen-',
    '智谱 GLM': 'glm-',
    '月之暗面': 'moonshot-',
    // 豆包使用用户自定义端点 ID（ep-xxxx），不做前缀过滤
  };

  // ── SharedPreferences keys ──
  static const _keyProvider = 'chat_api_provider';
  static const _keyApiKey = 'chat_api_key';
  static const _keyApiKeys = 'chat_api_keys';
  static const _keyModel = 'chat_api_model';
  static const _keyUrl = 'chat_api_url';
  static const _keySystemPrompt = 'chat_system_prompt';
  static const _keyCachedProviders = 'chat_cached_providers';

  // ── API Key 按厂商存储 ──

  static Future<Map<String, String>> _loadApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyApiKeys);
    if (json != null) {
      return Map<String, String>.from(jsonDecode(json));
    }
    // 迁移：旧单 key → 新 map
    final oldKey = prefs.getString(_keyApiKey);
    final oldProvider = prefs.getString(_keyProvider);
    if (oldKey != null && oldProvider != null) {
      final map = {oldProvider: oldKey};
      await prefs.setString(_keyApiKeys, jsonEncode(map));
      return map;
    }
    return {};
  }

  static Future<void> _saveApiKey(String provider, String apiKey) async {
    final keys = await _loadApiKeys();
    keys[provider] = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKeys, jsonEncode(keys));
  }

  static const defaultSystemPrompt =
      '你是用户的日记助手，拥有查询日记数据的能力。'
      '你可以：搜索日记内容、按日期/心情/标签筛选；'
      '查看日记统计数据（心情分布、标签使用、写作习惯）；'
      '分析写作趋势（字数变化、时间分布、连续打卡）。'
      '请用温暖、友善的语气回答。当用户问关于日记的问题时，'
      '优先使用工具查询真实数据，再基于数据给出有意义的分析和建议。'
      '如果用户的问题不需要查询数据（如写作建议、情感支持），可以直接回答。';

  // ── Provider 列表（优先缓存，回退默认） ──
  static List<LlmProvider> get providers =>
      _cachedProviders ?? _defaultProviders;

  // ── 配置读写 ──

  static Future<Map<String, String?>> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString(_keyProvider);
    final keys = await _loadApiKeys();
    return {
      'provider': provider,
      'apiKey': provider != null ? keys[provider] : null,
      'model': prefs.getString(_keyModel),
      'url': prefs.getString(_keyUrl),
      'systemPrompt': prefs.getString(_keySystemPrompt),
    };
  }

  static Future<void> saveConfig({
    required String provider,
    required String apiKey,
    required String model,
    required String url,
    String? systemPrompt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProvider, provider);
    await _saveApiKey(provider, apiKey);
    await prefs.setString(_keyModel, model);
    await prefs.setString(_keyUrl, url);
    if (systemPrompt != null) {
      await prefs.setString(_keySystemPrompt, systemPrompt);
    }
  }

  static Future<bool> isConfigured() async {
    final config = await loadConfig();
    return config['apiKey'] != null && config['apiKey']!.isNotEmpty;
  }

  static Future<String?> getApiKeyFor(String provider) async {
    final keys = await _loadApiKeys();
    return keys[provider];
  }

  // ── 缓存读写 ──

  static Future<void> _loadCachedProviders() async {
    if (_cachedProviders != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_keyCachedProviders);
      if (json != null) {
        final list = jsonDecode(json) as List;
        _cachedProviders = list
            .map((e) => LlmProvider.fromMap(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      _cachedProviders = null;
    }
  }

  static Future<void> _saveCachedProviders(List<LlmProvider> list) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(list.map((p) => p.toMap()).toList());
    await prefs.setString(_keyCachedProviders, json);
    _cachedProviders = list;
  }

  // ── 前缀过滤：只保留该厂商前缀的模型 ──

  static List<String> _filterModels(String providerName, List<String> apiModels) {
    final prefix = _providerPrefixes[providerName];
    if (prefix == null) return apiModels;
    return apiModels.where((m) => m.startsWith(prefix)).toList();
  }

  // ── 获取单个 provider 的模型列表 ──

  static Future<List<String>?> _fetchProviderModels(
    String baseUrl,
    String apiKey,
  ) async {
    try {
      // 大部分厂商兼容 GET /v1/models，豆包用 /api/v3/models
      final modelsUrl = baseUrl.endsWith('/v1')
          ? '$baseUrl/models'
          : '$baseUrl/models';

      final response = await http.get(
        Uri.parse(modelsUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final List<dynamic> modelList = data['data'] ?? [];
      final ids = modelList
          .map((m) => m['id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      return ids.isEmpty ? null : ids;
    } catch (_) {
      return null;
    }
  }

  // ── 主入口：手动更新模型列表 ──

  static Future<int> updateModels() async {
    // 加载缓存
    await _loadCachedProviders();

    // 读取用户已配置的 provider 和 API Key
    final config = await loadConfig();
    final configuredProvider = config['provider'];
    final configuredApiKey = config['apiKey'];

    if (configuredProvider == null || configuredApiKey == null) {
      throw Exception('请先配置 API Key');
    }

    // 找到对应的默认 provider
    final defaultProvider = _defaultProviders.firstWhere(
      (p) => p.name == configuredProvider,
      orElse: () => _defaultProviders.first,
    );

    // 获取该 provider 的最新模型列表
    final apiModels = await _fetchProviderModels(
      defaultProvider.baseUrl,
      configuredApiKey,
    );

    // TODO: 调试日志，测试完毕后删除
    print('[更新模型] provider=$configuredProvider');
    print('[更新模型] API 返回 ${apiModels?.length ?? 0} 个: $apiModels');

    if (apiModels == null || apiModels.isEmpty) {
      throw Exception('获取模型列表失败');
    }

    // 前缀过滤：只保留该厂商的模型
    final filtered = _filterModels(configuredProvider, apiModels);
    print('[更新模型] 前缀过滤后 ${filtered.length} 个: $filtered');

    if (filtered.isEmpty) {
      throw Exception('未找到匹配的模型');
    }

    // 合并：保留原有推荐模型 + 新发现的模型，去重
    final updatedProviders = <LlmProvider>[];
    for (final dp in _defaultProviders) {
      if (dp.name == configuredProvider) {
        final merged = <String>{...dp.models, ...filtered}.toList();
        print('[更新模型] 合并后 ${merged.length} 个: $merged');
        updatedProviders.add(dp.copyWith(models: merged));
      } else {
        updatedProviders.add(dp);
      }
    }

    // 持久化
    await _saveCachedProviders(updatedProviders);
    return filtered.length;
  }

  // ── 聊天 ──

  Future<ChatMessage> chat({
    required List<ChatMessage> messages,
    List<Map<String, dynamic>>? tools,
  }) async {
    final config = await loadConfig();
    final apiKey = config['apiKey'];
    final model = config['model'];
    final url = config['url'];
    final systemPrompt = config['systemPrompt'] ?? defaultSystemPrompt;

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先配置 API Key');
    }

    final apiMessages = [
      {'role': 'system', 'content': systemPrompt},
      ...messages.map((m) => m.toApiMap()),
    ];

    final body = <String, dynamic>{
      'model': model,
      'messages': apiMessages,
      'temperature': 0.7,
      'max_tokens': 2048,
    };

    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
    }

    final response = await http.post(
      Uri.parse('$url/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('API 调用失败 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final choice = data['choices'][0]['message'];

    final toolCalls = <ToolCall>[];
    if (choice['tool_calls'] != null) {
      for (final tc in choice['tool_calls'] as List) {
        toolCalls.add(ToolCall.fromMap(tc as Map<String, dynamic>));
      }
    }

    return ChatMessage(
      role: 'assistant',
      content: (choice['content'] as String?) ?? '',
      toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
    );
  }
}
