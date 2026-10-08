/// AI 全局配置模型（对话 / 生图 / 语音 四类能力共用一个配置对象）
///
/// 只依赖 dart:convert，不引入 Flutter，便于独立测试。
library;

import 'dart:convert';

import 'ai_provider.dart';
import 'reasoning_model.dart';

class AiConfig {
  /// 配置结构版本（与旧版平铺 key 区分，用于迁移判断）
  static const int schemaVersion = 2;

  /// 内置厂商预设的修订号。
  ///
  /// 每次修正内置预设（模型名 / 地址 / 协议）就 +1。加载时若发现已存配置的
  /// 修订号落后，就把**内置厂商**的受管字段刷新到最新 —— 否则老用户会一直
  /// 带着已经失效的模型名（例如改版前的 paraformer）。
  /// 用户自建厂商完全不受影响，内置厂商的 apiKey 也会保留。
  ///
  /// 3：通义 TTS 补上 `qwen3-tts-flash` / `qwen-tts`（原列表只有 cosyvoice / sambert）。
  /// 4：**语音厂商大换血** —— 摘掉讯飞 / 百度 / 腾讯云 / 豆包（要 APPID+SecretKey
  ///    三件套 + 签名，本配置模型装不下，选了也用不了），换成 Key 为 `sk-`、
  ///    只要「地址 + 密钥 + 模型」三项的：通义 / 硅基流动 / OpenAI。
  /// 5：新增内置 TTS 厂商 **`system-tts`（系统语音）** —— 走 Android 标准
  ///    `TextToSpeech` 调手机自带引擎，零体积零权限。
  static const int currentPresetRevision = 5;

  static const String defaultSystemPrompt =
      '你是「小花」，一个住在用户日记本里的姑娘，也是用户的陪伴者。'
      '你机灵古怪：活泼、俏皮、好奇心旺盛，脑子里总有些可爱的小怪点子，'
      '说话自然亲切、不端着，偶尔会俏皮地吐槽一下，'
      '但永远懂得分寸 —— 尊重并关心用户的感受，该认真的时候一点不含糊。'
      '你拥有查询日记数据的能力：'
      '可以搜索日记内容、按日期/心情/标签筛选；'
      '查看日记统计数据（心情分布、标签使用、写作习惯）；'
      '分析写作趋势（字数变化、时间分布、连续打卡）；'
      '查看日记里的图片与录音；'
      '以及在用户同意后新建、追加、修改、删除日记。'
      '你可以根据用户的喜好和聊天风格，主动调整自己的回复语气与性格 —— '
      '用户喜欢简洁就少说废话，喜欢热闹就多些俏皮，喜欢温柔就慢一点、软一点；'
      '用户的偏好也可以从日记内容里慢慢体会。'
      '请用温暖、友善的语气回答。当用户问关于日记的问题时，'
      '优先使用工具查询真实数据，再基于数据给出有意义的分析和建议。'
      '⚠️ 问题里出现「今天 / 昨天 / 这周 / 上周 / 最近 / 上个月」这类相对时间时，'
      '必须先调用 get_current_time 拿到真实日期再计算区间 —— '
      '不要用你记忆里的日期，那一定是过期的。'
      '⚠️ 改动日记的每一个操作都必须先让用户确认，'
      '用户取消后不要重试、也不要换个说法再试一次。'
      '如果用户的问题不需要查询数据（如写作建议、情感支持），可以直接回答。'
      '当用户明确要求画图/生成图片时，可以调用生图能力。';

