import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/repositories/diary_repository.dart';

class ExportService {
  ExportService._();

  static Future<String> exportToJson() async {
    final repository = DiaryRepository();
    final entries = await repository.getAllEntries();
    final jsonList = entries.map((e) => e.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert({
      'app': 'diary_app',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'entries_count': entries.length,
      'entries': jsonList,
    });

    final directory = await getApplicationDocumentsDirectory();
    final dateStamp = _dateStamp();
    final path = '${directory.path}/diary_backup_$dateStamp.json';
    final file = File(path);
    await file.writeAsString(jsonString);
    return path;
  }

  static Future<String> exportToMarkdown() async {
    final repository = DiaryRepository();
    final entries = await repository.getAllEntries();

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

    final directory = await getApplicationDocumentsDirectory();
    final dateStamp = _dateStamp();
    final path = '${directory.path}/diary_backup_$dateStamp.md';
    await File(path).writeAsString(buffer.toString());
    return path;
  }

  static Future<String> exportToTxt() async {
    final repository = DiaryRepository();
    final entries = await repository.getAllEntries();

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

    final directory = await getApplicationDocumentsDirectory();
    final dateStamp = _dateStamp();
    final path = '${directory.path}/diary_backup_$dateStamp.txt';
    await File(path).writeAsString(buffer.toString());
    return path;
  }

  static String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }
}
