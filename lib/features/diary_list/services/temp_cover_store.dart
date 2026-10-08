import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/temp_cover.dart';

/// 临时封面图的**进程级**存储。
///
/// ## 为什么是静态 Store 而不是 Provider
///
/// 写方是 `ChatProvider`（非 UI 层，拿不到 `BuildContext`），读方是首页。
/// `ChatProvider` 是 `ChangeNotifierProvider` 创建的，`Provider.of` 需要
/// `BuildContext` —— 它没有。这正是 `DiaryChangeBus` 与 `ToolConfirmationGate`
/// 已经解决过的问题，照抄同一个范式：**静态 `ValueNotifier` + 订阅方自己
/// `ValueListenableBuilder`**，零 provider 改造。
///
/// ## 为什么不落库
///
/// 需求就是「重启应用后消失」。一旦落进 sqflite，就得处理「什么时候删行」
/// 「和 DB 版本迁移的关系」「备份要不要带上」—— 全是白送的复杂度。
/// 进程内存 + 磁盘目录，冷启动一起清，是最短路径。
///
/// ## 生命周期
///
/// ```
/// 冷启动  → wipe()  删目录 + 清列表（聊天附件不动）
/// 切后台  → 什么都不发生（进程还在）
/// 杀进程  → 再打开 → wipe() → 回到空态
/// ```
class TempCoverStore {
  TempCoverStore._();

  /// 当前持有的临时封面图，**新的在前**。UI 订阅它即可。
  static final ValueNotifier<List<TempCover>> covers =
      ValueNotifier<List<TempCover>>(const []);

  static const String dirName = TempCover.dirName;

  /// 取（必要时创建）临时封面图目录
  static Future<Directory> directory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, dirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 把一张**已经落盘的图片**（绝对路径，通常是
  /// `{appDir}/chat_attachments/xxx.png`）复制成临时封面图并发布。
  ///
  /// ## 为什么必须复制而不是直接引用
  ///
  /// 封面位只认**相对路径**（见 [TempCover.relativePath] 的注释）。
  /// 而生图结果落在 `chat_attachments/`，存的是**绝对路径**。
  /// 把绝对路径直接丢给封面位 → 拼出 `{appDir}//data/...` → 永远显示灰图标、
  /// **日志里什么都没有**。宁可每张多占 1~2 MB（上限 5 张、重启即清），
  /// 也要把「路径约定」这件事收在一个地方。
  ///
  /// ## 绝不抛异常
  ///
  /// 生图本身是成功的，复制失败（磁盘满 / 权限）不该把整轮对话搞崩。
  /// 失败就返回 false，聊天页里的图照常显示。
  ///
  /// 返回值：是否真的发布进了 [covers]。
  static Future<bool> add(String sourcePath, {required String prompt}) async {
    if (sourcePath.trim().isEmpty) return false;
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return false;

      final dir = await directory();
      final ext = p.extension(sourcePath);
      final name = '${DateTime.now().millisecondsSinceEpoch}_${_rand()}'
          '${ext.isEmpty ? '.png' : ext}';
      final dest = File(p.join(dir.path, name));
      await src.copy(dest.path);

      // ★ 复制「没抛异常」不等于文件真的在 —— 发布前显式校验一次，
      //   否则列表里会挂一条指向不存在文件的记录（显示破图）。
      if (!await dest.exists()) return false;

      return _publish(TempCover(
        relativePath: '$dirName/$name',
        prompt: prompt,
        createdAt: DateTime.now(),
      ));
    } catch (_) {
      return false;
    }
  }

  /// 插入列表并处理被挤出去的旧文件
  static bool _publish(TempCover cover) {
    final result = TempCover.insert(covers.value, cover);
    covers.value = result.covers;
    // ★ 被挤出去的必须删文件 —— 只从列表里移除的话磁盘只增不减
    for (final relative in result.evicted) {
      unawaited(_deleteStored(relative));
    }
    return covers.value.any((c) => c.relativePath == cover.relativePath);
  }

  /// 冷启动清空。**必须在 `runApp` 之前调用**（见 `main.dart`）。
  ///
  /// 不能放在 `DiaryListScreen.initState` 里：那样切到别的 tab 再回来
  /// 就会把刚生成的图误删。
  ///
  /// 不能用 `getTemporaryDirectory()`：清理时机由系统决定，
  /// 而需求要的是「下一次开启应用」这种**确定性**。
  static Future<void> wipe() async {
    covers.value = const [];
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(appDir.path, dirName));
      // ★★ 目录名守卫：只删这一个目录。
      //    写错一个变量就会变成递归删掉整个 appDir —— 用户所有日记图片都没了。
      if (p.basename(dir.path) != dirName) return;
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // 删不掉也不影响本次会话：内存列表已经清空了
    }
  }

  /// 把相对路径还原成绝对路径（长按保存 / 全屏查看需要）
  static Future<File> absoluteFileOf(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return File(p.join(appDir.path, relativePath));
  }

  static Future<void> _deleteStored(String relativePath) async {
    // 归一化失败（路径非法）一律不动手
    final safe = TempCover.normalizeStored(relativePath);
    if (safe == null) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(appDir.path, safe));
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 单个文件删不掉不影响别的
    }
  }

  /// 仅供测试 / 调试：把内存列表清空（不动磁盘）
  @visibleForTesting
  static void resetInMemory() => covers.value = const [];

  static int _rand() => Random().nextInt(0xFFFFFF);
}
