/// AI 能力与厂商配置模型
///
/// 本文件只依赖 dart:convert，不引入 Flutter，便于独立测试。
library;

import 'dart:convert';

/// AI 能力类型
enum AiCapability {
  chat,
  image,
  tts,
  stt;

  static AiCapability fromValue(String? v) {
    return AiCapability.values.firstWhere(
      (e) => e.name == v,
      orElse: () => AiCapability.chat,
    );
  }

  String get label {
    switch (this) {
      case AiCapability.chat:
        return '对话';
      case AiCapability.image:
        return '生图';
      case AiCapability.tts:
        return '语音合成';
      case AiCapability.stt:
        return '语音识别';
    }
  }
}

/// 请求协议类型（决定使用哪个适配器）
enum AiProtocol {
  openAiCompat,
  dashScope,
  xunfei,
  baidu,
  tencent,

  /// **本地离线模型**（sherpa-onnx）。
  ///
  /// 它**不发任何网络请求**，也不需要 Key / 地址 —— [SttClient] / [TtsClient]
  /// 在入口按协议分流到 `LocalAsrEngine` / `LocalTtsEngine`。
  ///
  /// 之所以做成一个协议值、而不是另立一套「本地模型选中」机制：
  /// 这样它天然融进现有的「选厂商」交互（`ProviderManageScreen` +
  /// `AiConfig.activeProvider()`），卸载后的「悬空选择自动回落」也能直接复用
  /// `removeProvider` 的现成逻辑，零新概念。
  local,

  /// **系统自带语音**（Android 标准 `TextToSpeech`）。
  ///
  /// 与 [local] 一样：不走网络、不需要 Key / 地址。[TtsClient] 在入口按协议
  /// 分流到 `SystemTts`，由它把文字交给**手机自带的 TTS 引擎**朗读。
  ///
  /// 和 [local] 的区别：
  /// - `local` = 把模型下载到手机里自己跑（跨机一致、可挑音色、占体积）；
  /// - `system` = 借用手机里已有的引擎（**零体积、零权限、首字最快**，
  ///   但音色随手机走，且**拿不到音频字节** —— 边合成边播）。
  ///
  /// 因为是「边合成边播」，依赖音频字节的功能（导出音频）对它必须显式禁用。
  ///
  /// ⚠️ 使用它要求在 AndroidManifest 里声明
  /// `<queries><intent><action android:name="android.intent.action.TTS_SERVICE"/>`
  /// —— API 30+ 的包可见性机制会让 App 看不见 TTS 引擎。
  system,

  custom;

  static AiProtocol fromValue(String? v) {
    return AiProtocol.values.firstWhere(
      (e) => e.name == v,
      orElse: () => AiProtocol.openAiCompat,
    );
  }

  String get label {
    switch (this) {
      case AiProtocol.openAiCompat:
        return 'OpenAI 兼容';
      case AiProtocol.dashScope:
        return '阿里 DashScope';
      case AiProtocol.xunfei:
        return '讯飞';
      case AiProtocol.baidu:
        return '百度';
      case AiProtocol.tencent:
        return '腾讯云';
      case AiProtocol.local:
        return '本地模型';
      case AiProtocol.system:
        return '系统语音';
      case AiProtocol.custom:
        return '自定义';
    }
  }
}

/// 一个「厂商 + 能力」的配置
class AiProvider {
  final String id;
  final String name;
  final AiCapability capability;
  final AiProtocol protocol;
  final String baseUrl;
  final String apiKey;
  final List<String> models;

  /// 当前选中的模型名；为空时回退到 [effectiveModel]
  final String? selectedModel;
  final String? modelPrefix;
  final bool isBuiltin;
  final Map<String, String> extra;

  const AiProvider({
    required this.id,
    required this.name,
    required this.capability,
    this.protocol = AiProtocol.openAiCompat,
    this.baseUrl = '',
    this.apiKey = '',
    this.models = const [],
    this.selectedModel,
    this.modelPrefix,
    this.isBuiltin = false,
    this.extra = const {},
  });

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  /// 这个厂商是否**需要** API Key / API 地址。
  ///
  /// 本地离线模型（[AiProtocol.local]）跑在手机里，既没有密钥也没有服务地址，
  /// 概念上就不存在「没配好」这回事。所有 `hasApiKey` / `baseUrl` 校验都必须
  /// 先过这一关 —— 否则本地模型会被上游守卫**静默拦下**，界面上还显示
  /// 「（缺少密钥）」，用户根本无从下手。
  ///
  /// [AiProtocol.system] 同理：系统自带语音由手机提供，没有密钥与地址。
  bool get needsApiKey =>
      protocol != AiProtocol.local && protocol != AiProtocol.system;