  /// 历史版本的默认提示词。
  ///
  /// 用途：判断用户**到底有没有手改过**提示词 ——
  /// 只有当前提示词与这里某一版完全一致，才说明它还是"默认值"，
  /// 可以在升级时安全地刷成新的 [defaultSystemPrompt]。
  /// 用户自己写过的提示词永远不会被覆盖。
  ///
  /// ⚠️ 每次改 [defaultSystemPrompt]，都要把**上一版**追加到这里。
  static const List<String> legacyDefaultSystemPrompts = <String>[
    // v1：还没有名字的「日记助手」
    '你是用户的日记助手，拥有查询日记数据的能力。'
        '你可以：搜索日记内容、按日期/心情/标签筛选；'
        '查看日记统计数据（心情分布、标签使用、写作习惯）；'
        '分析写作趋势（字数变化、时间分布、连续打卡）；'
        '查看日记里的图片与录音；'
        '以及在用户同意后新建、追加、修改、删除日记。'
        '请用温暖、友善的语气回答。当用户问关于日记的问题时，'
        '优先使用工具查询真实数据，再基于数据给出有意义的分析和建议。'
        '⚠️ 问题里出现「今天 / 昨天 / 这周 / 上周 / 最近 / 上个月」这类相对时间时，'
        '必须先调用 get_current_time 拿到真实日期再计算区间 —— '
        '不要用你记忆里的日期，那一定是过期的。'
        '⚠️ 改动日记的每一个操作都必须先让用户确认，'
        '用户取消后不要重试、也不要换个说法再试一次。'
        '如果用户的问题不需要查询数据（如写作建议、情感支持），可以直接回答。'
        '当用户明确要求画图/生成图片时，可以调用生图能力。',
  ];

  final List<AiProvider> providers;

  /// 各能力当前选中的厂商 id
  final String? chatProviderId;
  final String? imageProviderId;
  final String? ttsProviderId;
  final String? sttProviderId;

  final String systemPrompt;
  final double temperature;
  final int maxTokens;
  final int contextLimit;

  /// 思考预算：推理模型的思考过程**不占用** [maxTokens]，在它之上额外再给这么多
  /// token。0 = 关闭该特性（思考与正文共用 [maxTokens]）。
  ///
  /// 之所以要单独留额度：`max_tokens` 在多数 OpenAI 兼容网关里是「思考 + 正文」
  /// 的总上限，推理模型很容易把 2048 全花在思考上，导致正文空白。
  final int reasoningBudget;

  /// 已经观察到**确实会输出思考过程**的模型名（由 [rememberReasoningModel] 学习而来）。
  ///
  /// 名字不像推理模型的自建 / 代理模型（`my-model-v2` 之类）靠这里兜住：
  /// 见过一次 `reasoning_content`，下次请求就会给它留预算。
  final List<String> reasoningModels;

  /// 是否在回复气泡里展示模型的思考过程。
  ///
  /// 关掉只是**不显示**，思考内容仍会照常解析并落库（不占 token、不回传 API），
  /// 所以随时可以再打开，历史消息里的思考过程不会丢。
  final bool showReasoning;

  // ── P4：语音朗读 ──

  /// TTS 音色。**空串表示用协议默认**（OpenAI 系 `alloy`、DashScope `Cherry`）——
  /// 各家音色命名完全不同，写死一个反而会在换厂商后静默念错人。
  final String ttsVoice;

  /// TTS 语速倍率（UI 范围 0.5–2.0；发请求前会再夹到接口允许的 0.25–4.0）
  final double ttsSpeed;

  /// 助手回复完成后是否自动朗读
  final bool ttsAutoRead;

  /// 语音提问时是否自动朗读回复。
  ///
  /// 默认 **true** —— 用语音提问的人，默认就是想听回答。
  /// 与 [ttsAutoRead] **独立**：那个管「打字提问也念」，这个只管语音回合。
  /// 老配置读不到这个 key 时取 true：升级前根本不存在「语音提问」这条路径，
  /// 没有行为需要回退；打字提问那条路仍由 `ttsAutoRead=false` 保持不变。
  final bool ttsAutoReadVoice;

  // ── P4：显示 ──

  /// 相邻消息间隔超过 5 分钟时，是否显示居中的时间分隔（微信规则）
  final bool showTimestamp;

  /// 打字机效果。关掉后**不走流式**，等整段回复拿到再一次性显示 ——
  /// 有人就是受不了逐字跳动（尤其长回答），给他们一个开关。
  final bool typewriter;

  /// 助手回复是否按 Markdown 渲染。关掉退化为纯文本。
  final bool renderMarkdown;

  /// 聊天气泡的字号倍率，**叠加**在全局「字体大小」之上（0.8–1.5）。
  ///
  /// 和全局设置并存而不是取代它：全局管整个 App，这个只管聊天页 ——
  /// 聊天正文通常希望比日记正文大一点。
  final double bubbleFontScale;

