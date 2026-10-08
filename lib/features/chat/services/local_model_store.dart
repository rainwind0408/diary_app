import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_provider.dart';
import '../models/local_model.dart';

/// 一条「已安装」记录
class InstalledLocalModel {
  final String modelId;

  /// 实际落盘字节数（下载后逐个核对过）
  final int bytes;

  /// 文件个数。用于「记录还在、文件被清了一半」这种半残状态的识别。
  final int fileCount;

  final DateTime installedAt;

  const InstalledLocalModel({
    required this.modelId,
    required this.bytes,
    required this.fileCount,
    required this.installedAt,
  });

  Map<String, dynamic> toMap() => {
        'bytes': bytes,
        'files': fileCount,
        'at': installedAt.millisecondsSinceEpoch,
      };

  static InstalledLocalModel? fromMap(String id, dynamic raw) {
    if (raw is! Map) return null;
    final bytes = raw['bytes'];
    final files = raw['files'];
    final at = raw['at'];
    return InstalledLocalModel(
      modelId: id,
      bytes: bytes is int ? bytes : 0,
      fileCount: files is int ? files : 0,
      installedAt: DateTime.fromMillisecondsSinceEpoch(
        at is int ? at : 0,
      ),
    );
  }
}

/// 本地模型的**安装状态**（唯一读写入口）。
///
/// 存储形态：SharedPreferences 单 key [keyInstalled] 存一段 JSON
/// `{modelId: {bytes, files, at}}`；模型文件本身在
/// `{AppSupport}/sherpa_models/<modelId>/`。
///
/// ## 两条必须记住的规则
///
/// 1. **绝不放进 `diary_images/` / `diary_audio/`。**
///    那两个目录是日记媒体的地盘，项目的「是不是媒体」判定要求路径必须落在
///    它们之下 —— 混进去会被当成用户图片/录音，出现在图片墙里。
///
/// 2. **不能用 cache 目录。** 系统在低存储时会清 cache，
///    表现是「模型莫名其妙没了、还每次都要重下」。`getApplicationSupportDirectory()`
///    只在卸载时清，才是模型该待的地方。
///
/// ## 读取时会与磁盘核对
///
/// 记录说装了、目录却不在（用户清了数据 / 系统清了 / 装到一半被杀），
/// 直接采信记录会让界面显示「已安装」但一说话就崩。
/// 所以 [load] 会顺手把这类**幽灵记录**剔掉并回写。
class LocalModelStore {
  LocalModelStore._();

  static const String keyInstalled = 'local_models_v1';

  /// 模型根目录名（位于 Application Support 下）
  static const String rootDirName = 'sherpa_models';

  static Map<String, InstalledLocalModel>? _cache;

  /// 内存缓存（同步读取用；未加载过则为 null）
  static Map<String, InstalledLocalModel>? get cached => _cache;

  /// 读取安装记录。
  ///
  /// [force] 为 true 时忽略缓存重新读盘。第一次读（或 force）会做磁盘核对。
  static Future<Map<String, InstalledLocalModel>> load({
    bool force = false,
  }) async {
    if (!force && _cache != null) return _cache!;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyInstalled);