  /// 实际使用的模型名：优先用户选中的，否则取列表第一个
  String get effectiveModel {
    final sel = selectedModel;
    if (sel != null && sel.trim().isNotEmpty) return sel;
    return models.isEmpty ? '' : models.first;
  }

  AiProvider copyWith({
    String? id,
    String? name,
    AiCapability? capability,
    AiProtocol? protocol,
    String? baseUrl,
    String? apiKey,
    List<String>? models,
    String? selectedModel,
    String? modelPrefix,
    bool? isBuiltin,
    Map<String, String>? extra,
  }) {
    return AiProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      capability: capability ?? this.capability,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      models: models ?? this.models,
      selectedModel: selectedModel ?? this.selectedModel,
      modelPrefix: modelPrefix ?? this.modelPrefix,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      extra: extra ?? this.extra,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'capability': capability.name,
        'protocol': protocol.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'models': models,
        'selectedModel': selectedModel,
        'modelPrefix': modelPrefix,
        'isBuiltin': isBuiltin,
        'extra': extra,
      };

  factory AiProvider.fromMap(Map<String, dynamic> map) {
    return AiProvider(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      capability: AiCapability.fromValue(map['capability'] as String?),
      protocol: AiProtocol.fromValue(map['protocol'] as String?),
      baseUrl: (map['baseUrl'] as String?) ?? '',
      apiKey: (map['apiKey'] as String?) ?? '',
      models: _parseStringList(map['models']),
      selectedModel: map['selectedModel'] as String?,
      modelPrefix: map['modelPrefix'] as String?,
      isBuiltin: (map['isBuiltin'] as bool?) ?? false,
      extra: _parseStringMap(map['extra']),
    );
  }

  /// 供「更新模型列表」使用：合并新发现的模型并去重
  AiProvider mergeModels(List<String> discovered) {
    final merged = <String>{...models, ...discovered}.toList();
    return copyWith(models: merged);
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.whereType<String>().toList();
      } catch (_) {}
    }
    return const [];
  }

  static Map<String, String> _parseStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return const {};
  }
}

/// 内置厂商预设（用户可编辑，内置项不可删除）
class AiProviderPresets {
  AiProviderPresets._();

  /// 内置「系统语音」厂商的 id。
  ///
  /// 单独抽成常量：界面层要按它**从云端列表里排除**、并单独渲染一个分区
  /// （它没有地址 / 密钥 / 模型，混在云端列表里会显示成「未配置」）。
  static const String systemTtsId = 'system-tts';

