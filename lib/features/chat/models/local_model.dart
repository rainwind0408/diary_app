/// 本地离线语音模型（sherpa-onnx）的**可装清单**与文件挑选规则。
///
/// 纯 Dart：只依赖 dart:convert，不引入 Flutter，便于独立测试。
///
/// ## 为什么文件清单是「白名单」而不是「黑名单」
///
/// 这些仓库里常常同时躺着 **fp32 与 int8 两份模型**，体积差一个量级：
/// SenseVoice 那个仓库里 `model.onnx`（fp32）是 **894 MB**，而
/// `model.int8.onnx` 只有 228 MB。用黑名单写「排除 model.onnx」，
/// 一旦漏写或仓库改结构，用户点一次安装就是近 1 GB 流量。
///
/// 所以这里只写「**要哪些**」，其余一律不下；另外再用
/// [LocalModelCatalog.assertNoFp32] 做第二道断言。
///
/// ## 体积是实测值
///
/// 全部来自 `https://hf-mirror.com/api/models/<repo>/tree/main?recursive=true`
/// 的逐文件字节数（2026-10-08 实测），不是估算。
library;

import 'ai_provider.dart';

/// 仓库清单里的一个文件
class RemoteFileEntry {
  final String path;

  /// 期望字节数（用来做下载后的完整性校验）
  final int bytes;

  const RemoteFileEntry({required this.path, required this.bytes});

  /// 从 HuggingFace 的 `tree/main?recursive=true` 响应里解析文件条目。
  ///
  /// 只认 `type == 'file'`；目录条目直接跳过（目录本身没有体积）。
  static List<RemoteFileEntry> parseList(dynamic decoded) {
    if (decoded is! List) return const [];
    final out = <RemoteFileEntry>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      if (item['type'] != 'file') continue;
      final path = item['path'];
      if (path is! String || path.isEmpty) continue;
      final size = item['size'];
      out.add(
        RemoteFileEntry(
          path: path,
          bytes: size is int ? size : (size is num ? size.toInt() : 0),
        ),
      );
    }
    return out;
  }
}

/// 一个可安装的本地模型
class LocalModelSpec {
  /// 稳定 id，同时也是磁盘目录名（`{AppSupport}/sherpa_models/<id>`）
  final String id;

  /// 短名，界面主标题，如「Zipformer 14M」
  final String name;

  /// 这个模型能干什么（决定它出现在「语音识别」还是「语音合成」页）
  final AiCapability capability;

  /// 一句话说明，界面副标题
  final String summary;

  /// 体积（MB，实测）。界面必须标出来 —— 用户要清楚自己在下多少东西。
  final double approxSizeMb;

  /// hf-mirror 上的仓库名，如 `csukuangfj/kokoro-int8-multi-lang-v1_0`
  final String repo;

  /// 要下载的**精确文件**（仓库内相对路径）
  final List<String> files;

  /// 要整目录下载的**前缀**（必须以 `/` 结尾，如 `espeak-ng-data/`）
  final List<String> dirs;

  const LocalModelSpec({
    required this.id,
    required this.name,
    required this.capability,
    required this.summary,
    required this.approxSizeMb,
    required this.repo,
    this.files = const [],
    this.dirs = const [],
  });

  /// 安装后在 `AiConfig.providers` 里的厂商 id
  String get providerId => LocalModelCatalog.providerIdOf(id);

  /// 界面显示名，如「本地 · Zipformer 14M」
  String get displayName => '本地 · $name';

  /// 体积文案，如「24 MB」
  String get sizeLabel => LocalModelCatalog.formatSize(approxSizeMb);
}

class LocalModelCatalog {
  LocalModelCatalog._();

  /// 下载源。**只走 hf-mirror** —— 直连 huggingface.co 在本机实测返回空，
  /// GitHub Releases 在国内也常慢/不通。
  static const String mirrorHost = 'https://hf-mirror.com';

  // ── 模型 id（引擎按它分支，别改）──
  static const String zipformerAsrId = 'asr-zipformer-14m';
  static const String senseVoiceAsrId = 'asr-sensevoice-small';
  static const String kokoroTtsId = 'tts-kokoro-multilang';

  /// 厂商 id 前缀。`AiConfig.providers` 里靠它区分本地模型与云端厂商。
  static const String providerPrefix = 'local-';

  static String providerIdOf(String modelId) => '$providerPrefix$modelId';

