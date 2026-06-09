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
}

class LlmService {
  static const _providers = [
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
      models: ['doubao-lite-4k', 'doubao-pro-4k'],
    ),
  ];

  static List<LlmProvider> get providers => _providers;

  static const _keyProvider = 'chat_api_provider';
  static const _keyApiKey = 'chat_api_key';
  static const _keyModel = 'chat_api_model';
  static const _keyUrl = 'chat_api_url';
  static const _keySystemPrompt = 'chat_system_prompt';

  static const defaultSystemPrompt =
      '你是用户的日记助手，拥有查询日记数据的能力。'
      '你可以：搜索日记内容、按日期/心情/标签筛选；'
      '查看日记统计数据（心情分布、标签使用、写作习惯）；'
      '分析写作趋势（字数变化、时间分布、连续打卡）。'
      '请用温暖、友善的语气回答。当用户问关于日记的问题时，'
      '优先使用工具查询真实数据，再基于数据给出有意义的分析和建议。'
      '如果用户的问题不需要查询数据（如写作建议、情感支持），可以直接回答。';

  static Future<Map<String, String?>> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'provider': prefs.getString(_keyProvider),
      'apiKey': prefs.getString(_keyApiKey),
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
    await prefs.setString(_keyApiKey, apiKey);
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
