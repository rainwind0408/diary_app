import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_provider.dart';
import '../models/chat_message.dart';
import '../models/reply_style.dart';
import 'ai_config_store.dart';
import 'reasoning_parser.dart';
import 'sse_parser.dart';

/// 对话（chat）能力的门面。
///
/// 配置读写统一收敛在 [AiConfigStore]；本类只负责三件事：
/// 发起对话请求（流式 / 非流式）、中断流式、联网更新模型列表。
///
/// P1 起旧的平铺配置兼容层（`LlmProvider` / `loadConfig` / `saveConfig` /
/// `getApiKeyFor` / `isConfigured` / `providers`）已随 `api_config_dialog.dart`
/// 一并移除 —— 那些接口的调用方已经全部迁移到 [AiConfigStore] 与
/// `ProviderManageScreen`。
class LlmService {
  /// 流式中途断掉（网络问题等）时，给「半截回答」打的 [ChatMessage.finishReason] 标记。
  ///
  /// 有了这个标记，调用方就能既保住已经生成的内容，又明确告诉用户「没写完」。
  static const String finishInterrupted = 'interrupted';

  // ── 流式中断 ──

  http.Client? _activeStreamClient;
  bool _streamAborted = false;

  /// 当前是否有流式请求在跑
  bool get isStreaming => _activeStreamClient != null;

  /// 中断当前流式请求（用户点「停止」时调用）。
  ///
  /// 只关掉底层连接；[chatStream] 会把**已经流出来的部分**照常返回，
  /// 让用户保住半截回答，而不是整段凭空消失。
  void abortStream() {
    final client = _activeStreamClient;
    if (client == null) return;
    _streamAborted = true;
    try {
      client.close();
    } catch (_) {
      // 已经关掉了，无所谓
    }
  }

  // ── 对话（非流式） ──

