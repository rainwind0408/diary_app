/// 会话导出（纯 Dart）。
///
/// 只依赖 dart:convert + data 层模型，不引入 Flutter —— 渲染规则（跳过工具消息、
/// 附件怎么标、时间怎么排）全都值得单测，而它们一旦错了，用户导出来的东西
/// 自己也不会去逐条核对。
library;

import 'dart:convert';

import '../../../data/models/chat_message_record.dart';
import '../models/chat_attachment.dart';

/// 导出格式
enum ChatExportFormat {
  markdown,
  plainText,
  json;

  String get label {
    switch (this) {
      case ChatExportFormat.markdown:
        return 'Markdown';
      case ChatExportFormat.plainText:
        return '纯文本';
      case ChatExportFormat.json:
        return 'JSON';
    }
  }

  String get hint {
    switch (this) {
      case ChatExportFormat.markdown:
        return '保留标题与列表，适合贴进笔记软件';
      case ChatExportFormat.plainText:
        return '没有任何标记符号，适合发消息或粘贴';
      case ChatExportFormat.json:
        return '结构化数据，含附件与思考过程，适合备份或二次处理';
    }
  }

  /// 文件扩展名（不含点）
  String get extension {
    switch (this) {
      case ChatExportFormat.markdown:
        return 'md';
      case ChatExportFormat.plainText:
        return 'txt';
      case ChatExportFormat.json:
        return 'json';
    }
  }
}

class ChatExporter {
  ChatExporter._();

  /// 把一段会话渲染成文本。
  ///
  /// [includeReasoning] 只对 markdown / 纯文本生效 —— JSON 是数据导出，
  /// 永远带上思考过程与附件原始字段。
  static String render({
    required String title,
    required List<ChatMessageRecord> messages,
    required ChatExportFormat format,
    DateTime? now,
    bool includeReasoning = false,
    bool includeTools = false,
  }) {
    final exportedAt = now ?? DateTime.now();
    final kept = _visibleMessages(messages, includeTools: includeTools);

    switch (format) {
      case ChatExportFormat.json:
        return _renderJson(title, kept, exportedAt);
      case ChatExportFormat.markdown:
        return _renderMarkdown(
          title,
          kept,
          exportedAt,
          includeReasoning: includeReasoning,
        );
      case ChatExportFormat.plainText:
        return _renderPlainText(
          title,
          kept,
          exportedAt,
          includeReasoning: includeReasoning,
        );
    }
  }

