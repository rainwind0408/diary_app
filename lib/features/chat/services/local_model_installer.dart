import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/local_model.dart';
import 'local_model_store.dart';

/// 安装阶段
enum LocalInstallStage {
  /// 拉取仓库文件清单
  listing,

  /// 下载中
  downloading,

  /// 校验字节数
  verifying,

  /// 已装好
  done,

  /// 失败（[LocalInstallProgress.error] 有原因）
  failed,

  /// 用户取消
  cancelled,
}

/// 一次安装的进度快照
class LocalInstallProgress {
  final String modelId;
  final LocalInstallStage stage;

  /// 已收到的字节（所有文件累计）
  final int receivedBytes;
  final int totalBytes;

  final int doneFiles;
  final int totalFiles;

  /// 正在下哪个文件（界面用来显示细节，也便于排错）
  final String currentFile;

  /// 失败原因（给人看的，不含 `Exception: ` 前缀）
  final String? error;

  const LocalInstallProgress({
    required this.modelId,
    required this.stage,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.doneFiles = 0,
    this.totalFiles = 0,
    this.currentFile = '',
    this.error,
  });

  bool get isRunning =>
      stage == LocalInstallStage.listing ||
      stage == LocalInstallStage.downloading ||
      stage == LocalInstallStage.verifying;

  double get fraction {
    if (totalBytes <= 0) return 0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// 进度文案，如 `62%`；还在拉清单时给 `准备中`
  String get percentLabel {
    if (stage == LocalInstallStage.listing) return '准备中';
    if (stage == LocalInstallStage.verifying) return '校验中';
    return '${(fraction * 100).round()}%';
  }
}

/// 本地模型下载器。
///
/// 流程：拉仓库清单 → 按白名单挑文件 → 并发下载 → 逐文件核对字节 → 写安装记录。
///
/// ## 为什么进度放在**静态单例**而不是页面 State
///
/// 228 MB 的模型要下好几分钟，用户很可能切出去看看别的再回来。
/// 放在页面 State 里，一离开页面进度就丢了、下载也断了。
/// 与 `TtsPlayer` 用静态单例的理由一致：这是**全局唯一的资源**。
class LocalModelInstaller {
  LocalModelInstaller._();

  /// 每个模型的安装进度（只包含正在装或刚装完的）
  static final ValueNotifier<Map<String, LocalInstallProgress>> progress =
      ValueNotifier<Map<String, LocalInstallProgress>>({});

  /// 并发数。4 是个折中：再多对源站不礼貌，再少则 355 个小文件太慢。
  static const int concurrency = 4;

  /// 单个文件的尝试次数（含首次）
  static const int maxAttempts = 2;

  /// 建立连接 / 拿到响应头的超时
  static const Duration connectTimeout = Duration(seconds: 30);

  /// 两个数据块之间的最大间隔（卡住判定）
  static const Duration stallTimeout = Duration(seconds: 60);

  /// 进度回调的最小间隔 —— 每收到一个 8KB 数据块就 setState 会把界面拖垮
  static const Duration _notifyInterval = Duration(milliseconds: 120);

  static final Set<String> _cancelRequested = <String>{};
  static final Set<String> _running = <String>{};

  /// 当前是否在装
  static bool isInstalling(String modelId) => _running.contains(modelId);

  /// 请求取消。**不会立刻停**，下一个数据块到达时才真正中断。
  static void cancel(String modelId) => _cancelRequested.add(modelId);

  /// 丢掉某个模型的进度记录（界面用它清掉「失败」横幅）
  static void clearProgress(String modelId) {
    if (!progress.value.containsKey(modelId)) return;
    final next = Map<String, LocalInstallProgress>.from(progress.value)
      ..remove(modelId);
    progress.value = next;
  }