  /// 生成一套全新的内置预设（每次返回新实例，避免被就地修改）
  static List<AiProvider> all() => [
        // ── 对话（全部 OpenAI 兼容协议）──
        const AiProvider(
          id: 'deepseek',
          name: 'DeepSeek',
          capability: AiCapability.chat,
          baseUrl: 'https://api.deepseek.com/v1',
          models: ['deepseek-chat', 'deepseek-reasoner'],
          modelPrefix: 'deepseek-',
          isBuiltin: true,
        ),
        const AiProvider(
          id: 'qwen',
          name: '通义千问',
          capability: AiCapability.chat,
          baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
          models: ['qwen-turbo', 'qwen-plus', 'qwen-max'],
          modelPrefix: 'qwen-',
          isBuiltin: true,
        ),
        const AiProvider(
          id: 'glm',
          name: '智谱 GLM',
          capability: AiCapability.chat,
          baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
          models: ['glm-4-flash', 'glm-4'],
          modelPrefix: 'glm-',
          isBuiltin: true,
        ),
        const AiProvider(
          id: 'moonshot',
          name: '月之暗面',
          capability: AiCapability.chat,
          baseUrl: 'https://api.moonshot.cn/v1',
          models: ['moonshot-v1-8k', 'moonshot-v1-32k'],
          modelPrefix: 'moonshot-',
          isBuiltin: true,
        ),
        const AiProvider(
          id: 'doubao',
          name: '豆包',
          capability: AiCapability.chat,
          baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
          models: ['doubao-1.5-pro-32k', 'doubao-1.5-lite-32k'],
          // 豆包使用用户自定义端点 ID（ep-xxxx），不做前缀过滤
          isBuiltin: true,
        ),

        // ── 生图：按需求默认「自定义」，不提供预设 ──

        // ── 语音识别 STT ──
        //
        // 选型标准（2026-10-05 定）：**Key 是 `sk-` 开头、只需填「地址 + 密钥 +
        // 模型」三项**。讯飞 / 百度 / 腾讯云那套要 APPID + APIKey + SecretKey
        // 三件套再做 HMAC / TC3 签名，而本项目的配置模型只有**一个** apiKey
        // 字段 —— 根本装不下，摆在列表里只会让人填完还是用不了，已移除。
        // 豆包语音同理（openspeech 走 WebSocket + X-Api-App-Key / Access-Key），
        // 原先那条 `Bearer + /api/v3/audio/transcriptions` 实际打不通，一并移除。
        // 通义排在最前：它的 Key 与对话/语音合成本来就是同一把（同一个 DashScope
        // 账号），已经配过对话的人不用再申请新账号就能用。
        // 硅基流动的 SenseVoiceSmall 是**免费**额度，想省钱可以换过去。
        const AiProvider(
          id: 'qwen-stt',
          name: '通义 Qwen-ASR',
          capability: AiCapability.stt,
          protocol: AiProtocol.dashScope,
          baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
          models: ['qwen3-asr-flash'],
          isBuiltin: true,
        ),
        const AiProvider(
          id: 'siliconflow-stt',
          name: '硅基流动 SenseVoice',
          capability: AiCapability.stt,
          protocol: AiProtocol.openAiCompat,
          baseUrl: 'https://api.siliconflow.cn/v1',
          models: ['FunAudioLLM/SenseVoiceSmall', 'TeleAI/TeleSpeechASR'],
          isBuiltin: true,
        ),
        const AiProvider(
          id: 'openai-stt',
          name: 'OpenAI Whisper',
          capability: AiCapability.stt,
          protocol: AiProtocol.openAiCompat,
          baseUrl: 'https://api.openai.com/v1',
          models: ['whisper-1', 'gpt-4o-transcribe', 'gpt-4o-mini-transcribe'],
          isBuiltin: true,
        ),

        // ── 语音合成 TTS ──
        //
        // 「系统语音」排最前：它**零体积、零权限、开箱即用** —— 新装用户
        // 什么都不用配就能朗读（`AiConfig.initial()` 只指定 chat，其余能力
        // 靠 `activeProvider()` 的 `firstWhere(hasApiKey)` 兜底，没有 Key 时
        // 落到列表第一个）。已经选过别的厂商的老用户不受影响：
        // `refreshBuiltinPresets()` 只刷新内置厂商的受管字段，**不动选择**。
        const AiProvider(
          id: systemTtsId,
          name: '系统语音',
          capability: AiCapability.tts,
          protocol: AiProtocol.system,
          isBuiltin: true,
        ),
        //
        // 通义排在最前（云端里）：它的默认音色（Cherry）与 qwen3-tts-flash 配套，
        // 用户什么都不改就能出声；换成 cosyvoice-v1 得自己把音色改成 longxiaochun。
        //
        // 硅基流动的 `voice` 官方硬性要求 **`模型名:音色名`** 的形态
        // （`FunAudioLLM/CosyVoice2-0.5B:alex`），留空落到通用的 `alloy` 会被拒。
        // 这个坑在 tts_codec.dart 里统一兜住了：只要地址是 siliconflow，
        // 留空 / 只写短名（`alex`）都会自动补成完整形态，用户不必手填。
        const AiProvider(
          id: 'qwen-tts',
          name: '通义 CosyVoice',
          capability: AiCapability.tts,
          protocol: AiProtocol.dashScope,
          baseUrl: 'https://dashscope.aliyuncs.com/api/v1',
          models: [
            'qwen3-tts-flash',
            'qwen-tts',
            'cosyvoice-v1',
            'sambert-zhichu-v1',
          ],
          isBuiltin: true,
        ),
        const AiProvider(
          id: 'siliconflow-tts',
          name: '硅基流动 CosyVoice',
          capability: AiCapability.tts,
          protocol: AiProtocol.openAiCompat,
          baseUrl: 'https://api.siliconflow.cn/v1',
          // 只列 CosyVoice2-0.5B：同平台的 `fnlp/MOSS-TTSD-v0.5` 必须同时带
          // `references`（参考音频）+ `stream`，`voice` 填什么都不对 ——
          // 它不是一个「选个音色就能念」的模型，列出来只会让人配完就报错。
          models: ['FunAudioLLM/CosyVoice2-0.5B'],
          isBuiltin: true,
        ),
        const AiProvider(
          id: 'openai-tts',
          name: 'OpenAI TTS',
          capability: AiCapability.tts,
          protocol: AiProtocol.openAiCompat,
          baseUrl: 'https://api.openai.com/v1',
          models: ['gpt-4o-mini-tts', 'tts-1', 'tts-1-hd'],
          isBuiltin: true,
        ),
      ];

  /// 内置厂商 id 集合（用于判断是否可删除）
  static Set<String> get builtinIds =>
      all().map((p) => p.id).toSet();
}
