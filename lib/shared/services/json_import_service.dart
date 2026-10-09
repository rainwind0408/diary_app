import 'dart:convert';
import 'dart:io';

import '../../data/repositories/diary_repository.dart';
import 'backup_parsing.dart';

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

      final entries = jsonData['entries'];
      if (entries is! List || entries.isEmpty) {
        return ImportResult(0, 0, ['备份文件中没有日记数据']);
      }

      // 3. 逐条导入
      for (final entryMap in entries) {
        try {
          // 解析规则统一在 BackupParsing.entryFromMap —— 它与 ZIP 导入共用一份，
          // 避免两边各写一套、改一边漏一边（历史上就是这么漏掉 tags 的）。
          //
          // 媒体：JSON 备份里只有图片 / 录音的**路径元信息**，不含二进制文件，
          // 所以这里无法还原。要连媒体一起备份请用「完整备份 ZIP」。
          final entry = BackupParsing.entryFromMap(
            entryMap as Map<String, dynamic>,
          );
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