  /// 反向：从厂商 id 取回模型 id；不是本地厂商则返回 null
  static String? modelIdOfProvider(String providerId) {
    if (!providerId.startsWith(providerPrefix)) return null;
    return providerId.substring(providerPrefix.length);
  }

  /// 全部可安装模型。
  ///
  /// 顺序即界面顺序：**先轻后重** —— 先看到 24 MB 的，用户更容易迈出第一步。
  static const List<LocalModelSpec> all = [
    // ── 语音识别 ──
    LocalModelSpec(
      id: zipformerAsrId,
      name: 'Zipformer 14M',
      capability: AiCapability.stt,
      summary: '中文 · 最省空间，日常说话够用',
      approxSizeMb: 24.2,
      repo: 'csukuangfj/sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23',
      files: [
        // 只取 int8 三件套；同仓库的 fp32 三件套合计 53 MB，不要。
        'encoder-epoch-99-avg-1.int8.onnx',
        'decoder-epoch-99-avg-1.int8.onnx',
        'joiner-epoch-99-avg-1.int8.onnx',
        'tokens.txt',
      ],
    ),
    LocalModelSpec(
      id: senseVoiceAsrId,
      name: 'SenseVoice Small',
      capability: AiCapability.stt,
      summary: '中英日韩粤五语 · 精度更高，体积大',
      approxSizeMb: 228.5,
      repo: 'csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17',
      files: [
        // ★ 同目录下的 `model.onnx`（fp32）是 894 MB，绝不能进这个列表。
        'model.int8.onnx',
        'tokens.txt',
      ],
    ),

    // ── 语音合成 ──
    LocalModelSpec(
      id: kokoroTtsId,
      name: 'Kokoro 多语',
      capability: AiCapability.tts,
      summary: '54 个音色 · 中英混说，音质最好',
      approxSizeMb: 161.1,
      repo: 'csukuangfj/kokoro-int8-multi-lang-v1_0',
      files: [
        'model.int8.onnx',
        'voices.bin',
        'tokens.txt',
        // 中文音素表 + 英文音素表（官方示例就是这两个，逗号分隔传给 lexicon）
        'lexicon-zh.txt',
        'lexicon-us-en.txt',
        // 中文数字 / 日期 / 电话号码的文本正则化规则
        'phone-zh.fst',
        'date-zh.fst',
        'number-zh.fst',
      ],
      // ★ espeak-ng-data 必须要：kokoro-multi-lang-lexicon.cc 的构造函数
      //   **无条件**调用 InitEspeak(data_dir)，遇到生僻词/英文夹杂时还会
      //   回退到 espeak。少了它中文长句会出错。17 MB，355 个文件。
      //
      //   仓库里那个 `dict/`（13.9 MB）反而**不用下** ——
      //   offline-tts-kokoro-model-config.cc 里写着
      //   `kokoro-dict-dir: "Not used. You don't need to provide a value for it"`。
      dirs: ['espeak-ng-data/'],
    ),
  ];

  static LocalModelSpec? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  static List<LocalModelSpec> of(AiCapability capability) =>
      all.where((s) => s.capability == capability).toList();

  /// 某个已安装模型该用哪个引擎 —— 引擎侧按 id 分支，这里只做存在性校验。
  static bool isKnownId(String id) => byId(id) != null;

