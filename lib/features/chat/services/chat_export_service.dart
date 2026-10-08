import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/chat_message_record.dart';
import 'chat_exporter.dart';

/// 会话导出：渲染 → 落临时文件 → 调系统分享。
///
/// 渲染规则全在 [ChatExporter]（纯 Dart，可离线测），这里只负责碰文件系统与插件。
class ChatExportService {
  ChatExportService._();

  /// 导出并唤起系统分享。
  ///
  /// 返回写出的文件路径；调用方一般不需要，但测试 / 提示会用到。
  /// 失败**抛异常** —— 导出是有明确用户动作的，静默失败比报错更糟。
  static Future<String> exportAndShare({
    required String title,
    required List<ChatMessageRecord> messages,
    ChatExportFormat format = ChatExportFormat.markdown,
    bool includeReasoning = false,
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final content = ChatExporter.render(
      title: title,
      messages: messages,
      format: format,
      now: stamp,
      includeReasoning: includeReasoning,
    );

    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'chat_export'));
    if (!await dir.exists()) await dir.create(recursive: true);

    // 只留最近一次导出的文件，避免临时目录越堆越多
    await for (final entity in dir.list()) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {
          // 正在被分享面板占用就跳过
        }
      }
    }

    final name = ChatExporter.fileName(
      title: title,
      format: format,
      now: stamp,
    );
    final file = File(p.join(dir.path, name));
    await file.writeAsString(content, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: _mimeOf(format))],
      subject: name,
      text: '折花日记 · AI 对话导出',
    );
    return file.path;
  }

  static String _mimeOf(ChatExportFormat format) {
    switch (format) {
      case ChatExportFormat.markdown:
        return 'text/markdown';
      case ChatExportFormat.plainText:
        return 'text/plain';
      case ChatExportFormat.json:
        return 'application/json';
    }
  }
}
