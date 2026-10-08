/// 日记媒体的 marker 编解码 + 路径守卫 —— **纯 Dart**，便于离线单测。
///
/// 本文件是日记媒体的**纯模型层**，只放不依赖 `dart:ui` 的东西：
/// [MediaMarker]（编解码）、[DiaryMediaPath]（路径守卫）、
/// [DiaryMediaItem]（清单项）、以及两个格式化函数。
/// 真正碰文件系统 / 插件的那部分在 `services/diary_media_service.dart`。
///
/// ## 为什么需要 marker
///
/// 协议层有一条硬约束：**图片只能出现在 `user` 消息里**
/// （非 user 消息的附件会被 `ChatContextBuilder` 静默剥掉），
/// 而 `tool` 消息的 content 必须是字符串。
///
/// 所以「让模型看见日记里的图片」只有一条通路：
///
/// ```
/// 工具返回 MediaMarker（一段 JSON 字符串）
///   → ChatProvider 解析出来
///   → 追加一条 role=user 的消息，把图片作为附件挂上去
///   → 下一轮请求时模型就看到了
/// ```
///
/// 这与生图的 `ImageGenResult` 是同一个模式，两者刻意保持对称。
library;

import 'dart:convert';

import 'package:path/path.dart' as p;

/// 「请让模型看看这几张日记图片」这件事的编码。
class MediaMarker {
  /// 标记类型。工具把它塞进返回值，界面/Provider 据此认出
  /// 「这条工具结果里带着要送进模型视野的图片」。
  static const String markerKind = 'diary_media';

  /// 追加的 user 消息正文前缀。
  ///
  /// 界面上识别它并用淡底样式渲染 —— 否则历史记录里会冒出一条
  /// 看起来像用户自己发的「日记《…》里的第 2 张图片」，很怪。
  static const String systemPrefix = '[系统] ';

  /// 要送进模型视野的图片**绝对路径**（已过 [DiaryMediaPath] 校验）
  final List<String> imagePaths;

  /// 给模型看的一句说明，例如「日记《周末的雨》里的第 2 张图片」
  final String caption;

  const MediaMarker({required this.imagePaths, required this.caption});

  /// 这条 marker 对应的 user 消息正文
  String get messageText => '$systemPrefix$caption';

  /// 工具返回给模型的字符串。
  ///
  /// 带上 caption，模型才知道这张图是从哪篇日记里翻出来的。
  String toMarker() => jsonEncode({
        'kind': markerKind,
        'images': imagePaths,
        'caption': caption,
      });

  /// 从工具返回值里解析出结果；不是媒体标记时返回 null。
  ///
  /// **绝不抛异常** —— 工具返回值可能是一段普通 JSON，也可能直接是报错文本。
  static MediaMarker? tryParse(String raw) {
    final trimmed = raw.trim();
    // 便宜预筛：避免对每一段工具返回都跑 jsonDecode
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    if (decoded['kind'] != markerKind) return null;

    final rawImages = decoded['images'];
    if (rawImages is! List) return null;

    final paths = <String>[];
    for (final item in rawImages) {
      if (item is String && item.trim().isNotEmpty) paths.add(item.trim());
    }
    // 一张图都没有 → 当成普通结果，别白白插一条空消息
    if (paths.isEmpty) return null;

    final caption = decoded['caption'];
    return MediaMarker(
      imagePaths: paths,
      caption: caption is String ? caption : '',
    );
  }
}

/// 日记媒体路径守卫 —— 纯逻辑，可在纯 Dart VM 里逐条断言。
///
/// ## 为什么必须校验
///
/// `PlacedImage.path` / `PlacedAudio.path` 里存的是**相对路径**
/// （形如 `diary_images/1712345678.jpg`），根目录由 `path_provider` 给出。
/// 这个字段来自数据库里的 JSON 列，理论上可被篡改 ——
/// **不能拿它直接拼绝对路径**，否则 `../../` 就能读到应用沙箱里的任何文件。
///
/// 一律用 `p.posix`（而不是平台默认的 `p`）：
/// - 本 App 是 Android 单平台，路径本来就是 POSIX；
/// - 用平台默认值的话，同一段逻辑在 Windows 上跑测试时行为会变，
///   而这条逻辑恰恰是「必须在离线测试里断言」的那种。
class DiaryMediaPath {
  DiaryMediaPath._();

