import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/chat_attachment.dart';

/// 附件本地存储。
///
/// 选择器（image_picker / file_selector）返回的是**临时缓存路径**，系统随时可能清理，
/// 所以必须复制进应用私有目录后再入库，否则历史消息里的附件过几天就变成裂图。
class AttachmentStore {
  AttachmentStore._();

  static const String dirName = 'chat_attachments';

  /// 单个附件大小上限。
  ///
  /// base64 后体积约为原始的 1.37 倍，10MB 原文件 ≈ 13.7MB 请求体；再大就很容易
  /// 在拼 JSON 时把内存打爆。这是**输入侧保护**，不是能力降级。
  static const int maxBytes = 10 * 1024 * 1024;

  static Directory? _cached;

  static Future<Directory> directory() async {
    final cached = _cached;
    if (cached != null) return cached;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cached = dir;
    return dir;
  }

  /// 导入外部文件到私有目录，返回落盘后的附件信息。
  ///
  /// 超过 [maxBytes] 抛 [AttachmentTooLargeException]。
  static Future<ChatAttachment> import(
    String sourcePath, {
    String? name,
    String? mimeType,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('文件不存在：$sourcePath');
    }
    final length = await file.length();
    final displayName = name ?? p.basename(sourcePath);

    if (length > maxBytes) {
      throw AttachmentTooLargeException(
        name: displayName,
        size: length,
        limit: maxBytes,
      );
    }

    final dir = await directory();
    final ext = p.extension(sourcePath);
    final target = p.join(dir.path, '${_stamp()}${ext.isEmpty ? '' : ext}');
    await file.copy(target);

    final mime = (mimeType == null || mimeType.isEmpty)
        ? ChatAttachment.mimeOf(displayName)
        : mimeType;

    return ChatAttachment(
      path: target,
      name: displayName,
      mimeType: mime,
      size: length,
      kind: ChatAttachment.kindOf(displayName, mimeType: mime),
    );
  }

  /// 直接把内存里的字节落盘。
  ///
  /// 生图结果是接口返回的字节（或下载下来的字节），没有「源文件路径」可复制，
  /// 所以单独给一条入口。
  static Future<ChatAttachment> saveBytes(
    List<int> bytes, {
    required String name,
    String? mimeType,
  }) async {
    if (bytes.length > maxBytes) {
      throw AttachmentTooLargeException(
        name: name,
        size: bytes.length,
        limit: maxBytes,
      );
    }

    final dir = await directory();
    final ext = p.extension(name);
    final target = p.join(dir.path, '${_stamp()}${ext.isEmpty ? '' : ext}');
    await File(target).writeAsBytes(bytes, flush: true);

    final mime = (mimeType == null || mimeType.isEmpty)
        ? ChatAttachment.mimeOf(name)
        : mimeType;

    return ChatAttachment(
      path: target,
      name: name,
      mimeType: mime,
      size: bytes.length,
      kind: ChatAttachment.kindOf(name, mimeType: mime),
    );
  }

  /// 为一个**已经在私有目录里**的图片构造附件信息（不复制文件）。
  ///
  /// 生图结果是直接写进私有目录的，不需要再走 [import] 复制一遍。
  static Future<ChatAttachment> describeLocalImage(
    String path, {
    String? name,
  }) async {
    var size = 0;
    try {
      final file = File(path);
      if (await file.exists()) size = await file.length();
    } catch (_) {
      // 拿不到大小不影响展示
    }

    final displayName = name ?? p.basename(path);
    final mime = ChatAttachment.mimeOf(displayName);
    return ChatAttachment(
      path: path,
      name: displayName,
      mimeType: mime,
      size: size,
      kind: AttachmentKind.image,
    );
  }

  /// 删除单个附件文件（不存在也不报错）
  static Future<void> delete(ChatAttachment attachment) async {
    try {
      final f = File(attachment.path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // 清理失败不影响主流程
    }
  }

  static Future<void> deleteAll(Iterable<ChatAttachment> items) async {
    for (final a in items) {
      await delete(a);
    }
  }

  /// 清理没有被任何会话引用的附件文件，返回删除数量。
  ///
  /// 删除会话 / 清空会话后调用，避免磁盘上堆积孤儿文件。
  static Future<int> sweepOrphans(Set<String> referencedPaths) async {
    try {
      final dir = await directory();
      if (!await dir.exists()) return 0;
      var removed = 0;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (referencedPaths.contains(entity.path)) continue;
        try {
          await entity.delete();
          removed++;
        } catch (_) {
          // 单个文件删不掉就跳过
        }
      }
      return removed;
    } catch (_) {
      return 0;
    }
  }

  /// 时间戳 + 随机后缀，避免同一毫秒内多选产生重名
  static String _stamp() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return '$now$rand';
  }
}
