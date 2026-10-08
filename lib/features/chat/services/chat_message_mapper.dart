/// 业务消息模型（[ChatMessage]）与持久化模型（[ChatMessageRecord]）的互转。
///
/// 本文件不依赖 Flutter，便于独立测试。
library;

import 'dart:convert';

import '../../../data/models/chat_message_record.dart';
import '../models/chat_attachment.dart';
import '../models/chat_message.dart';

class ChatMessageMapper {
  ChatMessageMapper._();

  /// 业务模型 → 持久化模型
  ///
  /// 不传 [attachmentsJson] 时自动从 `message.attachments` 编码。
  static ChatMessageRecord toRecord(
    ChatMessage message, {
    required int sessionId,
    int? id,
    String status = ChatMessageRecord.statusSent,
    String? attachmentsJson,
  }) {
    return ChatMessageRecord(
      id: id,
      sessionId: sessionId,
      role: message.role,
      content: message.content,
      toolCallsJson: _encodeToolCalls(message.toolCalls),
      toolCallId: message.toolCallId ?? '',
      toolName: message.toolName ?? '',
      attachmentsJson:
          attachmentsJson ?? ChatAttachment.encodeList(message.attachments),
      status: status,
      reasoning: message.reasoning,
      createdAt: message.timestamp,
    );
  }

  /// 持久化模型 → 业务模型
  static ChatMessage toChatMessage(ChatMessageRecord record) {
    return ChatMessage(
      role: record.role,
      content: record.content,
      reasoning: record.reasoning,
      toolCalls: _decodeToolCalls(record.toolCallsJson),
      toolCallId: record.toolCallId.isEmpty ? null : record.toolCallId,
      toolName: record.toolName.isEmpty ? null : record.toolName,
      attachments: ChatAttachment.decodeList(record.attachmentsJson),
      timestamp: record.createdAt,
    );
  }

  static String _encodeToolCalls(List<ToolCall>? calls) {
    if (calls == null || calls.isEmpty) {
      return ChatMessageRecord.emptyJsonArray;
    }
    return jsonEncode(calls.map((c) => c.toMap()).toList());
  }

  static List<ToolCall>? _decodeToolCalls(String raw) {
    if (raw.trim().isEmpty || raw.trim() == ChatMessageRecord.emptyJsonArray) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List || decoded.isEmpty) return null;
      final result = <ToolCall>[];
      for (final item in decoded) {
        if (item is Map) {
          result.add(ToolCall.fromMap(Map<String, dynamic>.from(item)));
        }
      }
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }
}
