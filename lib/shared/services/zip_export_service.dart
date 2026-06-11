import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/repositories/diary_repository.dart';
import '../../data/models/diary_entry.dart';
import '../../data/models/placed_image.dart';
import '../../data/models/placed_audio.dart';

class ZipExportService {
  ZipExportService._();

  /// 导出完整备份为 ZIP 并分享
  static Future<void> exportAndShare() async {
    final repository = DiaryRepository();
    final entries = await repository.getAllEntries();

    // 1. 创建临时目录
    final tempDir = await getTemporaryDirectory();
    final backupDir = Directory('${tempDir.path}/diary_backup');
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
    await backupDir.create();

    // 2. 复制图片文件并重建路径映射
    final imagesDir = Directory('${backupDir.path}/images');
    await imagesDir.create();
    final processedEntries = await _processEntries(entries, backupDir);

    // 3. 写入 diary.json
    final diaryJson = const JsonEncoder.withIndent('  ').convert({
      'entries': processedEntries.map((e) => _entryToExportMap(e)).toList(),
    });
    await File('${backupDir.path}/diary.json').writeAsString(diaryJson);

    // 4. 写入 metadata.json
    final metadata = _buildMetadata(entries);
    await File('${backupDir.path}/metadata.json').writeAsString(metadata);

    // 5. 压缩为 ZIP
    final zipPath = '${tempDir.path}/diary_backup_${_dateStamp()}.zip';
    await _compressToZip(backupDir.path, zipPath);

    // 6. 分享
    await Share.shareXFiles([XFile(zipPath)], text: '日记备份');

    // 7. 清理临时文件
    await backupDir.delete(recursive: true);
  }

  /// 处理条目：复制媒体文件到备份目录
  static Future<List<DiaryEntry>> _processEntries(
    List<DiaryEntry> entries,
    Directory backupDir,
  ) async {
    final processed = <DiaryEntry>[];
    final appDir = await getApplicationDocumentsDirectory();

    for (final entry in entries) {
      final entryId = entry.id ?? 0;
      final newImages = <PlacedImage>[];
      final newAudios = <PlacedAudio>[];

      // 复制图片
      if (entry.images.isNotEmpty) {
        final entryImagesDir = Directory('${backupDir.path}/images/$entryId');
        await entryImagesDir.create(recursive: true);

        for (int i = 0; i < entry.images.length; i++) {
          final img = entry.images[i];
          // 构建源文件路径
          String srcPath;
          if (img.path.startsWith(appDir.path)) {
            // 已经是完整路径
            srcPath = img.path;
          } else {
            // 相对路径，需要拼接
            srcPath = '${appDir.path}/${img.path}';
          }
          final srcFile = File(srcPath);
          if (await srcFile.exists()) {
            final ext = img.path.split('.').last;
            final newPath = '${entryImagesDir.path}/img_${i + 1}.$ext';
            await srcFile.copy(newPath);
            newImages.add(PlacedImage(
              path: 'images/$entryId/img_${i + 1}.$ext',
              dx: img.dx,
              dy: img.dy,
              width: img.width,
              height: img.height,
              rotation: img.rotation,
              scale: img.scale,
            ));
          }
        }
      }

      // 复制录音
      if (entry.audios.isNotEmpty) {
        final entryAudioDir = Directory('${backupDir.path}/audio/$entryId');
        await entryAudioDir.create(recursive: true);

        for (int i = 0; i < entry.audios.length; i++) {
          final audio = entry.audios[i];
          // 构建源文件路径
          String srcPath;
          if (audio.path.startsWith(appDir.path)) {
            // 已经是完整路径
            srcPath = audio.path;
          } else {
            // 相对路径，需要拼接
            srcPath = '${appDir.path}/${audio.path}';
          }
          final srcFile = File(srcPath);
          if (await srcFile.exists()) {
            final newPath = '${entryAudioDir.path}/rec_${i + 1}.m4a';
            await srcFile.copy(newPath);
            newAudios.add(PlacedAudio(
              path: 'audio/$entryId/rec_${i + 1}.m4a',
              durationMs: audio.durationMs,
              createdAt: audio.createdAt,
              dx: audio.dx,
              dy: audio.dy,
              width: audio.width,
              height: audio.height,
              pageIndex: audio.pageIndex,
            ));
          }
        }
      }

      processed.add(entry.copyWith(
        images: newImages,
        audios: newAudios,
      ));
    }

    return processed;
  }

  /// 压缩目录为 ZIP
  static Future<void> _compressToZip(String sourceDir, String zipPath) async {
    final archive = Archive();
    final dir = Directory(sourceDir);

    // 统一路径分隔符为 /
    final normalizedSourceDir = sourceDir.replaceAll('\\', '/');

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final normalizedEntityPath = entity.path.replaceAll('\\', '/');
        final relativePath = normalizedEntityPath.replaceFirst('$normalizedSourceDir/', '');
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }
    }

    final zipData = ZipEncoder().encode(archive);
    await File(zipPath).writeAsBytes(zipData!);
  }

  /// 构建元数据 JSON
  static String _buildMetadata(List<DiaryEntry> entries) {
    int totalImages = 0;
    int totalAudios = 0;
    bool hasStickers = false;

    for (final entry in entries) {
      totalImages += entry.images.length;
      totalAudios += entry.audios.length;
      if (entry.stickers.isNotEmpty) hasStickers = true;
    }

    return const JsonEncoder.withIndent('  ').convert({
      'app': 'diary_app',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'entries_count': entries.length,
      'total_images': totalImages,
      'total_audios': totalAudios,
      'has_stickers': hasStickers,
    });
  }

  static Map<String, dynamic> _entryToExportMap(DiaryEntry entry) {
    return {
      'id': entry.id,
      'title': entry.title,
      'content': entry.content,
      'mood': entry.mood,
      'mood_intensity': entry.moodIntensity,
      'mood_note': entry.moodNote,
      'mood_label': entry.moodLabel,
      'word_count': entry.wordCount,
      'tags': entry.tags,
      'images': entry.images.map((img) => img.toJson()).toList(),
      'audios': entry.audios.map((a) => a.toJson()).toList(),
      'stickers': entry.stickers.map((s) => s.toJson()).toList(),
      'created_at': entry.createdAt.toIso8601String(),
      'updated_at': entry.updatedAt.toIso8601String(),
    };
  }

  static String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }
}
