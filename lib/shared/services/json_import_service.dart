import 'dart:io';
import 'dart:convert';
import '../../data/models/diary_entry.dart';
import '../../data/repositories/diary_repository.dart';
import '../../features/stickers/models/placed_sticker.dart';

class JsonImportService {
  JsonImportService._();

  /// 从 JSON 文件导入日记
  /// 返回导入结果
  static Future<ImportResult> importFromJson(String jsonPath) async {
    final repository = DiaryRepository();
    int importedCount = 0;
    int skippedCount = 0;
    final errors = <String>[];

    try {
      // 1. 读取 JSON 文件
      final file = File(jsonPath);
      if (!await file.exists()) {
        return ImportResult(0, 0, ['文件不存在']);
      }

      final jsonStr = await file.readAsString();
      final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;

      // 2. 校验格式
      if (jsonData['app'] != 'diary_app') {
        return ImportResult(0, 0, ['无效的备份文件：app 标识不匹配']);
      }

      final entries = jsonData['entries'] as List;
      if (entries.isEmpty) {
        return ImportResult(0, 0, ['备份文件中没有日记数据']);
      }

      // 3. 逐条导入
      for (final entryMap in entries) {
        try {
          final entry = _parseEntry(entryMap as Map<String, dynamic>);
          await repository.insertEntry(entry);
          importedCount++;
        } catch (e) {
          skippedCount++;
          errors.add('导入日记失败: $e');
        }
      }

      return ImportResult(importedCount, skippedCount, errors);
    } catch (e) {
      return ImportResult(0, 0, ['JSON 解析失败: $e']);
    }
  }

  /// 解析日记条目
  static DiaryEntry _parseEntry(Map<String, dynamic> map) {
    return DiaryEntry(
      title: (map['title'] as String?) ?? '无标题',
      content: (map['content'] as String?) ?? '',
      mood: (map['mood'] as String?) ?? '',
      moodIntensity: (map['mood_intensity'] as int?) ?? 3,
      moodNote: (map['mood_note'] as String?) ?? '',
      moodLabel: (map['mood_label'] as String?) ?? '',
      wordCount: (map['word_count'] as int?) ?? 0,
      tags: (map['tags'] as List?)?.cast<String>() ?? [],
      images: const [], // JSON 导入不支持图片
      audios: const [], // JSON 导入不支持录音
      stickers: _parseStickers(map['stickers']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  static List<PlacedSticker> _parseStickers(dynamic raw) {
    if (raw == null || raw is! List) return [];
    return raw.map((item) {
      if (item is Map<String, dynamic>) {
        return PlacedSticker.fromJson(item);
      }
      return PlacedSticker(
        stickerId: '',
        emoji: '',
      );
    }).toList();
  }
}

/// 导入结果
class ImportResult {
  final int importedCount;
  final int skippedCount;
  final List<String> errors;

  ImportResult(this.importedCount, this.skippedCount, this.errors);

  bool get success => errors.isEmpty;
  int get total => importedCount + skippedCount;
}
