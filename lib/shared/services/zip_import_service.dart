import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/placed_audio.dart';
import '../../data/models/placed_image.dart';
import '../../data/repositories/diary_repository.dart';
import 'backup_parsing.dart';
import 'json_import_service.dart';

class ZipImportService {
  ZipImportService._();

  /// 从 ZIP 文件导入日记
  static Future<ImportResult> importFromZip(String zipPath) async {
    final repository = DiaryRepository();
    int importedCount = 0;
    int skippedCount = 0;
    final errors = <String>[];

    try {
      // 1. 读取 ZIP 文件
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // 2. 解压到临时目录
      final tempDir = await getTemporaryDirectory();
      final extractDir = Directory('${tempDir.path}/diary_import');
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create();

      for (final file in archive) {
        final filePath = '${extractDir.path}/${file.name}';
        if (file.isFile) {
          final outDir = Directory(File(filePath).parent.path);
          if (!await outDir.exists()) {
            await outDir.create(recursive: true);
          }
          // 获取文件内容并写入
          final content = file.content;
          if (content != null) {
            await File(filePath).writeAsBytes(content as List<int>);
          }
        }
      }

      // 3. 读取 diary.json
      final diaryJsonFile = File('${extractDir.path}/diary.json');
      if (!await diaryJsonFile.exists()) {
        return ImportResult(0, 0, ['ZIP 包中缺少 diary.json']);
      }

      final diaryData = jsonDecode(await diaryJsonFile.readAsString());
      final entries = diaryData['entries'] as List;

      // 4. 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();

      // 5. 逐条导入
      for (final entryMap in entries) {
        try {
          // 复制图片到应用目录
          final newImages = <PlacedImage>[];
          for (final imgData in (entryMap['images'] as List? ?? [])) {
            final zipPath = (imgData['path'] as String).replaceAll('\\', '/');
            final normalizedExtractDir = extractDir.path.replaceAll('\\', '/');
            final srcFile = File('$normalizedExtractDir/$zipPath');
            if (await srcFile.exists()) {
              final fileName = zipPath.split('/').last;
              final destPath = '${appDir.path}/diary_images/$fileName';
              final destDir = Directory('${appDir.path}/diary_images');
              if (!await destDir.exists()) await destDir.create();
              await srcFile.copy(destPath);
              newImages.add(PlacedImage(
                path: 'diary_images/$fileName',
                dx: BackupParsing.doubleValue(imgData['dx']),
                dy: BackupParsing.doubleValue(imgData['dy']),
                width: BackupParsing.doubleValue(imgData['width']),
                height: BackupParsing.doubleValue(imgData['height']),
                rotation: BackupParsing.doubleValue(imgData['rotation']),
                scale: BackupParsing.doubleValue(imgData['scale'], fallback: 1),
              ));
            }
          }

          // 复制录音到应用目录
          final newAudios = <PlacedAudio>[];
          for (final audioData in (entryMap['audios'] as List? ?? [])) {
            final zipPath = (audioData['path'] as String).replaceAll('\\', '/');
            final normalizedExtractDir = extractDir.path.replaceAll('\\', '/');
            final srcFile = File('$normalizedExtractDir/$zipPath');
            if (await srcFile.exists()) {
              final fileName = zipPath.split('/').last;
              final destPath = '${appDir.path}/diary_audio/$fileName';
              final destDir = Directory('${appDir.path}/diary_audio');
              if (!await destDir.exists()) await destDir.create();
              await srcFile.copy(destPath);
              newAudios.add(PlacedAudio(
                path: 'diary_audio/$fileName',
                durationMs: BackupParsing.intValue(audioData['durationMs']),
                createdAt: audioData['createdAt'] != null
                    ? DateTime.tryParse(audioData['createdAt'].toString()) ??
                        DateTime.now()
                    : DateTime.now(),
                dx: BackupParsing.doubleValue(audioData['dx']),
                dy: BackupParsing.doubleValue(audioData['dy']),
                width: BackupParsing.doubleValue(audioData['width'],
                    fallback: 220),
                height: BackupParsing.doubleValue(audioData['height'],
                    fallback: 80),
                pageIndex: BackupParsing.intValue(audioData['pageIndex']),
              ));
            }
          }

          // 创建日记条目。
          // 字段解析统一在 BackupParsing.entryFromMap —— 与 JSON 导入共用一份，
          // 避免两边各写一套、改一边漏一边。
          final entry = BackupParsing.entryFromMap(
            entryMap as Map<String, dynamic>,
            images: newImages,
            audios: newAudios,
          );

          await repository.insertEntry(entry);
          importedCount++;
        } catch (e) {
          skippedCount++;
          errors.add('导入日记失败: $e');
        }
      }

      // 6. 清理临时文件
      await extractDir.delete(recursive: true);

      return ImportResult(importedCount, skippedCount, errors);
    } catch (e) {
      return ImportResult(0, 0, ['ZIP 解压失败: $e']);
    }
  }
}
