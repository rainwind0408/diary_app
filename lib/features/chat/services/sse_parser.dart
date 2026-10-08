/// SSE（Server-Sent Events）解析：把 OpenAI 兼容的流式响应逐行变成结构化增量。
///
/// 纯 Dart（只依赖 dart:convert），便于在纯 Dart VM 里独立测试。
///
/// 典型的流式响应长这样（每帧之间用空行分隔）：
/// ```
/// data: {"choices":[{"delta":{"reasoning_content":"先查一下"}}]}
///
/// data: {"choices":[{"delta":{"content":"你上周"}}]}
///
/// data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1",
///         "function":{"name":"search","arguments":"{\"q\":"}}]}}]}
///
/// data: [DONE]
/// ```
library;

import 'dart:convert';

import '../models/chat_message.dart';
import 'reasoning_parser.dart';

/// 流式响应里工具调用的一个分片。
///
/// 各家会把一次 tool_call 拆成多帧：第一帧带 `id` 与 `function.name`，
/// 后续帧只带 `function.arguments` 的**字符串片段**，必须按 [index] 拼接。
class ToolCallDelta {
  final int index;
  final String? id;
  final String? name;
  final String? arguments;

  const ToolCallDelta({
    required this.index,
    this.id,
    this.name,
    this.arguments,
  });

  /// 解析一帧里的 tool_calls 数组；结构不对的条目直接跳过。
  static List<ToolCallDelta> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    final result = <ToolCallDelta>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final fn = item['function'];
      result.add(
        ToolCallDelta(
          // 缺 index 时按 0 处理 —— 丢掉会导致整次工具调用凭空消失
          index: _toInt(item['index']) ?? 0,
          id: item['id'] is String ? item['id'] as String : null,
          name: (fn is Map && fn['name'] is String)
              ? fn['name'] as String
              : null,
          arguments: (fn is Map && fn['arguments'] is String)
              ? fn['arguments'] as String
              : null,
        ),
      );
    }
    return result;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// 流式响应的一帧增量。
class StreamDelta {
  final String content;

  /// 思考过程增量（**不做 trim**，否则帧间空格会被吃掉）
  final String reasoning;
  final List<ToolCallDelta> toolCalls;
  final String finishReason;

  const StreamDelta({
    this.content = '',
    this.reasoning = '',
    this.toolCalls = const [],
    this.finishReason = '',
  });

  bool get isEmpty =>
      content.isEmpty &&
      reasoning.isEmpty &&
      toolCalls.isEmpty &&
      finishReason.isEmpty;
}

/// 一行 SSE 的解析结果。
class SseLineResult {
  /// 收到 `[DONE]`，流结束
  final bool done;

  /// 本行携带的增量；null 表示这行没内容（空行 / 注释 / 心跳 / 坏 JSON）
  final StreamDelta? delta;

  const SseLineResult.ignore()
      : done = false,
        delta = null;
  const SseLineResult.finished()
      : done = true,
        delta = null;
  const SseLineResult.data(this.delta) : done = false;
}

class SseParser {
  SseParser._();

  static const String dataPrefix = 'data:';
  static const String doneMarker = '[DONE]';

  /// 解析一行。
  ///
  /// **绝不抛异常** —— 流式场景里一行坏数据不该毁掉整轮回答，
  /// 解析不了就当这行不存在。
  static SseLineResult parseLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return const SseLineResult.ignore();
    // `event:` / `id:` / `retry:` / `:comment` 一律忽略
    if (!line.startsWith(dataPrefix)) return const SseLineResult.ignore();

    // 有的网关是 `data:{}`（冒号后无空格），trim 两种都能吃
    final payload = line.substring(dataPrefix.length).trim();
    if (payload.isEmpty) return const SseLineResult.ignore();
    if (payload == doneMarker) return const SseLineResult.finished();

    Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (_) {
      return const SseLineResult.ignore();
    }
    if (decoded is! Map) return const SseLineResult.ignore();

    return SseLineResult.data(deltaFromChunk(decoded));
  }

  /// 从一个已解析的 JSON 对象里抽出增量。
  static StreamDelta deltaFromChunk(Map<dynamic, dynamic> root) {
    final choices = root['choices'];
    // 有的网关会单独发一帧 usage（choices 为空数组），忽略即可
    if (choices is! List || choices.isEmpty) return const StreamDelta();

    final choice = choices.first;
    if (choice is! Map) return const StreamDelta();

    var content = '';
    var reasoning = '';

    final delta = choice['delta'];
    if (delta is Map) {
      final c = delta['content'];
      if (c is String) content = c;
      // 用 raw 版本：流式分片里的空格是有效字符，不能 trim
      reasoning = ReasoningParser.rawFromMessage(
        Map<String, dynamic>.from(delta),
      );
    } else {
      // 少数网关在流式里仍返回完整的 message 而非 delta
      final message = choice['message'];
      if (message is Map) {
        final c = message['content'];
        if (c is String) content = c;
        reasoning = ReasoningParser.rawFromMessage(
          Map<String, dynamic>.from(message),
        );
      }
    }

    final finish = choice['finish_reason'];

    return StreamDelta(
      content: content,
      reasoning: reasoning,
      toolCalls: ToolCallDelta.listFrom(
        delta is Map ? delta['tool_calls'] : null,
      ),
      finishReason: finish is String ? finish : '',
    );
  }
}

/// 把流式分片拼成完整的 [ToolCall] 列表。
class ToolCallAssembler {
  final Map<int, _PartialToolCall> _partials = {};

  void add(List<ToolCallDelta> deltas) {
    for (final d in deltas) {
      final partial = _partials.putIfAbsent(d.index, _PartialToolCall.new);
      final id = d.id;
      if (id != null && id.isNotEmpty) partial.id = id;
      final name = d.name;
      if (name != null && name.isNotEmpty) partial.name = name;
      final args = d.arguments;
      if (args != null && args.isNotEmpty) partial.arguments.write(args);
    }
  }

  bool get isEmpty => _partials.isEmpty;

  /// 按 index 升序产出。缺名字的残缺分片丢弃（无法执行）。
  List<ToolCall> build() {
    final indexes = _partials.keys.toList()..sort();
    final result = <ToolCall>[];
    for (final index in indexes) {
      final partial = _partials[index]!;
      if (partial.name.isEmpty) continue;
      result.add(
        ToolCall(
          id: partial.id.isEmpty ? 'call_$index' : partial.id,
          name: partial.name,
          arguments: parseArguments(partial.arguments.toString()),
        ),
      );
    }
    return result;
  }

  /// 把累积的 arguments 字符串解析成 Map。
  ///
  /// 模型偶尔会吐出截断或非法的 JSON，这时退化成空参数，
  /// 让工具自己用默认值兜底，而不是让整轮对话崩掉。
  static Map<String, dynamic> parseArguments(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const {};
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // 落到下面的兜底
    }
    return const {};
  }
}

class _PartialToolCall {
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
}