  /// 已应用的内置预设修订号（见 [currentPresetRevision]）
  final int presetRevision;

  const AiConfig({
    this.providers = const [],
    this.chatProviderId,
    this.imageProviderId,
    this.ttsProviderId,
    this.sttProviderId,
    this.systemPrompt = defaultSystemPrompt,
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.contextLimit = 20,
    this.reasoningBudget = defaultReasoningBudget,
    this.reasoningModels = const [],
    this.showReasoning = true,
    this.ttsVoice = '',
    this.ttsSpeed = 1.0,
    this.ttsAutoRead = false,
    this.ttsAutoReadVoice = true,
    this.showTimestamp = true,
    this.typewriter = true,
    this.renderMarkdown = true,
    this.bubbleFontScale = 1.0,
    this.presetRevision = currentPresetRevision,
  });

  /// 默认思考预算。给得比 [maxTokens] 默认值大一档，留够推理模型的思考空间。
  static const int defaultReasoningBudget = 4096;

  /// 首次安装 / 配置损坏时的初始配置：内置预设 + 默认选中第一个对话厂商
  factory AiConfig.initial() {
    final presets = AiProviderPresets.all();
    final chatIds = presets
        .where((p) => p.capability == AiCapability.chat)
        .map((p) => p.id)
        .toList();
    return AiConfig(
      providers: presets,
      chatProviderId: chatIds.isEmpty ? null : chatIds.first,
    );
  }

  // ── 查询 ──

  List<AiProvider> providersOf(AiCapability capability) =>
      providers.where((p) => p.capability == capability).toList();

  AiProvider? providerById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 取某能力当前选中的厂商；若 id 失效则回退到该能力下第一个有 Key 的厂商
  AiProvider? activeProvider(AiCapability capability) {
    final id = _activeIdOf(capability);
    final byId = providerById(id);
    if (byId != null) return byId;
    final candidates = providersOf(capability);
    if (candidates.isEmpty) return null;
    return candidates.firstWhere(
      (p) => p.hasApiKey,
      orElse: () => candidates.first,
    );
  }

  String? activeIdOf(AiCapability capability) => _activeIdOf(capability);

  String? _activeIdOf(AiCapability capability) {
    switch (capability) {
      case AiCapability.chat:
        return chatProviderId;
      case AiCapability.image:
        return imageProviderId;
      case AiCapability.tts:
        return ttsProviderId;
      case AiCapability.stt:
        return sttProviderId;
    }
  }

  /// 是否已具备可用的对话配置（供旧的 isConfigured 使用）
  bool get hasUsableChatProvider {
    final p = activeProvider(AiCapability.chat);
    return p != null && p.hasApiKey;
  }

  // ── 变更 ──

  AiConfig copyWith({
    List<AiProvider>? providers,
    String? chatProviderId,
    String? imageProviderId,
    String? ttsProviderId,
    String? sttProviderId,
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
    int? contextLimit,
    int? reasoningBudget,
    List<String>? reasoningModels,
    bool? showReasoning,
    String? ttsVoice,
    double? ttsSpeed,
    bool? ttsAutoRead,
    bool? ttsAutoReadVoice,
    bool? showTimestamp,
    bool? typewriter,
    bool? renderMarkdown,
    double? bubbleFontScale,
    int? presetRevision,
    bool clearChatProviderId = false,
    bool clearImageProviderId = false,
    bool clearTtsProviderId = false,
    bool clearSttProviderId = false,
  }) {
    return AiConfig(
      providers: providers ?? this.providers,
      chatProviderId:
          clearChatProviderId ? null : (chatProviderId ?? this.chatProviderId),
      imageProviderId: clearImageProviderId
          ? null
          : (imageProviderId ?? this.imageProviderId),
      ttsProviderId:
          clearTtsProviderId ? null : (ttsProviderId ?? this.ttsProviderId),
      sttProviderId:
          clearSttProviderId ? null : (sttProviderId ?? this.sttProviderId),
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      contextLimit: contextLimit ?? this.contextLimit,
      reasoningBudget: reasoningBudget ?? this.reasoningBudget,
      reasoningModels: reasoningModels ?? this.reasoningModels,
      showReasoning: showReasoning ?? this.showReasoning,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      ttsAutoRead: ttsAutoRead ?? this.ttsAutoRead,
      ttsAutoReadVoice: ttsAutoReadVoice ?? this.ttsAutoReadVoice,
      showTimestamp: showTimestamp ?? this.showTimestamp,
      typewriter: typewriter ?? this.typewriter,
      renderMarkdown: renderMarkdown ?? this.renderMarkdown,
      bubbleFontScale: bubbleFontScale ?? this.bubbleFontScale,
      presetRevision: presetRevision ?? this.presetRevision,
    );
  }