  /// 目录名守卫：模型 id 必须是一段**安全的单层路径**。
  ///
  /// `LocalModelStore.uninstall` 会 `delete(recursive: true)`，
  /// 一旦 id 里混进 `..`、`/` 或空串，删掉的就可能是整个 Application Support 目录
  /// （里面装着日记的图片与录音）。所以这条守卫宁可抛错也不放行。
  ///
  /// 放在这里而不是 Store 里，是因为 Store 依赖 Flutter，跑不了纯 Dart 测试 ——
  /// 而这条守卫恰恰是**最不能只靠人眼检查**的那种代码。
  static String safeSegment(String modelId) {
    final id = modelId.trim();
    if (id.isEmpty ||
        id.contains('/') ||
        id.contains(r'\') ||
        id.contains('..') ||
        id == '.' ||
        id.startsWith('.')) {
      throw ArgumentError.value(modelId, 'modelId', '不是合法的模型 id');
    }
    return id;
  }

  // ─────────────────────────────────────────────
  // 文件挑选
  // ─────────────────────────────────────────────

  /// 从仓库全量清单里挑出这个模型需要的文件。
  ///
  /// 顺序保持与 [all] 的声明一致（files 在前、dirs 展开在后），
  /// 这样下载进度看起来是「先下大模型、再下零碎音素表」，而不是乱跳。
  static List<RemoteFileEntry> select(
    LocalModelSpec spec,
    List<RemoteFileEntry> entries,
  ) {
    final byPath = {for (final e in entries) e.path: e};

    final picked = <RemoteFileEntry>[];
    for (final path in spec.files) {
      final hit = byPath[path];
      // 清单里找不到就**直接报错**：说明仓库结构变了，
      // 继续下去只会得到一个跑不起来的模型。
      if (hit == null) {
        throw LocalModelPlanException(
          '下载源里找不到文件 `$path`（仓库 ${spec.repo} 可能已改结构）',
        );
      }
      picked.add(hit);
    }

    for (final dir in spec.dirs) {
      final inDir = entries.where((e) => e.path.startsWith(dir)).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      if (inDir.isEmpty) {
        throw LocalModelPlanException(
          '下载源里找不到目录 `$dir`（仓库 ${spec.repo} 可能已改结构）',
        );
      }
      picked.addAll(inDir);
    }

    assertNoFp32(picked);
    return picked;
  }

  /// **第二道防线**：待下载清单里不允许出现未量化的 fp32 大模型。
  ///
  /// 白名单本身已经把它们挡在外面了，但规则是手写的、会改错；
  /// 而这里漏一个文件的代价是用户白下近 1 GB 流量。宁可报错也不开下。
  ///
  /// 判定：文件名以 `.onnx` 结尾但**不含 `int8`** → 视为 fp32，拒绝。
  /// （当前三个模型需要的 .onnx 全部带 `int8`。）
  static void assertNoFp32(List<RemoteFileEntry> picked) {
    final offenders = <String>[];
    for (final e in picked) {
      final name = e.path.split('/').last;
      if (name.endsWith('.onnx') && !name.contains('int8')) {
        offenders.add(e.path);
      }
    }
    if (offenders.isNotEmpty) {
      throw LocalModelPlanException(
        '待下载清单里出现了未量化的模型文件（${offenders.join('、')}）—— '
        '这通常是「文件挑选规则」写错了。已中止下载，避免白费流量。',
      );
    }
  }

  /// 单个文件的下载地址
  static String downloadUrl(LocalModelSpec spec, String path) {
    // 逐段编码：`espeak-ng-data/voices/!v/...` 这类路径里有特殊字符，
    // 整串丢给 Uri.parse 容易把 `!`、`(` 之类解释错。
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    return '$mirrorHost/${spec.repo}/resolve/main/$encoded';
  }

  /// 仓库清单接口
  static String treeUrl(LocalModelSpec spec) =>
      '$mirrorHost/api/models/${spec.repo}/tree/main?recursive=true';

  /// 体积文案：小于 1 MB 用 KB，否则一位小数（`24.2 MB`）。
  ///
  /// 刻意保留一位小数：`24.2` 和 `228.5` 看起来是「量过的」，
  /// 整数会让人以为是拍脑袋的约数。
  static String formatSize(double mb) {
    if (mb <= 0) return '未知大小';
    if (mb < 1) return '${(mb * 1024).round()} KB';
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// 清单 / 文件挑选阶段的失败。
///
/// 单独一个类型是为了让界面能把「源站结构变了」这类问题
/// 与「网络超时」区分开，给出不同的提示。
class LocalModelPlanException implements Exception {
  final String message;

  const LocalModelPlanException(this.message);

  @override
  String toString() => message;
}

/// Kokoro 多语模型的音色表。
///
/// ## 数据来源（**别凭目录顺序猜**）
///
/// 下面这串名字是**直接抄自模型自带的 ONNX 元数据** `id2speaker`
/// （2026-10-08 从 `model.int8.onnx` 尾部 4 MB 实测读出），**顺序即 sid**。
///
/// ⚠️ 不要用 `hexgrad/Kokoro-82M` 仓库里 `voices/` 目录的字母序去推 ——
/// 那个顺序**不一样**：目录里 `em_santa` 排在第 31 位，而模型里的 sid 是 **53**。
/// （旁证：该仓库 README 自己也写着 "the Spanish `em_santa` voice at speaker ID 53"。）
///
/// 中文（普通话）音色是 sid **45–52**：4 女（xiaobei/xiaoni/xiaoxiao/xiaoyi）
/// + 4 男（yunjian/yunxi/yunxia/yunyang），与官方 VOICES.md 的 "4F 4M" 一致。
class KokoroVoices {
  KokoroVoices._();

  /// 顺序即 sid，共 54 个
  static const String id2speakerCsv =
      'af_alloy,af_aoede,af_bella,af_heart,af_jessica,af_kore,af_nicole,'
      'af_nova,af_river,af_sarah,af_sky,am_adam,am_echo,am_eric,am_fenrir,'
      'am_liam,am_michael,am_onyx,am_puck,am_santa,bf_alice,bf_emma,'
      'bf_isabella,bf_lily,bm_daniel,bm_fable,bm_george,bm_lewis,ef_dora,'
      'em_alex,ff_siwis,hf_alpha,hf_beta,hm_omega,hm_psi,if_sara,im_nicola,'
      'jf_alpha,jf_gongitsune,jf_nezumi,jf_tebukuro,jm_kumo,pf_dora,pm_alex,'
      'pm_santa,zf_xiaobei,zf_xiaoni,zf_xiaoxiao,zf_xiaoyi,zm_yunjian,'
      'zm_yunxi,zm_yunxia,zm_yunyang,em_santa';

  static final List<String> names = id2speakerCsv.split(',');

  static int get count => names.length;

  /// 默认音色：中文女声 Xiaoxiao（sid 47）。
  ///
  /// 这个 App 是中文日记，默认给一个中文音色比给 `af_alloy`（美音）
  /// 要合理得多 —— 否则用户第一次点朗读，听到的是一串英文口音念中文。
  static const int defaultVoiceId = 47;

  /// 中文音色（4 女 4 男），界面优先展示这一组
  static List<int> get chineseIds => [45, 46, 47, 48, 49, 50, 51, 52];

  static bool isValidId(int id) => id >= 0 && id < count;

  /// 把用户填的音色归一成 sid。
  ///
  /// 接受三种写法：
  /// - 数字（`47`）→ 直接用
  /// - 音色名（`zf_xiaoxiao`，大小写不敏感）→ 查表
  /// - 留空 / 认不出 → [defaultVoiceId]
  ///
  /// 认不出时**回落到默认而不是报错**：朗读是个「点了就要有反应」的功能，
  /// 因为音色写错就静默不出声，比念错音色难排查得多。
  static int resolve(String voice) {
    final v = voice.trim();
    if (v.isEmpty) return defaultVoiceId;

    final asNumber = int.tryParse(v);
    if (asNumber != null) {
      return isValidId(asNumber) ? asNumber : defaultVoiceId;
    }

    final idx = names.indexOf(v.toLowerCase());
    return idx >= 0 ? idx : defaultVoiceId;
  }

  /// `zf_xiaoxiao` → `中文女声 · Xiaoxiao`
  static String labelOf(String name) {
    if (name.length < 3 || name[2] != '_') return name;
    final lang = _langLabel(name.substring(0, 2));
    final given = name.substring(3);
    return '$lang · ${_capitalize(given)}';
  }

  /// `47` → `中文女声 · Xiaoxiao`
  static String describe(int id) =>
      isValidId(id) ? '${names[id]} · ${labelOf(names[id])}' : '未知音色';

  /// 中文音色在界面上的显示名（去掉 id 前缀，更短）
  static String shortLabel(int id) =>
      isValidId(id) ? labelOf(names[id]) : '未知音色';

  static String _langLabel(String code) {
    final gender = code.length == 2 && code[1] == 'f' ? '女声' : '男声';
    switch (code) {
      case 'af':
      case 'am':
        return '美音$gender';
      case 'bf':
      case 'bm':
        return '英音$gender';
      case 'ef':
      case 'em':
        return '西语$gender';
      case 'ff':
      case 'fm':
        return '法语$gender';
      case 'hf':
      case 'hm':
        return '印地语$gender';
      case 'if':
      case 'im':
        return '意语$gender';
      case 'jf':
      case 'jm':
        return '日语$gender';
      case 'pf':
      case 'pm':
        return '葡语$gender';
      case 'zf':
      case 'zm':
        return '中文$gender';
      default:
        return code;
    }
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
