import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/diary_entry.dart';
import '../../data/models/placed_audio.dart';
import '../../data/models/placed_image.dart';
import '../../data/repositories/diary_repository.dart';
import 'export_service.dart';

class ZipExportService {
  ZipExportService._();

  /// 导出完整备份为 ZIP 并唤起系统分享。
  ///
  /// 返回 [ShareResult] 供调用方区分「已发送」与「用户关掉面板没选」。
  static Future<ShareResult> exportAndShare() async {
    final repository = DiaryRepository();
    final entries = await repository.getAllEntries();

    // 1. 创建临时目录
    final tempDir = await getTemporaryDirectory();
    final backupDir = Directory('${tempDir.path}/diary_backup');
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
    await backupDir.create();

    final zipPath = '${tempDir.path}/diary_backup_${_dateStamp()}.zip';

    try {
      // 2. 复制图片 / 录音文件并重建路径映射
      final imagesDir = Directory('${backupDir.path}/images');
      await imagesDir.create();
      final processedEntries = await _processEntries(entries, backupDir);

      // 3. 写入 diary.json
      final diaryJson = const JsonEncoder.withIndent('  ').convert({
        'entries': processedEntries.map((e) => _entryToExportMap(e)).toList(),
      });
      await File('${backupDir.path}/diary.json').writeAsString(diaryJson);

      // 4. 写入 metadata.json
      final metadata = _buildMetadata(entries, await ExportService.appVersion());
      await File('${backupDir.path}/metadata.json').writeAsString(metadata);

      // 5. 压缩为 ZIP
      await _compressToZip(backupDir.path, zipPath);

      // 6. 分享
      return await Share.shareXFiles(
        [XFile(zipPath, mimeType: 'application/zip')],
        subject: p.basename(zipPath),
        text: '折花日记 · 完整备份',
      );
    } finally {
      // 7. 清理临时文件。
      //
      // ⚠️ 分享已经由 share_plus 把 ZIP **复制**到 `cacheDir/share_plus/` 再交给
      // 系统面板（见 Share.kt:copyToShareCacheFolder），所以这里删掉原件不会
      // 影响接收方读取。而 ZIP 原件之前一直没人清理，会在缓存目录里越堆越多。
      await _deleteQuietly(backupDir);
      await _deleteQuietly(File(zipPath));
    }
  }

  static Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) {
        await entity.delete(recursive: true);
      }
    } catch (_) {
      // 清理失败不影响导出结果，交给系统缓存回收
    }
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

  /// 压缩目录为 ZIP（**流式**写入）。
  ///
  /// ⚠️ 不要改回「把所有文件 `readAsBytes` 塞进 `Archive` 再 `ZipEncoder().encode()`」：
  /// 那样峰值内存 ≈ 备份总量 × 2，日记媒体攒到几百 MB 时会在低端机上
  /// **OOM 闪退**，而且崩在导出中途、用户已经等了很久。
  ///
  /// `ZipFileEncoder.addFile` 是「读一个 → 压一个 → 写一个」，
  /// 峰值内存降到**单个最大文件**的量级。
  static Future<void> _compressToZip(String sourceDir, String zipPath) async {
    final normalizedSourceDir = sourceDir.replaceAll('\\', '/');
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    try {
      await for (final entity in Directory(sourceDir).list(recursive: true)) {
        if (entity is! File) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        final relativePath =
            normalized.replaceFirst('$normalizedSourceDir/', '');
        // 显式传 `filename`：ZipFileEncoder 默认走 path.relative，
        // 在 Windows 上会生成 `images\1\img_1.jpg` 这种反斜杠路径，
        // 而 ZIP 规范要求 `/` —— 在 Android 上解包时会变成一个奇怪的文件名。
        await encoder.addFile(File(entity.path), relativePath);
      }
    } finally {
      await encoder.close();
    }
  }

  /// 构建元数据 JSON
  static String _buildMetadata(List<DiaryEntry> entries, String version) {
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
      'version': version,
      'exported_at': DateTime.now().toIso8601String(),
      'entries_count': entries.length,
      'total_images': totalImages,
      'total_audios': totalAudios,
      'has_stickers': hasStickers,
    });
  }

  /// 条目 → 导出 map。
  ///
  /// ⚠️ 这里是**手搓**的 map，和 `ExportService._renderJson()` 用的
  /// `DiaryEntry.toMap()` 是两套结构 —— 任何一侧加字段，另一侧都要跟着改，
  /// 否则就会出现「某格式备份丢字段」。
  /// 曾漏掉 `is_locked` / `pin_hash`，导致**加锁日记恢复后锁失效**
  /// （`DiaryAccess.verify` 在 hash 为空时直接放行），必须保持同步。
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
      'is_locked': entry.isLocked,
      // pinHash 是自包含的 `salt:sha256(salt+pin)`，跨设备可校验，
      // 所以导出它是安全的；不导出则会退化成「显示有锁、点开就进」的假锁。
      'pin_hash': entry.pinHash,
      'tags': entry.tags,
      'images': entry.images.map((img) => img.toJson()).toList(),
      'audios': entry.audios.map((a) => a.toJson()).toList(),
      'stickers': entry.stickers.map((s) => s.toJson()).toList(),
      'created_at': entry.createdAt.toIso8601String(),
      'updated_at': entry.updatedAt.toIso8601String(),
      'weather': entry.weather,
      'location': entry.location,
    };
  }

  static String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }
}