  /// 发起一次对话请求。
  ///
  /// [messages] 是**已组装好的 API 消息体**（含多模态 content parts），
  /// 由 `ChatProvider` 负责异步编码附件后再传进来。
  Future<ChatMessage> chat({
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    ReplyStyle style = ReplyStyle.normal,
  }) async {
    final spec = await _prepare(
      messages: messages,
      tools: tools,
      stream: false,
      style: style,
    );

    final response = await http.post(
      Uri.parse(spec.url),
      headers: spec.headers,
      body: jsonEncode(spec.body),
    );

    if (response.statusCode != 200) {
      throw Exception('API 调用失败 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final choice = data['choices'][0]['message'];
    final finish = data['choices'][0]['finish_reason'];

    // ★ 用 tryFromMap 而不是 fromMap：厂商的**服务端工具**会返回一种没有
    //   `function` 字段的 tool_call（例如智谱的 `{"type":"web_search",...}`、
    //   代码解释器之类）。老的 `fromMap` 里 `map['function'] as Map` 会直接抛
    //   TypeError，把一次本来成功的回答变成报错。这类工具由厂商自己执行完，
    //   客户端不需要也不应该去执行它 —— 丢掉即可。
    final toolCalls = <ToolCall>[];
    if (choice['tool_calls'] is List) {
      for (final tc in choice['tool_calls'] as List) {
        final parsed = ToolCall.tryFromMap(tc);
        if (parsed != null) toolCalls.add(parsed);
      }
    }

    final message = ChatMessage(
      role: 'assistant',
      content: (choice['content'] as String?) ?? '',
      reasoning: ReasoningParser.fromMessage(choice),
      finishReason: finish is String ? finish : '',
      toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
    );
    if (message.hasReasoning) await _rememberReasoningModel(spec.model);
    return message;
  }

  // ── 对话（流式） ──

  /// 流式对话请求。
  ///
  /// 增量通过 [onDelta] 实时回调，**返回值仍是完整的助手消息**
  /// （含按 index 拼接好的 tool_calls）。
  ///
  /// 为什么不返回 `Stream<StreamDelta>`：调用方（ChatProvider）无论如何都要
  /// 拿到最终消息才能决定「要不要执行工具、要不要落库」；拆成 Stream 只会
  /// 逼着调用方在外面再拼一遍内容与工具调用，得不偿失。
  Future<ChatMessage> chatStream({
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    required void Function(StreamDelta delta) onDelta,
    ReplyStyle style = ReplyStyle.normal,
  }) async {
    final spec = await _prepare(
      messages: messages,
      tools: tools,
      stream: true,
      style: style,
    );

    final client = http.Client();
    _activeStreamClient = client;
    _streamAborted = false;

    try {
      final request = http.Request('POST', Uri.parse(spec.url))
        ..headers.addAll(spec.headers)
        ..body = jsonEncode(spec.body);

      final response = await client.send(request);

      if (response.statusCode != 200) {
        final text = await response.stream.bytesToString();
        // 少数网关 / 自建模型不认 stream:true —— 退回一次性请求，
        // 别让用户因为「不支持流式」就完全聊不了。
        if (_looksLikeStreamUnsupported(response.statusCode, text)) {
          // 退回一次性请求时**必须带上同样的 style** ——
          // 否则语音回合会在这里悄悄丢掉「150 字」约束
          final fallback =
              await chat(messages: messages, tools: tools, style: style);
          onDelta(
            StreamDelta(
              content: fallback.content,
              reasoning: fallback.reasoning,
            ),
          );
          return fallback;
        }
        throw Exception('API 调用失败 (${response.statusCode}): $text');
      }

      final content = StringBuffer();
      final reasoning = StringBuffer();
      final assembler = ToolCallAssembler();
      var finishReason = '';

      // utf8.decoder 会跨 chunk 保住被切断的多字节字符；LineSplitter 认 \n 与 \r\n。
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      try {
        await for (final line in lines) {
          final parsed = SseParser.parseLine(line);
          if (parsed.done) break;

          final delta = parsed.delta;
          if (delta == null || delta.isEmpty) continue;

          if (delta.content.isNotEmpty) content.write(delta.content);
          if (delta.reasoning.isNotEmpty) reasoning.write(delta.reasoning);
          if (delta.toolCalls.isNotEmpty) assembler.add(delta.toolCalls);
          if (delta.finishReason.isNotEmpty) finishReason = delta.finishReason;

          onDelta(delta);
        }
      } catch (e) {
        // 用户点「停止」时 client.close() 会让流抛异常 —— 这不是错误，
        // 把已经流出来的部分照常返回（非破坏性收尾）。
        if (_streamAborted) {
          // 落到下面正常返回
        } else if (content.isNotEmpty || reasoning.isNotEmpty) {
          // 网络中途断了：把半截回答带回去（打上 finishInterrupted 标记），
          // 别让用户眼睁睁看着已经写出来的内容消失。
          // 注意：请求阶段的错误（413 / 鉴权）此时 content 还是空的，会走 rethrow，
          // 所以「附件过大重试」那条链路不受影响。
          final toolCalls = assembler.build();
          return ChatMessage(
            role: 'assistant',
            content: content.toString(),
            reasoning: reasoning.toString(),
            finishReason: finishInterrupted,
            toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
          );
        } else {
          rethrow;
        }
      }

      final toolCalls = assembler.build();
      final message = ChatMessage(
        role: 'assistant',
        content: content.toString(),
        reasoning: reasoning.toString(),
        finishReason: finishReason,
        toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
      );

      // 见过它吐思考过程 → 记下来，下次请求就给它留思考预算
      if (message.hasReasoning) await _rememberReasoningModel(spec.model);

      return message;
    } finally {
      if (identical(_activeStreamClient, client)) _activeStreamClient = null;
      try {
        client.close();
      } catch (_) {
        // 忽略
      }
    }
  }

  // ── 内部：请求准备 ──

  Future<_RequestSpec> _prepare({
    required List<Map<String, dynamic>> messages,
    required bool stream,
    List<Map<String, dynamic>>? tools,
    ReplyStyle style = ReplyStyle.normal,
  }) async {
    final config = await AiConfigStore.load();
    final active = config.activeProvider(AiCapability.chat);

    final apiKey = active?.apiKey ?? '';
    if (apiKey.isEmpty) {
      throw Exception('请先在 AI 助手设置里配置 API Key');
    }

    final url = active!.baseUrl;
    if (url.isEmpty) {
      throw Exception('该厂商未配置 API 地址');
    }

    final model = config.activeModel(AiCapability.chat) ?? '';

    // 回合级约束（如语音回合的「150 字以内」）追加在**全局 systemPrompt 之后**。
    // 不改 config.systemPrompt 本身 —— 那是用户在设置里手改的，不能被临时请求污染。
    final systemPrompt = '${config.systemPrompt}${style.systemSuffix}';

    // 语音回合压低正文额度。cap 只是「模型收不住尾」时的安全网，
    // 不是截断手段 —— 它比 150 字宽裕一倍（见 ReplyStyle.contentTokenCap）。
    // 推理模型的思考预算要照常加回去，否则思考会把正文挤没。
    final cap = style.contentTokenCap;
    final maxTokens = cap == null
        ? config.effectiveMaxTokensFor(model)
        : cap + (config.isReasoningModel(model) ? config.reasoningBudget : 0);

    final body = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        ...messages,
      ],
      'temperature': config.temperature,
      'max_tokens': maxTokens,
    };
    if (stream) body['stream'] = true;
    if (tools != null && tools.isNotEmpty) body['tools'] = tools;

    return _RequestSpec(
      url: '$url/chat/completions',
      model: model,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );
  }