  /// 图片落盘目录（相对 appDir）。与 `ImageService._imageDir` 保持一致。
  static const String imagesDir = 'diary_images';

  /// 录音落盘目录（相对 appDir）。与 `DiaryAudioService._audioDir` 保持一致。
  static const String audiosDir = 'diary_audio';

  /// 允许的两个媒体子目录
  static const List<String> mediaDirs = [imagesDir, audiosDir];

  /// 把数据库里存的相对路径解析成绝对路径；非法一律返回 null。
  ///
  /// 拒绝的情况：
  /// - 空串 / 纯空白
  /// - 绝对路径（无论 POSIX 的 `/` 还是 Windows 的盘符）
  /// - 归一化后跑出 [appDir]（例如 `../../etc/passwd`）
  /// - 归一化后正好等于 [appDir]（`p.isWithin` 对自身返回 false）
  static String? resolve({
    required String appDir,
    required String storedPath,
  }) {
    final raw = storedPath.trim();
    if (raw.isEmpty) return null;

    final root = p.posix.normalize(appDir);
    if (root.isEmpty || root == '.') return null;

    if (p.posix.isAbsolute(raw)) return null;

    final joined = p.posix.normalize(p.posix.join(root, raw));
    if (!p.posix.isWithin(root, joined)) return null;
    return joined;
  }

  /// 相对路径是否指向日记的图片/录音目录。
  ///
  /// 比 [resolve] 更严：即使没跑出 appDir，也必须落在
  /// `diary_images/` 或 `diary_audio/` 之下 —— 否则工具就能读到
  /// 应用沙箱里与日记无关的文件。
  static bool isMedia({required String appDir, required String storedPath}) {
    final abs = resolve(appDir: appDir, storedPath: storedPath);
    if (abs == null) return false;

    final root = p.posix.normalize(appDir);
    for (final sub in mediaDirs) {
      if (p.posix.isWithin(p.posix.join(root, sub), abs)) return true;
    }
    return false;
  }

  /// 是不是图片目录里的文件
  static bool isImage({required String appDir, required String storedPath}) {
    final abs = resolve(appDir: appDir, storedPath: storedPath);
    if (abs == null) return false;
    final root = p.posix.normalize(appDir);
    return p.posix.isWithin(p.posix.join(root, imagesDir), abs);
  }

  /// 是不是录音目录里的文件
  static bool isAudio({required String appDir, required String storedPath}) {
    final abs = resolve(appDir: appDir, storedPath: storedPath);
    if (abs == null) return false;
    final root = p.posix.normalize(appDir);
    return p.posix.isWithin(p.posix.join(root, audiosDir), abs);
  }
}

/// 一篇日记里的一段媒体（图片或录音）的清单项。
///
/// 纯数据 —— 文件大小由 `DiaryMediaService` 从磁盘读出来再塞进来，
/// 这样这个类的 `toJson` 就能在纯 Dart VM 里断言。
class DiaryMediaItem {
  /// 序号，**从 1 开始**（模型是按「第 2 张图」这种说法调工具的）
  final int index;

  /// 数据库里存的相对路径（原样保留，用于回查）
  final String storedPath;

  /// 解析后的绝对路径（已过 [DiaryMediaPath] 校验）
  final String absPath;

  /// 显示用文件名
  final String name;

  /// 文件大小（字节）；读不到时为 0
  final int sizeBytes;

  /// 时长（毫秒）；图片为 null
  final int? durationMs;

  const DiaryMediaItem({
    required this.index,
    required this.storedPath,
    required this.absPath,
    required this.name,
    this.sizeBytes = 0,
    this.durationMs,
  });

  bool get isAudio => durationMs != null;

  Map<String, dynamic> toJson() => {
        'index': index,
        'name': name,
        'size_bytes': sizeBytes,
        'size': formatBytes(sizeBytes),
        if (durationMs != null) ...{
          'duration_ms': durationMs,
          'duration': formatDuration(durationMs!),
        },
      };
}

/// 人类可读的文件大小。给模型看，所以用 KB / MB 这种它熟悉的写法。
String formatBytes(int bytes) {
  if (bytes <= 0) return '未知';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}

/// 把毫秒格式化成 `mm:ss`。
String formatDuration(int ms) {
  final totalSeconds = ms <= 0 ? 0 : ms ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
