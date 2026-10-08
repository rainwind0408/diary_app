/// 临时封面图的数据模型与列表规则 —— **纯 Dart**，不依赖 Flutter，便于离线断言。
///
/// ## 它是什么
///
/// 「长按悬浮球说一句『生成一张水墨画』」产出的图，除了出现在聊天页，
/// 还会落到首页顶部封面位。但它**不是用户的正式图片**：冷启动即消失。
///
/// ## 为什么单独一个目录
///
/// 放在 `{appDir}/temp_covers/`，与 `diary_images/` 平级。
/// **绝不能混进 `diary_images/`** —— 那个目录会被 `getMonthImagePaths`、
/// `deleteImage`、备份逻辑扫到，混进去等于往用户数据里掺临时垃圾。
library;

import 'package:path/path.dart' as p;

/// 一张临时封面图
class TempCover {
  /// 相对路径，形如 `temp_covers/1789468691938_123.png`（相对 appDir）
  ///
  /// **必须相对**：封面位读取走 `ImageService.getImageFile(rel)` →
  /// `File('${appDir.path}/$rel')`。给它绝对路径会拼出
  /// `{appDir}//data/user/0/...` —— 一个永远不存在的路径，
  /// `FutureBuilder` 静默走 `errorBuilder`，界面上只剩一个灰图标，**不报任何错**。
  final String relativePath;

  /// 生成用的提示词（大图页标题 / 无障碍描述用）
  final String prompt;

  final DateTime createdAt;

  const TempCover({
    required this.relativePath,
    required this.prompt,
    required this.createdAt,
  });

  /// 存放目录名（与 `diary_images/` 平级）
  static const String dirName = 'temp_covers';

  /// 列表上限。超出丢最旧 —— 避免连续生成十张后堆一屏。
  static const int maxCount = 5;

  static const String _prefix = '$dirName/';

  bool get isValid => isStoredPath(relativePath);

  /// 这个相对路径是不是「临时封面图」。
  ///
  /// ⚠️ **前缀陷阱**：`temp_covers_x/xxx.png` 不算 —— 必须连尾斜杠一起比。
  /// 只比 `startsWith('temp_covers')` 会把一个同前缀的别的目录也算进来，
  /// 于是 `wipe()` 的删除范围就悄悄变大了。
  static bool isStoredPath(String storedPath) {
    final norm = _normalizeSeparators(storedPath).trim();
    return norm.startsWith(_prefix) && norm.length > _prefix.length;
  }

  /// 把存下来的路径归一化成安全的相对路径；不在 `temp_covers/` 之下返回 null。
  ///
  /// 做三件事：统一分隔符（Windows 上可能混进 `\`）、去掉 `./` 前缀、
  /// 用 `p.posix.normalize` 消掉 `..`（`temp_covers/../x` 会被拒掉）。
  ///
  /// 一律用 `p.posix`：本项目只发 Android，且要保证同一段逻辑在 Windows 上
  /// 跑离线测试时行为完全一致。
  static String? normalizeStored(String storedPath) {
    var norm = _normalizeSeparators(storedPath.trim());
    while (norm.startsWith('./')) {
      norm = norm.substring(2);
    }
    if (norm.isEmpty) return null;
    // 绝对路径在这里就被挡掉了：'/data/...' 不以 'temp_covers/' 开头
    if (!norm.startsWith(_prefix)) return null;
    final normalized = p.posix.normalize(norm);
    if (!isStoredPath(normalized)) return null;
    return normalized;
  }

  static String _normalizeSeparators(String s) => s.replaceAll(r'\', '/');

  /// 插入一张新图：**新的放最前**，按 [maxCount] 裁剪。
  ///
  /// ⚠️ **前提**：[current] 必须已经是「新的在前」的顺序（[TempCoverStore]
  /// 始终这样维护）。传一个旧的在前面的列表，被挤出去的就会是新的那张。
  ///
  /// 返回 `(covers, evicted)`。`evicted` 是被挤出去、需要**从磁盘删掉**的相对路径。
  /// 调用方必须删文件 —— 只从列表里移除会让磁盘只增不减。
  ///
  /// 同一张图重复发布（例如工具循环里被执行了两次）不会重复插入。
  static ({List<TempCover> covers, List<String> evicted}) insert(
    List<TempCover> current,
    TempCover cover,
  ) {
    if (!cover.isValid) {
      return (covers: List<TempCover>.from(current), evicted: const []);
    }
    final rest = current
        .where((c) => c.isValid && c.relativePath != cover.relativePath)
        .toList();
    final next = <TempCover>[cover, ...rest];
    if (next.length <= maxCount) return (covers: next, evicted: const []);
    return (
      covers: next.sublist(0, maxCount),
      evicted: next.sublist(maxCount).map((c) => c.relativePath).toList(),
    );
  }

  /// 剔掉路径非法的条目（读磁盘 / 反序列化之后过一道）
  static List<TempCover> sanitize(List<TempCover> list) =>
      list.where((c) => c.isValid).toList();
}