  /// 判断这次失败是不是「网关不认 `stream:true`」。
  ///
  /// 只对「请求本身有问题」类状态码放宽；401/403（鉴权）与 429（限流）
  /// 一律照常抛错 —— 那些退回非流式也一样失败，反而会掩盖真实原因。
  static bool _looksLikeStreamUnsupported(int status, String body) {
    const candidates = {400, 404, 405, 422, 501};
    if (!candidates.contains(status)) return false;
    return body.toLowerCase().contains('stream');
  }

  /// 把「这个模型会输出思考过程」写进配置，下次请求就会给它留思考预算。
  ///
  /// 已经记过就不写盘（[AiConfig.rememberReasoningModel] 会原样返回同一实例）。
  /// 记不住也不影响这次回答，所以整段静默兜底。
  static Future<void> _rememberReasoningModel(String model) async {
    if (model.isEmpty) return;
    try {
      final config = await AiConfigStore.load();
      final next = config.rememberReasoningModel(model);
      if (identical(next, config)) return;
      await AiConfigStore.save(next);
    } catch (_) {
      // 忽略：这只是优化，不该影响对话
    }
  }

  // ── 模型列表更新 ──

  /// 手动联网更新「对话」能力的当前厂商模型列表，返回新增（过滤后）的模型数量
  static Future<int> updateModels() => updateModelsFor(AiCapability.chat);

  /// 手动联网更新指定能力当前选中厂商的模型列表
  static Future<int> updateModelsFor(AiCapability capability) async {
    final config = await AiConfigStore.load();
    final active = config.activeProvider(capability);
    if (active == null) {
      throw Exception('该能力尚未配置厂商');
    }
    return updateModelsOf(active);
  }

  /// 更新**指定厂商**的模型列表（不要求它是当前选中项）。
  ///
  /// 编辑页会用到：用户可能正在编辑一个还没选中的厂商。
  ///
  /// 注意：只有 OpenAI 兼容协议的 `/models` 端点可用；DashScope / 讯飞 /
  /// 百度 / 腾讯等私有协议没有统一列表接口，会返回「获取模型列表失败」。
  static Future<int> updateModelsOf(AiProvider provider) async {
    if (!provider.hasApiKey) {
      throw Exception('请先配置 API Key');
    }
    if (provider.baseUrl.isEmpty) {
      throw Exception('该厂商未配置 API 地址');
    }

    final apiModels =
        await _fetchProviderModels(provider.baseUrl, provider.apiKey);
    if (apiModels == null || apiModels.isEmpty) {
      throw Exception('获取模型列表失败');
    }

    final filtered = _filterModels(provider, apiModels);
    if (filtered.isEmpty) {
      throw Exception('未找到匹配的模型');
    }

    final merged = provider.mergeModels(filtered);
    await AiConfigStore.update((c) => c.upsertProvider(merged));
    return filtered.length;
  }

  /// 只保留该厂商前缀的模型（未配置前缀时原样返回）
  static List<String> _filterModels(
    AiProvider provider,
    List<String> apiModels,
  ) {
    final prefix = provider.modelPrefix;
    if (prefix == null || prefix.isEmpty) return apiModels;
    return apiModels.where((m) => m.startsWith(prefix)).toList();
  }

  static Future<List<String>?> _fetchProviderModels(
    String baseUrl,
    String apiKey,
  ) async {
    try {
      final modelsUrl = '$baseUrl/models';
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
}

/// 一次对话请求所需的全部要素（地址 / 模型 / 头 / 体），流式与非流式共用。
class _RequestSpec {
  final String url;
  final String model;
  final Map<String, String> headers;
  final Map<String, dynamic> body;

  const _RequestSpec({
    required this.url,
    required this.model,
    required this.headers,
    required this.body,
  });
}