  /// 安装一个模型。返回是否成功装好。
  ///
  /// 失败**不抛异常**：调用方多半是按钮回调，抛出去只会变成红屏。
  /// 原因写进 [LocalInstallProgress.error]，由界面读走。
  static Future<bool> install(LocalModelSpec spec) async {
    if (_running.contains(spec.id)) return false;
    _running.add(spec.id);
    _cancelRequested.remove(spec.id);

    var lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

    void emit(
      LocalInstallStage stage, {
      int? received,
      int? total,
      int? doneFiles,
      int? totalFiles,
      String? currentFile,
      String? error,
      bool force = false,
    }) {
      final now = DateTime.now();
      if (!force &&
          now.difference(lastNotify) < _notifyInterval &&
          stage == LocalInstallStage.downloading) {
        return;
      }
      lastNotify = now;
      final prev = progress.value[spec.id];
      final next = Map<String, LocalInstallProgress>.from(progress.value);
      next[spec.id] = LocalInstallProgress(
        modelId: spec.id,
        stage: stage,
        receivedBytes: received ?? prev?.receivedBytes ?? 0,
        totalBytes: total ?? prev?.totalBytes ?? 0,
        doneFiles: doneFiles ?? prev?.doneFiles ?? 0,
        totalFiles: totalFiles ?? prev?.totalFiles ?? 0,
        currentFile: currentFile ?? prev?.currentFile ?? '',
        error: error,
      );
      progress.value = next;
    }

    Directory? dir;
    try {
      // ── 1. 拉清单 ──
      emit(LocalInstallStage.listing, force: true);
      final entries = await _fetchTree(spec);
      _throwIfCancelled(spec.id);

      final picked = LocalModelCatalog.select(spec, entries);
      final totalBytes = picked.fold<int>(0, (sum, e) => sum + e.bytes);
      if (totalBytes <= 0) {
        throw const LocalModelPlanException('清单里所有文件的体积都是 0，源站可能异常');
      }

      // ── 2. 落盘 ──
      dir = await LocalModelStore.dirOf(spec.id);
      if (!await dir.exists()) await dir.create(recursive: true);

      emit(
        LocalInstallStage.downloading,
        received: 0,
        total: totalBytes,
        doneFiles: 0,
        totalFiles: picked.length,
        force: true,
      );

      final client = http.Client();
      var received = 0;
      var doneFiles = 0;

      try {
        // 简易工作池：把 picked 切成 concurrency 条，各自顺序下载。
        // 用「分片」而不是「任务队列」是为了让进度单调递增、不来回跳。
        final slices = List.generate(concurrency, (_) => <RemoteFileEntry>[]);
        for (var i = 0; i < picked.length; i++) {
          slices[i % concurrency].add(picked[i]);
        }

        Future<void> runSlice(List<RemoteFileEntry> slice) async {
          for (final entry in slice) {
            _throwIfCancelled(spec.id);
            final target = File(p.join(dir!.path, entry.path));
            await target.parent.create(recursive: true);

            // 已存在且字节数正确 → 跳过。
            // 这让「下到一半被杀掉、重来」不必从头下，也顺手做到了断点续传。
            if (await target.exists() &&
                await target.length() == entry.bytes) {
              received += entry.bytes;
              doneFiles++;
              emit(
                LocalInstallStage.downloading,
                received: received,
                doneFiles: doneFiles,
                currentFile: entry.path,
              );
              continue;
            }

            await _downloadOne(
              client: client,
              spec: spec,
              entry: entry,
              target: target,
              onChunk: (n) {
                received += n;
                emit(
                  LocalInstallStage.downloading,
                  received: received,
                  currentFile: entry.path,
                );
              },
              isCancelled: () => _cancelRequested.contains(spec.id),
            );

            doneFiles++;
            emit(
              LocalInstallStage.downloading,
              received: received,
              doneFiles: doneFiles,
              currentFile: entry.path,
            );
          }
        }

        await Future.wait(slices.map(runSlice));
      } finally {
        client.close();
      }

      // ── 3. 终验：逐个文件核对字节数 ──
      emit(LocalInstallStage.verifying, received: totalBytes, force: true);
      for (final entry in picked) {
        final f = File(p.join(dir.path, entry.path));
        if (!await f.exists()) {
          throw LocalModelPlanException('下载完成但找不到 `${entry.path}`');
        }
        final len = await f.length();
        if (len != entry.bytes) {
          throw LocalModelPlanException(
            '`${entry.path}` 下载不完整（期望 ${entry.bytes} 字节，实际 $len）',
          );
        }
      }

      await LocalModelStore.markInstalled(
        modelId: spec.id,
        bytes: totalBytes,
        fileCount: picked.length,
      );

      emit(
        LocalInstallStage.done,
        received: totalBytes,
        total: totalBytes,
        doneFiles: picked.length,
        totalFiles: picked.length,
        force: true,
      );
      return true;
    } on _InstallCancelled {
      // 取消：把半成品目录删掉，别让「装了一半」的目录被误认为可用。
      // （不删的话下次安装会走「文件已存在且字节数正确」的快路径 ——
      //  这其实是好事，但只有**完整**的文件才算数，半截文件会被重新下。
      //  这里保守起见整目录清掉，避免留下难排查的残骸。）
      if (dir != null) {
        try {
          if (await dir.exists()) await dir.delete(recursive: true);
        } catch (_) {
          // 删不掉也无妨
        }
      }
      emit(LocalInstallStage.cancelled, force: true);
      return false;
    } catch (e) {
      emit(LocalInstallStage.failed, error: readableInstallError(e), force: true);
      return false;
    } finally {
      _running.remove(spec.id);
      _cancelRequested.remove(spec.id);
    }
  }

