import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/models/diary_entry.dart';
import '../../data/repositories/diary_repository.dart';

/// 可导出的**纯文字**格式。
///
/// ⚠️ 与「完整备份 ZIP」区分：这三种都**不含图片与录音**，
/// 导入时 `images` / `audios` 一律忽略（见 `JsonImportService`）。
/// 要连媒体一起备份，只能用 `ZipExportService`。
enum DiaryExportFormat {
  json(extension: 'json', mimeType: 'application/json', label: 'JSON'),
  markdown(extension: 'md', mimeType: 'text/markdown', label: 'Markdown'),
  txt(extension: 'txt', mimeType: 'text/plain', label: 'TXT');

  const DiaryExportFormat({
    required this.extension,
    required this.mimeType,
    required this.label,
  });

  final String extension;
  final String mimeType;
  final String label;
}

class ExportService {
  ExportService._();

  /// 导出目录：落在**缓存目录**下。
  ///
  /// ⚠️ 这里**不能**用 `getApplicationDocumentsDirectory()`：它在 Android 上返回
  /// 应用私有目录（`/data/user/0/com.example.diary_app/…`），用户用任何文件管理器
  /// 都看不到。之前导出的文件就是丢在那儿 —— 用户点完「导出」、看到
  /// 「导出成功：/data/user/0/…」，却永远找不到这个文件，等于没导出。
  ///
  /// 放缓存目录后，配合 [exportAndShare] 走系统分享面板，用户就能
  /// 「保存到文件 / 发送给其他应用」了。
  static Future<Directory> _exportDir() async {
    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'diary_export'),
    );
    // 只保留最近一次导出，避免缓存目录越堆越多
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    return dir;
  }

  /// 当前 App 版本号（如 `1.1.1`）。
  ///
  /// 取不到时回落 `unknown` —— 版本号只是备份文件的元信息，
  /// 不该因为它取不到就让整个导出失败。
  static Future<String> appVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return 'unknown';
    }
  }

  /// 生成导出文件并返回其路径。**只落盘，不分享。**
  static Future<String> export(DiaryExportFormat format) async {
    final entries = await DiaryRepository().getAllEntries();
    final version = await appVersion();
    final dir = await _exportDir();
    final path = p.join(
      dir.path,
      'diary_backup_${_dateStamp()}.${format.extension}',
    );

    late final String content;
    switch (format) {
      case DiaryExportFormat.json:
        content = _renderJson(entries, version);
      case DiaryExportFormat.markdown:
        content = _renderMarkdown(entries);
      case DiaryExportFormat.txt:
        content = _renderTxt(entries);
    }

    await File(path).writeAsString(content, flush: true);
    return path;
  }

  /// 导出并唤起系统分享面板。
  ///
  /// 这是导出功能**唯一正确的出口**：只落盘不分享的话，文件待在用户看不见的
  /// 缓存目录里，用户拿不到，功能等于不存在。
  ///
  /// `share_plus` 会把文件复制到 `cacheDir/share_plus/` 再交给系统，
  /// 所以分享面板里能选「保存到文件」「发送到微信」等任意目标。
  ///
  /// 返回 [ShareResult] 供调用方区分「已发送」与「用户关掉面板没选」。
  static Future<ShareResult> exportAndShare(DiaryExportFormat format) async {
    final path = await export(format);
    return Share.shareXFiles(
      [XFile(path, mimeType: format.mimeType)],
      subject: p.basename(path),
      text: '折花日记 · ${format.label} 导出',
    );
  }

  static String _renderJson(List<DiaryEntry> entries, String version) {
    // 直接复用 DiaryEntry.toJson()（= toMap()），它会带上
    // is_locked / pin_hash / weather / location。
    // ⚠️ 注意 tags / images / audios / stickers 经 toMap 会被 jsonEncode 成
    // **字符串**，导入侧必须用 BackupParsing 兼容解析。
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'diary_app',
      'version': version,
      'exported_at': DateTime.now().toIso8601String(),
      'entries_count': entries.length,
      'entries': entries.map((e) => e.toJson()).toList(),
    });
  }

  static String _renderMarkdown(List<DiaryEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln('# 我的日记本');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    for (final entry in entries) {
      final dateStr = DateFormatter.formatFull(entry.createdAt);
      final mood = entry.mood.isNotEmpty ? ' ${entry.mood}' : '';
      final words = '${entry.wordCount}字';
      buffer.writeln('## $dateStr$mood | $words');
      buffer.writeln();
      if (entry.title.isNotEmpty) {
        buffer.writeln('### ${entry.title}');
        buffer.writeln();
      }
      buffer.writeln(entry.content);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }
    return buffer.toString();
  }

  static String _renderTxt(List<DiaryEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('           我的日记本');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln();

    for (final entry in entries) {
      final dateStr = DateFormatter.formatFull(entry.createdAt);
      final mood = entry.mood.isNotEmpty ? '  ${entry.mood}' : '';
      final words = '${entry.wordCount}字';
      buffer.writeln('═══════════════════════════════════════');
      buffer.writeln('  $dateStr$mood  $words');
      buffer.writeln('═══════════════════════════════════════');
      buffer.writeln();
      if (entry.title.isNotEmpty) {
        buffer.writeln('【${entry.title}】');
        buffer.writeln();
      }
      buffer.writeln(entry.content);
      buffer.writeln();
      buffer.writeln('───────────────────────────────────────');
      buffer.writeln();
    }
    return buffer.toString();
  }

  static String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }
}