  /// 新增或替换一个厂商（按 id 匹配）
  AiConfig upsertProvider(AiProvider provider) {
    final list = [...providers];
    final idx = list.indexWhere((p) => p.id == provider.id);
    if (idx >= 0) {
      list[idx] = provider;
    } else {
      list.add(provider);
    }
    return copyWith(providers: list);
  }

  /// 删除一个厂商；若删除的是当前选中项，则自动切换到该能力下的第一个厂商
  AiConfig removeProvider(String id) {
    final removed = providerById(id);
    if (removed == null) return this;

    final list = providers.where((p) => p.id != id).toList();
    final fallbackIds = list
        .where((p) => p.capability == removed.capability)
        .map((p) => p.id)
        .toList();
    final fallback = fallbackIds.isEmpty ? null : fallbackIds.first;

    var next = copyWith(providers: list);
    switch (removed.capability) {
      case AiCapability.chat:
        if (next.chatProviderId == id) {
          next = next.copyWith(
            chatProviderId: fallback,
            clearChatProviderId: fallback == null,
          );
        }
        break;
      case AiCapability.image:
        if (next.imageProviderId == id) {
          next = next.copyWith(
            imageProviderId: fallback,
            clearImageProviderId: fallback == null,
          );
        }
        break;
      case AiCapability.tts:
        if (next.ttsProviderId == id) {
          next = next.copyWith(
            ttsProviderId: fallback,
            clearTtsProviderId: fallback == null,
          );
        }
        break;
      case AiCapability.stt:
        if (next.sttProviderId == id) {
          next = next.copyWith(
            sttProviderId: fallback,
            clearSttProviderId: fallback == null,
          );
        }
        break;
    }
    return next;
  }

  /// 设置某能力当前选中的厂商
  AiConfig selectProvider(AiCapability capability, String id) {
    switch (capability) {
      case AiCapability.chat:
        return copyWith(chatProviderId: id);
      case AiCapability.image:
        return copyWith(imageProviderId: id);
      case AiCapability.tts:
        return copyWith(ttsProviderId: id);
      case AiCapability.stt:
        return copyWith(sttProviderId: id);
    }
  }

  /// 取某能力当前实际使用的模型名
  String? activeModel(AiCapability capability) {
    final p = activeProvider(capability);
    if (p == null) return null;
    final m = p.effectiveModel;
    return m.isEmpty ? null : m;
  }

  /// 这个模型是否按「会先思考」处理（名字像 **或** 已经学过，见 [reasoningModels]）
  bool isReasoningModel(String model) {
    if (model.isEmpty) return false;
    if (reasoningModels.contains(model)) return true;
    return looksLikeReasoningModel(model);
  }

  /// 本次请求实际要发出去的 `max_tokens` —— 推理模型会在正文额度之上再加
  /// [reasoningBudget]，保证思考过程不挤占正文。
  int effectiveMaxTokensFor(String model) => effectiveMaxTokens(
        maxTokens: maxTokens,
        reasoningBudget: reasoningBudget,
        isReasoning: isReasoningModel(model),
      );

  /// 为某能力当前选中的厂商设置模型
  AiConfig selectModel(AiCapability capability, String model) {
    final p = activeProvider(capability);
    if (p == null) return this;
    return upsertProvider(p.copyWith(selectedModel: model));
  }