  /// 导出文件名（不含目录）。例：`折花日记_AI对话_最近心情_20261004_1930.md`
  static String fileName({
    required String title,
    required ChatExportFormat format,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final stamp = '${t.year}${_two(t.month)}${_two(t.day)}'
        '_${_two(t.hour)}${_two(t.minute)}';
    final safe = sanitizeFileName(title.trim());
    final middle = safe.isEmpty ? '' : '_$safe';
    return '折花日记_AI对话$middle' '_$stamp.${format.extension}';
  }

  /// 文件名里不能出现的字符统一换成下划线；过长就截断（Android 有 255 字节上限，
  /// 中文按 3 字节算，60 字已经到 180 字节，够用了）。
  static String sanitizeFileName(String raw, {int maxChars = 60}) {
    var s = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // 开头的点会被当成隐藏文件
    while (s.startsWith('.')) {
      s = s.substring(1);
    }
    if (s.length > maxChars) s = s.substring(0, maxChars).trim();
    return s;
  }

  // ─────────────────────────────────────────────
  // 内部
  // ─────────────────────────────────────────────

  /// 挑出真正要导出的消息。
  ///
  /// 默认丢掉：
  /// - `tool` 消息（工具原始返回，是给模型看的，不是对话内容）
  /// - 空内容的助手占位消息（只有 tool_calls、正文为空的那些）
  static List<ChatMessageRecord> _visibleMessages(
    List<ChatMessageRecord> messages, {
    required bool includeTools,
  }) {
    return messages.where((m) {
      if (m.isTool && !includeTools) return false;
      final hasText = m.content.trim().isNotEmpty;
      final hasAttachments =
          ChatAttachment.decodeList(m.attachmentsJson).isNotEmpty;
      return hasText || hasAttachments;
    }).toList();
  }

  static String _renderMarkdown(
    String title,
    List<ChatMessageRecord> messages,
    DateTime exportedAt, {
    required bool includeReasoning,
  }) {
    final buf = StringBuffer()
      ..writeln('# ${title.trim().isEmpty ? 'AI 对话' : title.trim()}')
      ..writeln()
      ..writeln('> 导出时间：${_stamp(exportedAt)}　·　共 ${messages.length} 条消息')
      ..writeln();

    if (messages.isEmpty) {
      buf.writeln('_（这段会话里还没有内容）_');
      return buf.toString();
    }

    for (final m in messages) {
      buf
        ..writeln('## ${_speaker(m)}　·　${_stamp(m.createdAt)}')
        ..writeln();

      if (includeReasoning && m.hasReasoning) {
        buf
          ..writeln('<details><summary>思考过程</summary>')
          ..writeln()
          ..writeln(m.reasoning.trim())
          ..writeln()
          ..writeln('</details>')
          ..writeln();
      }

      if (m.content.trim().isNotEmpty) {
        buf
          ..writeln(m.content.trim())
          ..writeln();
      }

      for (final a in ChatAttachment.decodeList(m.attachmentsJson)) {
        buf.writeln('- 附件：${a.kind.label}　`${a.name}`');
      }
      if (ChatAttachment.decodeList(m.attachmentsJson).isNotEmpty) {
        buf.writeln();
      }
    }
    return buf.toString();
  }

  static String _renderPlainText(
    String title,
    List<ChatMessageRecord> messages,
    DateTime exportedAt, {
    required bool includeReasoning,
  }) {
    final buf = StringBuffer()
      ..writeln(title.trim().isEmpty ? 'AI 对话' : title.trim())
      ..writeln('导出时间：${_stamp(exportedAt)}　共 ${messages.length} 条消息')
      ..writeln();

    if (messages.isEmpty) {
      buf.writeln('（这段会话里还没有内容）');
      return buf.toString();
    }

    for (final m in messages) {
      buf
        ..writeln('【${_speaker(m)}】${_stamp(m.createdAt)}');

      if (includeReasoning && m.hasReasoning) {
        buf
          ..writeln('（思考过程）')
          ..writeln(m.reasoning.trim());
      }

      if (m.content.trim().isNotEmpty) {
        buf.writeln(m.content.trim());
      }

      for (final a in ChatAttachment.decodeList(m.attachmentsJson)) {
        buf.writeln('（附件：${a.kind.label} ${a.name}）');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  static String _renderJson(
    String title,
    List<ChatMessageRecord> messages,
    DateTime exportedAt,
  ) {
    final data = <String, dynamic>{
      'app': 'diary_app',
      'kind': 'ai_chat',
      'title': title.trim().isEmpty ? 'AI 对话' : title.trim(),
      'exported_at': exportedAt.toIso8601String(),
      'message_count': messages.length,
      'messages': messages
          .map(
            (m) => <String, dynamic>{
              'role': m.role,
              'content': m.content,
              if (m.reasoning.trim().isNotEmpty) 'reasoning': m.reasoning,
              if (m.toolName.isNotEmpty) 'tool_name': m.toolName,
              'status': m.status,
              'created_at': m.createdAt.toIso8601String(),
              'attachments': ChatAttachment.decodeList(m.attachmentsJson)
                  .map(
                    (a) => <String, dynamic>{
                      'kind': a.kind.name,
                      'name': a.name,
                      'path': a.path,
                      'mime': a.mimeType,
                      'size': a.size,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 说话人显示名。工具消息只有在显式要求导出时才出现。
  static String _speaker(ChatMessageRecord m) {
    if (m.isUser) return '我';
    if (m.isAssistant) return 'AI 助手';
    if (m.isTool) {
      return m.toolName.isEmpty ? '工具' : '工具 · ${m.toolName}';
    }
    return m.role;
  }

  static String _stamp(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
