/// 聊天附件模型（纯 Dart，只依赖 dart:convert，便于独立测试）
library;

import 'dart:convert';

/// 附件类别，决定发送给模型时使用哪种 content part
enum AttachmentKind {
  image,
  video,
  file;

  static AttachmentKind fromValue(String? v) {
    for (final k in AttachmentKind.values) {
      if (k.name == v) return k;
    }
    return AttachmentKind.file;
  }

  String get label {
    switch (this) {
      case AttachmentKind.image:
        return '图片';
      case AttachmentKind.video:
        return '视频';
      case AttachmentKind.file:
        return '文件';
    }
  }
}

/// 一条附件。
///
/// [path] 是**应用私有目录内的绝对路径**（由 AttachmentStore 导入时落盘），
/// 不是选择器返回的临时路径 —— 否则历史消息里的附件会随缓存清理而失效。
class ChatAttachment {
  final String path;
  final String name;
  final String mimeType;
  final int size;
  final AttachmentKind kind;

  const ChatAttachment({
    required this.path,
    required this.name,
    this.mimeType = '',
    this.size = 0,
    this.kind = AttachmentKind.file,
  });

  bool get isImage => kind == AttachmentKind.image;
  bool get isVideo => kind == AttachmentKind.video;
  bool get isFile => kind == AttachmentKind.file;

  /// 人类可读大小：1.2 MB / 345 KB / 89 B
  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() => {
        'path': path,
        'name': name,
        'mimeType': mimeType,
        'size': size,
        'kind': kind.name,
      };

  factory ChatAttachment.fromMap(Map<String, dynamic> map) {
    final path = (map['path'] as String?) ?? '';
    final name = (map['name'] as String?) ?? '';
    return ChatAttachment(
      path: path,
      name: name,
      mimeType: (map['mimeType'] as String?) ?? '',
      size: _toInt(map['size']),
      kind: map['kind'] is String
          ? AttachmentKind.fromValue(map['kind'] as String)
          : kindOf(name.isNotEmpty ? name : path),
    );
  }

  /// 序列化整个列表（存进 chat_messages.attachments 列）
  static String encodeList(List<ChatAttachment> items) {
    if (items.isEmpty) return '[]';
    return jsonEncode(items.map((a) => a.toMap()).toList());
  }

  /// 反序列化；任何异常都退化为空列表，不能让坏数据卡死聊天
  static List<ChatAttachment> decodeList(String? raw) {
    if (raw == null) return const [];
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '[]') return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return const [];
      final result = <ChatAttachment>[];
      for (final item in decoded) {
        if (item is Map) {
          final a = ChatAttachment.fromMap(Map<String, dynamic>.from(item));
          if (a.path.isNotEmpty) result.add(a);
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  /// 按扩展名 / mime 推断类别
  static AttachmentKind kindOf(String pathOrName, {String? mimeType}) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('image/')) return AttachmentKind.image;
    if (mime.startsWith('video/')) return AttachmentKind.video;

    final ext = _extension(pathOrName);
    if (_imageExts.contains(ext)) return AttachmentKind.image;
    if (_videoExts.contains(ext)) return AttachmentKind.video;
    return AttachmentKind.file;
  }

  /// 按扩展名推断 mime（推断不出时给通用的 application/octet-stream）
  static String mimeOf(String pathOrName) {
    final ext = _extension(pathOrName);
    return _mimeByExt[ext] ?? 'application/octet-stream';
  }

  static String _extension(String pathOrName) {
    final name = pathOrName.replaceAll('\\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static const Set<String> _imageExts = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'avif',
  };

  static const Set<String> _videoExts = {
    'mp4', 'mov', 'm4v', 'mkv', 'avi', 'webm', '3gp', 'flv', 'wmv',
  };

  static const Map<String, String> _mimeByExt = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'avif': 'image/avif',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'm4v': 'video/x-m4v',
    'mkv': 'video/x-matroska',
    'avi': 'video/x-msvideo',
    'webm': 'video/webm',
    '3gp': 'video/3gpp',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'flac': 'audio/flac',
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'md': 'text/markdown',
    'json': 'application/json',
    'csv': 'text/csv',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip': 'application/zip',
  };

  @override
  String toString() => 'ChatAttachment(${kind.name}, $name, $sizeLabel)';
}

/// 附件超过大小上限时抛出（在选择阶段就拦下，避免 base64 后撑爆内存）
class AttachmentTooLargeException implements Exception {
  final String name;
  final int size;
  final int limit;

  AttachmentTooLargeException({
    required this.name,
    required this.size,
    required this.limit,
  });

  @override
  String toString() {
    final mb = (limit / (1024 * 1024)).toStringAsFixed(0);
    final actual = (size / (1024 * 1024)).toStringAsFixed(1);
    return '「$name」有 $actual MB，超过 ${mb}MB 上限';
  }
}