  /// 记下「这个模型会输出思考过程」，下次请求就会给它留预算。
  ///
  /// 已经在集合里就原样返回（`identical` 可用于判断是否需要写盘）。
  AiConfig rememberReasoningModel(String model) {
    if (model.isEmpty || reasoningModels.contains(model)) return this;
    return copyWith(reasoningModels: [...reasoningModels, model]);
  }

  // ── 序列化 ──

  Map<String, dynamic> toMap() => {
        'version': schemaVersion,
        'providers': providers.map((p) => p.toMap()).toList(),
        'chatProviderId': chatProviderId,
        'imageProviderId': imageProviderId,
        'ttsProviderId': ttsProviderId,
        'sttProviderId': sttProviderId,
        'systemPrompt': systemPrompt,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'contextLimit': contextLimit,
        'reasoningBudget': reasoningBudget,
        'reasoningModels': reasoningModels,
        'showReasoning': showReasoning,
        'ttsVoice': ttsVoice,
        'ttsSpeed': ttsSpeed,
        'ttsAutoRead': ttsAutoRead,
        'ttsAutoReadVoice': ttsAutoReadVoice,
        'showTimestamp': showTimestamp,
        'typewriter': typewriter,
        'renderMarkdown': renderMarkdown,
        'bubbleFontScale': bubbleFontScale,
        'presetRevision': presetRevision,
      };

  String toJsonString() => jsonEncode(toMap());

