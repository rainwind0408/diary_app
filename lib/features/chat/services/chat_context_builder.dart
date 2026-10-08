/// 组装发给大模型的上下文（纯 Dart，不依赖 Flutter，便于独立测试）
library;

import '../../../data/models/chat_message_record.dart';
import '../models/chat_attachment.dart';
import '../models/chat_message.dart';
import 'chat_message_mapper.dart';

class ChatContextBuilder {
  ChatContextBuilder._();

  /// 附件总预算（原始字节数）。
  ///
  /// base64 后约为原始的 1.37 倍，24MB 原始 ≈ 33MB 请求体；再大就有 OOM 风险。
  /// 超预算时**从最旧的消息开始剥离附件**（文本保留），最新的那条永远带附件。
  static const int defaultAttachmentBudgetBytes = 24 * 1024 * 1024;

  /// 取最近 [limit] 条消息作为上下文。
  ///
  /// 起点会被向后推到第一条 `user` 消息：从 `assistant` / `tool` 中间切入会
  /// 破坏 `tool_calls` 与 `tool` 消息的配对，部分厂商会直接返回 400。
  /// 若截断后一条 `user` 都找不到（极端情况），退化为「全量返回」。
  static List<ChatMessage> build(
    List<ChatMessageRecord> records,
    int limit, {
    int attachmentBudgetBytes = defaultAttachmentBudgetBytes,
  }) {
    if (records.isEmpty) return const [];

    final safeLimit = limit <= 0 ? 1 : limit;
    var start = records.length > safeLimit ? records.length - safeLimit : 0;

    while (start < records.length &&
        records[start].role != ChatMessageRecord.roleUser) {
      start++;
    }
    if (start >= records.length) start = 0;

    final window = records.sublist(start);
    return _applyAttachmentBudget(
      _stripNonUserAttachments(window),
      attachmentBudgetBytes,
    ).map(ChatMessageMapper.toChatMessage).toList();
  }

  /// 只有 `user` 消息能把附件发给模型。
  ///
  /// 助手 / 工具消息上的附件是**给用户看的**（典型例子是 AI 生图的结果：
  /// 图片挂在助手消息上，或者跟着工具返回值一起落在工具消息上）。回传会被
  /// 多数厂商拒绝 —— OpenAI 兼容协议里图片只能出现在 user 消息中，而 `tool`
  /// 消息的 content 必须是字符串。直接在这里清掉，别让整包请求白跑一趟。
  static List<ChatMessageRecord> _stripNonUserAttachments(
    List<ChatMessageRecord> window,
  ) {
    var changed = false;
    final result = List<ChatMessageRecord>.from(window);
    for (var i = 0; i < result.length; i++) {
      if (result[i].role == ChatMessageRecord.roleUser) continue;
      final raw = result[i].attachmentsJson;
      if (raw.trim().isEmpty || raw.trim() == ChatMessageRecord.emptyJsonArray) {
        continue;
      }
      result[i] = result[i].copyWith(
        attachmentsJson: ChatMessageRecord.emptyJsonArray,
      );
      changed = true;
    }
    return changed ? result : window;
  }

  /// 从最新往旧累加附件字节；超预算的消息把附件置空（文本保留）。
  ///
  /// 最新一条带附件的消息**无论多大都保留** —— 用户刚发的附件必须发出去，
  /// 要裁就裁历史。
  static List<ChatMessageRecord> _applyAttachmentBudget(
    List<ChatMessageRecord> window,
    int budget,
  ) {
    final safeBudget = budget < 0 ? 0 : budget;
    final result = List<ChatMessageRecord>.from(window);
    var used = 0;
    var seenNewest = false;
    var dropped = false;

    for (var i = result.length - 1; i >= 0; i--) {
      final raw = result[i].attachmentsJson;
      if (raw.trim().isEmpty || raw.trim() == ChatMessageRecord.emptyJsonArray) {
        continue;
      }
      final size = _attachmentsSize(raw);

      if (!seenNewest) {
        seenNewest = true;
        used += size;
        continue;
      }

      if (used + size <= safeBudget) {
        used += size;
        continue;
      }

      result[i] = result[i].copyWith(
        attachmentsJson: ChatMessageRecord.emptyJsonArray,
      );
      dropped = true;
    }

    return dropped ? result : window;
  }

  /// 从 attachments JSON 里读出总字节数（不读磁盘，保持纯函数）
  static int _attachmentsSize(String json) {
    var total = 0;
    for (final a in ChatAttachment.decodeList(json)) {
      total += a.size;
    }
    return total;
  }
}