  // ─────────────────────────────────────────────

  /// 拉仓库全量清单（带体积）
  static Future<List<RemoteFileEntry>> _fetchTree(LocalModelSpec spec) async {
    final uri = Uri.parse(LocalModelCatalog.treeUrl(spec));
    final http.Response resp;
    try {
      resp = await http.get(uri).timeout(connectTimeout);
    } on TimeoutException {
      throw const LocalModelPlanException(
        '读取模型清单超时，请检查网络后重试（下载源 hf-mirror.com）',
      );
    } on SocketException catch (e) {
      throw LocalModelPlanException('读取模型清单失败：${e.message}');
    }

    if (resp.statusCode != 200) {
      throw LocalModelPlanException(
        '读取模型清单失败（HTTP ${resp.statusCode}），'
        '下载源可能暂时不可用',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(resp.bodyBytes, allowMalformed: true));
    } catch (_) {
      throw const LocalModelPlanException('模型清单不是合法的 JSON，源站可能返回了错误页');
    }

    final entries = RemoteFileEntry.parseList(decoded);
    if (entries.isEmpty) {
      throw const LocalModelPlanException('模型清单为空，源站可能暂时不可用');
    }
    return entries;
  }

  /// 下单个文件（含重试）。落盘用「先写临时文件再改名」，
  /// 避免中断留下一个字节数看着对、内容却是半截的文件。
  static Future<void> _downloadOne({
    required http.Client client,
    required LocalModelSpec spec,
    required RemoteFileEntry entry,
    required File target,
    required void Function(int bytes) onChunk,
    required bool Function() isCancelled,
  }) async {
    final url = LocalModelCatalog.downloadUrl(spec, entry.path);
    final tmp = File('${target.path}.part');

    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (isCancelled()) throw const _InstallCancelled();
      try {
        final req = http.Request('GET', Uri.parse(url));
        final resp = await client.send(req).timeout(connectTimeout);

        if (resp.statusCode != 200) {
          throw LocalModelPlanException(
            '下载 `${entry.path}` 失败（HTTP ${resp.statusCode}）',
          );
        }

        final sink = tmp.openWrite();
        try {
          await for (final chunk in resp.stream.timeout(stallTimeout)) {
            if (isCancelled()) throw const _InstallCancelled();
            sink.add(chunk);
            onChunk(chunk.length);
          }
        } finally {
          await sink.close();
        }

        // 改名前先核一次字节数：不符就当作失败，让重试去处理
        final len = await tmp.length();
        if (len != entry.bytes) {
          throw LocalModelPlanException(
            '`${entry.path}` 字节数不符（期望 ${entry.bytes}，实际 $len）',
          );
        }

        if (await target.exists()) await target.delete();
        await tmp.rename(target.path);
        return;
      } on _InstallCancelled {
        try {
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {}
        rethrow;
      } catch (e) {
        lastError = e;
        try {
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {}
      }
    }

    throw LocalModelPlanException(
      '下载 `${entry.path}` 失败：${readableInstallError(lastError)}',
    );
  }

  static void _throwIfCancelled(String modelId) {
    if (_cancelRequested.contains(modelId)) throw const _InstallCancelled();
  }

  /// 把异常转成给人看的一句话
  static String readableInstallError(Object? error) {
    if (error == null) return '未知错误';
    if (error is LocalModelPlanException) return error.message;

    var s = error.toString().trim();
    for (final prefix in const ['Exception: ', 'Exception：']) {
      if (s.startsWith(prefix)) s = s.substring(prefix.length).trim();
    }

    if (error is TimeoutException) {
      return '网络超时，请检查网络后重试';
    }
    if (error is SocketException) {
      return '网络不可用：${error.message}';
    }
    if (error is FileSystemException) {
      // 最常见的成因是空间不足 —— 明确说出来，别让用户以为是自己网络的问题
      return '写入失败（多半是存储空间不足）：${error.message}';
    }
    return s.isEmpty ? '未知错误' : s;
  }
}

/// 内部用的取消信号（不对外暴露 —— 对外统一是「进度里的 cancelled 状态」）
class _InstallCancelled implements Exception {
  const _InstallCancelled();

  @override
  String toString() => '已取消';
}