  factory AiConfig.fromMap(Map<String, dynamic> map) {
    final rawProviders = map['providers'];
    final providers = <AiProvider>[];
    if (rawProviders is List) {
      for (final item in rawProviders) {
        if (item is Map) {
          providers.add(AiProvider.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    return AiConfig(
      providers: providers,
      chatProviderId: map['chatProviderId'] as String?,
      imageProviderId: map['imageProviderId'] as String?,
      ttsProviderId: map['ttsProviderId'] as String?,
      sttProviderId: map['sttProviderId'] as String?,
      systemPrompt: (map['systemPrompt'] as String?) ?? defaultSystemPrompt,
      temperature: _toDouble(map['temperature'], 0.7),
      maxTokens: _toInt(map['maxTokens'], 2048),
      contextLimit: _toInt(map['contextLimit'], 20),
      // 老配置没有这个 key → 用默认值（思考不占用正文额度）
      reasoningBudget: _toInt(map['reasoningBudget'], defaultReasoningBudget),
      reasoningModels: _strList(map['reasoningModels']),
      // 老配置没有这个 key → 默认展示（此前就是这么做的，不能因为升级就突然不显示）
      showReasoning: _toBool(map['showReasoning'], true),
      // 以下 7 项都是 P4 新增；老配置读不到 key 时全部取「与升级前一致」的值，
      // 不能让用户升级完发现界面变了样。
      ttsVoice: (map['ttsVoice'] as String?) ?? '',
      ttsSpeed: _toDouble(map['ttsSpeed'], 1.0),
      ttsAutoRead: _toBool(map['ttsAutoRead'], false),
      // 老配置没有这个 key → true（见字段注释：语音提问这条路径升级前不存在）
      ttsAutoReadVoice: _toBool(map['ttsAutoReadVoice'], true),
      showTimestamp: _toBool(map['showTimestamp'], true),
      typewriter: _toBool(map['typewriter'], true),
      renderMarkdown: _toBool(map['renderMarkdown'], true),
      bubbleFontScale: _toDouble(map['bubbleFontScale'], 1.0),
      // 老配置没有这个 key → 0 → 触发一次内置预设刷新
      presetRevision: _toInt(map['presetRevision'], 0),
    );
  }

  factory AiConfig.fromJsonString(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return AiConfig.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // 配置损坏时回退到初始配置，不能让 AI 功能不可用
    }
    return AiConfig.initial();
  }

  /// 补齐缺失的内置厂商（例如版本升级后新增了预设），不影响用户已有配置
  AiConfig withMissingPresets() {
    final existingIds = providers.map((p) => p.id).toSet();
    final missing =
        AiProviderPresets.all().where((p) => !existingIds.contains(p.id));
    if (missing.isEmpty) return this;
    return copyWith(providers: [...providers, ...missing]);
  }

  /// 把内置厂商的「受管字段」同步到当前预设修订。
  ///
  /// 受管字段：名称 / 协议 / 地址 / 模型列表 / 模型前缀。
  /// **保留**：apiKey、extra，以及仍然在新模型列表里的 selectedModel。
  /// 用户自建厂商（isBuiltin == false）完全不碰。
  ///
  /// 修订号已是最新时直接返回 this，不做任何改动。
  ///
  /// ★ 修订 4 起还会**摘掉预设里已经不存在的内置厂商**（见 [currentPresetRevision]）。
  /// 在此之前这里只做「刷新」不做「删除」，`if (preset == null) return p;` 会把
  /// 废弃的内置厂商永久留在用户配置里 —— 列表越滚越长，而且选中的那个再也用不了。
  AiConfig refreshBuiltinPresets() {
    if (presetRevision >= currentPresetRevision) return this;

    final presets = <String, AiProvider>{
      for (final p in AiProviderPresets.all()) p.id: p,
    };

    // 1) 先摘掉「预设里已经没有」的内置厂商。
    //
    //    走 removeProvider 而不是自己拼列表：它会顺带把**悬空的能力选择**
    //    落到该能力下的第一个厂商，这正是我们要的副作用 ——
    //    否则 ttsProviderId 会一直指着一个已经不存在的 id，设置页显示成「未选择」。
    var next = this;
    for (final p in providers) {
      if (p.isBuiltin && !presets.containsKey(p.id)) {
        next = next.removeProvider(p.id);
      }
    }

    // 2) 再刷新还在预设里的内置厂商（保留 apiKey / extra / 仍然有效的 selectedModel）
    final synced = next.providers.map((p) {
      if (!p.isBuiltin) return p;
      final preset = presets[p.id];
      if (preset == null) return p;

      final selected = p.selectedModel;
      return AiProvider(
        id: p.id,
        name: preset.name,
        capability: p.capability,
        protocol: preset.protocol,
        baseUrl: preset.baseUrl,
        apiKey: p.apiKey,
        models: preset.models,
        selectedModel:
            (selected != null && preset.models.contains(selected)) ? selected : null,
        modelPrefix: preset.modelPrefix,
        isBuiltin: true,
        extra: p.extra,
      );
    }).toList();

    return next.copyWith(
      providers: synced,
      presetRevision: currentPresetRevision,
    );
  }

  /// 把「还是默认值」的系统提示词刷成最新默认值。
  ///
  /// 为什么需要它：配置在**每次 load 时都会落盘**（`AiConfigStore.load` 末尾
  /// 有一次 `setString`），所以哪怕用户从没打开过 AI 设置，老默认提示词也
  /// 已经被写进 SharedPreferences 了。只改 [defaultSystemPrompt] 常量，
  /// 老设备永远拿不到新提示词 —— 和内置厂商预设需要 `presetRevision` 是同一个坑。
  ///
  /// 判定方式：当前提示词与 [legacyDefaultSystemPrompts] 里任意一版**逐字相同**
  /// （忽略首尾空白）→ 视为没改过 → 刷新。用户自己写过的绝不覆盖。
  AiConfig refreshDefaultSystemPrompt() {
    final current = systemPrompt.trim();
    if (current.isEmpty) {
      return copyWith(systemPrompt: defaultSystemPrompt);
    }
    if (current == defaultSystemPrompt.trim()) return this;

    for (final legacy in legacyDefaultSystemPrompts) {
      if (current == legacy.trim()) {
        return copyWith(systemPrompt: defaultSystemPrompt);
      }
    }
    return this;
  }

  static double _toDouble(dynamic v, double fallback) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static int _toInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// 字符串列表；非字符串条目直接跳过（配置被手改坏也不该让 AI 用不了）
  static List<String> _strList(dynamic v) {
    if (v is! List) return const [];
    return v.whereType<String>().where((s) => s.isNotEmpty).toList();
  }

  /// 布尔；兼容 JSON 里被写成字符串的 "true" / "false"
  static bool _toBool(dynamic v, bool fallback) {
    if (v is bool) return v;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
    }
    return fallback;
  }
}
