import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/diary_entry.dart';
import '../../data/models/placed_image.dart';
import '../../data/models/placed_audio.dart';
import '../../data/repositories/diary_repository.dart';
import '../../features/stickers/models/placed_sticker.dart';
import 'json_import_service.dart';

class ZipImportService {
  ZipImportService._();

  /// 解析标签，兼容 List 和 String 两种格式
  static List<String> _parseTags(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.cast<String>();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.cast<String>();
      } catch (_) {}
    }
    return [];
  }

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
                dx: (imgData['dx'] as num).toDouble(),
                dy: (imgData['dy'] as num).toDouble(),
                width: (imgData['width'] as num).toDouble(),
                height: (imgData['height'] as num).toDouble(),
                rotation: (imgData['rotation'] as num?)?.toDouble() ?? 0,
                scale: (imgData['scale'] as num?)?.toDouble() ?? 1.0,
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
                durationMs: (audioData['durationMs'] as num?)?.toInt() ?? 0,
                createdAt: audioData['createdAt'] != null
                    ? DateTime.parse(audioData['createdAt'])
                    : DateTime.now(),
                dx: (audioData['dx'] as num?)?.toDouble() ?? 0,
                dy: (audioData['dy'] as num?)?.toDouble() ?? 0,
                width: (audioData['width'] as num?)?.toDouble() ?? 220,
                height: (audioData['height'] as num?)?.toDouble() ?? 80,
                pageIndex: (audioData['pageIndex'] as num?)?.toInt() ?? 0,
              ));
            }
          }

          // 解析贴纸
          final stickers = <PlacedSticker>[];
          for (final stickerData in (entryMap['stickers'] as List? ?? [])) {
            if (stickerData is Map<String, dynamic>) {
              stickers.add(PlacedSticker.fromJson(stickerData));
            }
          }

          // 创建日记条目
          final entry = DiaryEntry(
            title: entryMap['title'] ?? '无标题',
            content: entryMap['content'] ?? '',
            mood: entryMap['mood'] ?? '',
            moodIntensity: entryMap['mood_intensity'] ?? 3,
            moodNote: entryMap['mood_note'] ?? '',
            moodLabel: entryMap['mood_label'] ?? '',
            wordCount: entryMap['word_count'] ?? 0,
            tags: _parseTags(entryMap['tags']),
            images: newImages,
            audios: newAudios,
            stickers: stickers,
            createdAt: DateTime.parse(entryMap['created_at']),
            updatedAt: DateTime.parse(entryMap['updated_at']),
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