    final parsed = <String, InstalledLocalModel>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final id = entry.key.toString();
            final item = InstalledLocalModel.fromMap(id, entry.value);
            if (item != null) parsed[id] = item;
          }
        }
      } catch (_) {
        // 记录损坏 → 当作「什么都没装」。模型文件若还在，
        // 用户重新点一次安装会走「目录已存在」的快路径，不会白下。
      }
    }

    // ── 磁盘核对：剔掉幽灵记录 ──
    final healed = <String, InstalledLocalModel>{};
    var dropped = false;
    for (final entry in parsed.entries) {
      if (await _looksInstalled(entry.key, entry.value.fileCount)) {
        healed[entry.key] = entry.value;
      } else {
        dropped = true;
      }
    }

    _cache = healed;
    if (dropped || healed.length != parsed.length) {
      await _write(prefs, healed);
    }
    return healed;
  }

  /// 记录 + 磁盘**双重确认**才叫「已安装」。
  static Future<bool> isInstalled(String modelId, {bool force = false}) async {
    final map = await load(force: force);
    final record = map[modelId];
    if (record == null) return false;
    return _looksInstalled(modelId, record.fileCount);
  }

  /// 模型目录（**不创建**）。装之前也要能拿到这个路径，所以不创建。
  static Future<Directory> dirOf(String modelId) async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, rootDirName, _safeSegment(modelId)));
  }

  /// 模型目录的绝对路径字符串
  static Future<String> pathOf(String modelId) async =>
      (await dirOf(modelId)).path;

  /// 给「语音调用点」用的便捷方法：如果当前选中的厂商是**已安装的**本地模型，
  /// 返回它的模型目录；否则返回 null。
  ///
  /// 返回 null 时调用方把 null 原样透传给 `SttClient` / `TtsClient`，
  /// 由它们给出「本地模型还没安装」的提示 —— 判断逻辑只写一份。
  static Future<String?> dirForProvider(AiProvider provider) async {
    if (provider.protocol != AiProtocol.local) return null;
    final modelId = LocalModelCatalog.modelIdOfProvider(provider.id);
    if (modelId == null) return null;
    if (!await isInstalled(modelId)) return null;
    return pathOf(modelId);
  }

  /// 写入安装记录
  static Future<void> markInstalled({
    required String modelId,
    required int bytes,
    required int fileCount,
    DateTime? at,
  }) async {
    final map = Map<String, InstalledLocalModel>.from(
      await load(force: true),
    );
    map[modelId] = InstalledLocalModel(
      modelId: modelId,
      bytes: bytes,
      fileCount: fileCount,
      installedAt: at ?? DateTime.now(),
    );
    _cache = map;
    final prefs = await SharedPreferences.getInstance();
    await _write(prefs, map);
  }

  /// 卸载：**先删文件，再清记录**。
  ///
  /// 顺序不能反 —— 先清记录的话，中途失败就再也找不到那堆文件了
  /// （变成谁也不知道的孤儿目录）。
  static Future<void> uninstall(String modelId) async {
    final dir = await dirOf(modelId);
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // 删不掉也继续清记录：留着记录只会让界面一直显示「已安装」却用不了。
    }
    await forget(modelId);
  }

  /// 只清记录，不动文件（供内部与「记录修复」使用）
  static Future<void> forget(String modelId) async {
    final map = Map<String, InstalledLocalModel>.from(await load(force: true))
      ..remove(modelId);
    _cache = map;
    final prefs = await SharedPreferences.getInstance();
    await _write(prefs, map);
  }

  /// 清空内存缓存（需要强制重载时用）
  static void invalidate() => _cache = null;

  // ─────────────────────────────────────────────

  static Future<void> _write(
    SharedPreferences prefs,
    Map<String, InstalledLocalModel> map,
  ) async {
    final json = <String, dynamic>{
      for (final e in map.entries) e.key: e.value.toMap(),
    };
    await prefs.setString(keyInstalled, jsonEncode(json));
  }

  /// 目录在、且文件数不少于记录值 → 认为还在
  static Future<bool> _looksInstalled(String modelId, int expectedFiles) async {
    try {
      final dir = await dirOf(modelId);
      if (!await dir.exists()) return false;
      // 记录里 fileCount 为 0（老记录 / 异常）时只要求目录非空
      final need = expectedFiles <= 0 ? 1 : expectedFiles;
      var count = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          count++;
          if (count >= need) return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 目录名守卫：modelId 只能是一段安全路径。
  ///
  /// `uninstall` 会 `delete(recursive: true)`，一旦 modelId 里混进 `..`
  /// 或空串，删掉的就可能是整个 Application Support 目录。
  ///
  /// 实现搬到 [LocalModelCatalog.safeSegment]（纯 Dart，可单测）。
  static String _safeSegment(String modelId) =>
      LocalModelCatalog.safeSegment(modelId);
}
