import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/app_chrome_provider.dart';
import '../models/ai_config.dart';
import '../models/ai_provider.dart';
import '../providers/chat_session_provider.dart';
import '../services/ai_config_store.dart';
import '../services/chat_export_service.dart';
import '../services/tts_codec.dart';
import '../widgets/chat_export_sheet.dart';
import 'provider_manage_screen.dart';

/// AI 助手内部设置（只从聊天页进入，与全局设置分离）。
///
/// 包含：各能力的厂商与模型、对话参数、会话管理。
class AiAssistantSettingsScreen extends StatefulWidget {
  const AiAssistantSettingsScreen({super.key});

  @override
  State<AiAssistantSettingsScreen> createState() =>
      _AiAssistantSettingsScreenState();
}

class _AiAssistantSettingsScreenState
    extends State<AiAssistantSettingsScreen> {
  AiConfig? _config;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final config = await AiConfigStore.load(force: true);
    if (!mounted) return;
    setState(() => _config = config);
  }

  Future<void> _update(
    AiConfig Function(AiConfig current) transform,
  ) async {
    await AiConfigStore.update(transform);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = _config;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkTitleText : AppColors.titleText,
        ),
        title: Text(
          'AI 助手设置',
          style: AppTextStyles.heading.copyWith(
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            fontSize: 20,
          ),
        ),
      ),
      body: config == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _sectionTitle(isDark, '模型与厂商'),
                _card(isDark, [
                  ...AiCapability.values.map(
                    (c) => _capabilityTile(isDark, config, c),
                  ),
                ]),
                const SizedBox(height: 18),
                _sectionTitle(isDark, '对话参数'),
                _card(isDark, [
                  SwitchListTile(
                    secondary: Icon(
                      Icons.psychology_outlined,
                      size: 20,
                      color: isDark ? AppColors.darkPink : AppColors.pinkDark,
                    ),
                    title: Text(
                      '显示思考过程',
                      style: AppTextStyles.body.copyWith(
                        color: isDark
                            ? AppColors.darkTitleText
                            : AppColors.titleText,
                      ),
                    ),
                    subtitle: Text(
                      '在回复上方展示模型的推理过程；'
                      '关掉只是不显示，思考内容仍会保存',
                      style: AppTextStyles.label.copyWith(
                        color: isDark
                            ? AppColors.darkLabelText
                            : AppColors.labelText,
                      ),
                    ),
                    value: config.showReasoning,
                    activeThumbColor: AppColors.darkGoldAccent,
                    onChanged: (v) =>
                        _update((c) => c.copyWith(showReasoning: v)),
                  ),
                  _divider(isDark),
                  _systemPromptTile(isDark, config),
                  _divider(isDark),
                  _sliderTile(
                    isDark,
                    title: '温度',
                    subtitle: '越低越稳定，越高越有创意',
                    value: config.temperature,
                    min: 0,
                    max: 2,
                    divisions: 20,
                    display: config.temperature.toStringAsFixed(1),
                    onChanged: (v) => _update((c) => c.copyWith(temperature: v)),
                  ),
                  _divider(isDark),
                  _sliderTile(
                    isDark,
                    title: '上下文轮数',
                    subtitle: '每次请求携带的历史消息条数',
                    value: config.contextLimit.toDouble(),
                    min: 4,
                    max: 50,
                    divisions: 46,
                    display: '${config.contextLimit} 条',
                    onChanged: (v) => _update(
                      (c) => c.copyWith(contextLimit: v.round()),
                    ),
                  ),
                  _divider(isDark),
                  _sliderTile(
                    isDark,
                    title: '单次回复上限',
                    subtitle: 'max_tokens，「正文」的长度上限（思考过程另算）',
                    value: config.maxTokens.toDouble(),
                    min: 256,
                    max: 8192,
                    divisions: 31,
                    display: '${config.maxTokens}',
                    onChanged: (v) => _update(
                      (c) => c.copyWith(maxTokens: (v / 256).round() * 256),
                    ),
                  ),
                  _divider(isDark),
                  _sliderTile(
                    isDark,
                    title: '思考预算',
                    subtitle: '推理模型额外留给思考的 token，'
                        '不占用上面的回复上限；0 = 不额外留',
                    value: config.reasoningBudget.toDouble(),
                    min: 0,
                    max: 16384,
                    divisions: 16,
                    display: config.reasoningBudget == 0
                        ? '不额外留'
                        : '${config.reasoningBudget}',
                    onChanged: (v) => _update(
                      (c) => c.copyWith(
                        reasoningBudget: (v / 1024).round() * 1024,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                _sectionTitle(isDark, '显示'),
                _card(isDark, [
                  _switchTile(
                    isDark,
                    icon: Icons.schedule_outlined,
                    title: '显示时间分隔',
                    subtitle: '相邻消息间隔超过 5 分钟时，插入一条居中时间',
                    value: config.showTimestamp,
                    onChanged: (v) => _update((c) => c.copyWith(showTimestamp: v)),
                  ),
                  _divider(isDark),
                  _switchTile(
                    isDark,
                    icon: Icons.auto_awesome_motion_outlined,
                    title: '打字机效果',
                    subtitle: '逐字显示回复。关掉后等整段回复生成完再一次性出现',
                    value: config.typewriter,
                    onChanged: (v) => _update((c) => c.copyWith(typewriter: v)),
                  ),
                  _divider(isDark),
                  _switchTile(
                    isDark,
                    icon: Icons.format_shapes_outlined,
                    title: 'Markdown 渲染',
                    subtitle: '助手回复按 Markdown 排版；关掉退化为纯文本',
                    value: config.renderMarkdown,
                    onChanged: (v) =>
                        _update((c) => c.copyWith(renderMarkdown: v)),
                  ),
                  _divider(isDark),
                  _sliderTile(
                    isDark,
                    title: '气泡字号',
                    subtitle: '只影响聊天气泡正文，叠加在全局「字体大小」之上',
                    value: config.bubbleFontScale,
                    min: 0.8,
                    max: 1.5,
                    divisions: 14,
                    display: '${(config.bubbleFontScale * 100).round()}%',
                    onChanged: (v) => _update(
                      (c) => c.copyWith(
                        bubbleFontScale: (v * 10).round() / 10,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                _sectionTitle(isDark, '悬浮球'),
                _card(isDark, [
                  _switchTile(
                    isDark,
                    icon: Icons.auto_awesome_outlined,
                    title: '显示悬浮球',
                    subtitle: '在日记 / 成就 / 回顾等页面显示可拖动的 AI 助手图标；'
                        '设置页、聊天页、写日记页与弹层里会自动隐藏',
                    value: context.watch<AppChromeProvider>().orbEnabled,
                    onChanged: (v) =>
                        context.read<AppChromeProvider>().setOrbEnabled(v),
                  ),
                ]),
                const SizedBox(height: 18),
                _sectionTitle(isDark, '语音'),
                _card(isDark, [
                  _switchTile(
                    isDark,
                    icon: Icons.record_voice_over_outlined,
                    title: '自动朗读回复',
                    subtitle: '打字提问时，每条回复生成完自动念一遍；可随时点气泡下方的「停止」',
                    value: config.ttsAutoRead,
                    onChanged: (v) => _update((c) => c.copyWith(ttsAutoRead: v)),
                  ),
                  _divider(isDark),
                  _switchTile(
                    isDark,
                    icon: Icons.mic_none_rounded,
                    title: '语音提问时朗读回复',
                    subtitle: '悬浮球长按说话提问时，回复默认念一遍'
                        '（这类回合只要 150 字以内的简短回答）',
                    value: config.ttsAutoReadVoice,
                    onChanged: (v) =>
                        _update((c) => c.copyWith(ttsAutoReadVoice: v)),
                  ),
                  _divider(isDark),
                  _ttsVoiceTile(isDark, config),
                  _divider(isDark),
                  _sliderTile(
                    isDark,
                    title: '语速',
                    subtitle: '部分厂商不支持调节，会忽略这个值',
                    value: config.ttsSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    display: '${config.ttsSpeed.toStringAsFixed(1)}×',
                    onChanged: (v) => _update(
                      (c) => c.copyWith(ttsSpeed: (v * 10).round() / 10),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                _sectionTitle(isDark, '会话'),
                _card(isDark, [
                  ListTile(
                    leading: Icon(
                      Icons.ios_share_rounded,
                      size: 20,
                      color: isDark ? AppColors.darkPink : AppColors.pinkDark,
                    ),
                    title: Text(
                      '导出当前会话',
                      style: AppTextStyles.body.copyWith(
                        color: isDark
                            ? AppColors.darkTitleText
                            : AppColors.titleText,
                      ),
                    ),
                    subtitle: Text(
                      '导出为 Markdown / 纯文本 / JSON 并分享',
                      style: AppTextStyles.label.copyWith(
                        color: isDark
                            ? AppColors.darkLabelText
                            : AppColors.labelText,
                      ),
                    ),
                    onTap: _exportCurrentSession,
                  ),
                  _divider(isDark),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined,
                        color: AppColors.deleteRed, size: 20),
                    title: Text(
                      '清空全部会话',
                      style: AppTextStyles.body.copyWith(
                        color: isDark
                            ? AppColors.darkBodyText
                            : AppColors.bodyText,
                      ),
                    ),
                    subtitle: Text(
                      '删除所有会话与消息，不可恢复',
                      style: AppTextStyles.label.copyWith(
                        color: isDark
                            ? AppColors.darkLabelText
                            : AppColors.labelText,
                      ),
                    ),
                    onTap: _confirmClearSessions,
                  ),
                ]),
                const SizedBox(height: 14),
                Text(
                  'API Key 以明文保存在本机 SharedPreferences 中，'
                  '请勿在共享设备上保存敏感密钥。',
                  style: AppTextStyles.pageNumber.copyWith(
                    color:
                        isDark ? AppColors.darkSubtleText : AppColors.subtleText,
                    height: 1.6,
                  ),
                ),
              ],
            ),
    );
  }

  // ── 组件 ──

  Widget _sectionTitle(bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: AppTextStyles.label.copyWith(
          color: isDark ? AppColors.darkLabelText : AppColors.labelText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _card(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: Column(children: children),
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine,
      );

  /// 统一的开关行 —— 和「显示思考过程」那一行长得一样，只是省掉重复代码
  Widget _switchTile(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(
        icon,
        size: 20,
        color: isDark ? AppColors.darkPink : AppColors.pinkDark,
      ),
      title: Text(
        title,
        style: AppTextStyles.body.copyWith(
          color: isDark ? AppColors.darkTitleText : AppColors.titleText,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.label.copyWith(
          color: isDark ? AppColors.darkLabelText : AppColors.labelText,
        ),
      ),
      value: value,
      activeThumbColor: AppColors.darkGoldAccent,
      onChanged: onChanged,
    );
  }

  /// TTS 音色。各家命名完全不同（OpenAI `alloy` / 通义 `Cherry` / 硅基流动
  /// `FunAudioLLM/CosyVoice2-0.5B:alex`），所以只能让用户自己填，留空则用协议默认。
  Widget _ttsVoiceTile(bool isDark, AiConfig config) {
    final provider = config.activeProvider(AiCapability.tts);
    final protocol = provider?.protocol ?? AiProtocol.openAiCompat;
    // 兜底值必须按**当前这家厂商**算：硅基流动的默认音色是带模型名前缀的
    // `FunAudioLLM/CosyVoice2-0.5B:alex`，拿通用的 `alloy` 显示出来是错的。
    final fallback = defaultVoiceFor(
      protocol,
      baseUrl: provider?.baseUrl ?? '',
      model: provider?.effectiveModel ?? '',
    );
    final effective = config.ttsVoice.trim().isEmpty
        ? (fallback.isEmpty ? '未设置' : '$fallback（协议默认）')
        : config.ttsVoice;

    return ListTile(
      leading: Icon(
        Icons.graphic_eq_rounded,
        size: 20,
        color: isDark ? AppColors.darkPink : AppColors.pinkDark,
      ),
      title: Text(
        // 系统语音的「音色」其实是语言标签，标题跟着改，别让人去找音色名
        protocol == AiProtocol.system ? '语言（系统语音）' : '音色',
        style: AppTextStyles.body.copyWith(
          color: isDark ? AppColors.darkTitleText : AppColors.titleText,
        ),
      ),
      subtitle: Text(
        effective,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.label.copyWith(
          color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
      ),
      onTap: () => _editVoice(
        config,
        fallback,
        helperText: _voiceHelperText(provider, fallback),
      ),
    );
  }

  Widget _capabilityTile(bool isDark, AiConfig config, AiCapability capability) {
    final active = config.activeProvider(capability);
    final subColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final accent = isDark ? AppColors.darkPink : AppColors.pinkDark;

    String subtitle;
    if (active == null) {
      subtitle = capability == AiCapability.image ? '未配置（生图需自行添加厂商）' : '未配置';
    } else {
      final model = active.effectiveModel;
      subtitle = '${active.name}${model.isEmpty ? "" : " · $model"}'
          '${active.needsApiKey && !active.hasApiKey ? "（缺少密钥）" : ""}';
    }

    return Column(
      children: [
        ListTile(
          leading: Icon(_iconOf(capability), size: 20, color: accent),
          title: Text(
            capability.label,
            style: AppTextStyles.body.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(color: subColor),
          ),
          trailing: Icon(Icons.chevron_right, size: 20, color: subColor),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProviderManageScreen(capability: capability),
              ),
            );
            await _reload();
          },
        ),
        if (capability != AiCapability.values.last) _divider(isDark),
      ],
    );
  }

  IconData _iconOf(AiCapability capability) {
    switch (capability) {
      case AiCapability.chat:
        return Icons.chat_bubble_outline_rounded;
      case AiCapability.image:
        return Icons.image_outlined;
      case AiCapability.tts:
        return Icons.volume_up_outlined;
      case AiCapability.stt:
        return Icons.mic_none_rounded;
    }
  }

  Widget _systemPromptTile(bool isDark, AiConfig config) {
    return ListTile(
      leading: Icon(
        Icons.tune_rounded,
        size: 20,
        color: isDark ? AppColors.darkPink : AppColors.pinkDark,
      ),
      title: Text(
        '系统提示词',
        style: AppTextStyles.body.copyWith(
          color: isDark ? AppColors.darkTitleText : AppColors.titleText,
        ),
      ),
      subtitle: Text(
        config.systemPrompt.replaceAll('\n', ' '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.label.copyWith(
          color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
      ),
      onTap: () => _editSystemPrompt(config),
    );
  }

  Widget _sliderTile(
    bool isDark, {
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color:
                        isDark ? AppColors.darkTitleText : AppColors.titleText,
                  ),
                ),
              ),
              Text(
                display,
                style: AppTextStyles.label.copyWith(
                  color: isDark ? AppColors.darkPink : AppColors.pinkDark,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: AppTextStyles.pageNumber.copyWith(
              color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
            ),
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: isDark ? AppColors.darkPink : AppColors.pink,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ── 交互 ──

  /// 编辑系统提示词。
  ///
  /// controller 由 [_TextEditDialog] 自己持有并释放 —— **不要**在这里
  /// `showDialog` 之后自己 new/dispose 一个 controller（原因见该类的注释）。
  Future<void> _editSystemPrompt(AiConfig config) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TextEditDialog(
        title: '系统提示词',
        initialText: config.systemPrompt,
        hintText: '描述 AI 助手的角色与回答风格',
        minLines: 5,
        maxLines: 10,
        actions: const [
          _DialogAction('取消'),
          _DialogAction('恢复默认', value: AiConfig.defaultSystemPrompt),
          _DialogAction('保存', primary: true, submitText: true),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await _update((c) => c.copyWith(systemPrompt: result.trim()));
    }
  }

  /// 音色输入框下方的说明。
  ///
  /// 硅基流动那条必须单独写：它的 `voice` 是 `模型名:音色名`，
  /// 不说清楚用户会照 OpenAI 的习惯填 `alloy`，然后 400。
  String _voiceHelperText(AiProvider? provider, String fallback) {
    if (provider != null && provider.protocol == AiProtocol.system) {
      return '系统语音这里填的是**语言标签**，不是音色名 —— '
          '例如 $fallback（中文）/ en-US（英文），留空即用 $fallback。\n'
          '具体音色由手机自带的语音引擎决定，第三方 App 改不了。';
    }
    if (provider != null && isSiliconFlowBase(provider.baseUrl)) {
      return '留空即用 $fallback。'
          '硅基流动要求「模型名:音色名」的写法，只填短名也行（会自动补上前缀）。'
          '预置音色：${siliconFlowVoiceNames.join(' / ')}。';
    }
    if (fallback.isEmpty) {
      return '留空则使用该厂商的默认音色。各家音色命名不同，请查阅厂商文档。';
    }
    return '留空则使用协议默认音色 $fallback。'
        '换模型后音色可能需要跟着改（例如 CosyVoice 用 longxiaochun）。';
  }

  /// 编辑 TTS 音色。留空即「用协议默认」。
  ///
  /// 同样把 controller 交给 [_TextEditDialog] —— 这里原来是
  /// `await showDialog(...)` 之后直接 `controller.dispose()`，
  /// 而对话框退场动画还没播完，`TextField` 会去用已经释放的 controller，
  /// 抛 `A TextEditingController was used after being disposed`。
  Future<void> _editVoice(
    AiConfig config,
    String fallback, {
    String? helperText,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TextEditDialog(
        title: '朗读音色',
        initialText: config.ttsVoice,
        hintText: fallback.isEmpty ? '例如 Cherry' : fallback,
        helperText: helperText ??
            (fallback.isEmpty
                ? '留空则使用该厂商的默认音色。各家音色命名不同，请查阅厂商文档。'
                : '留空则使用协议默认音色 $fallback。'
                    '换模型后音色可能需要跟着改（例如 CosyVoice 用 longxiaochun）。'),
        autofocus: true,
        actions: const [
          _DialogAction('取消'),
          _DialogAction('用默认', value: ''),
          _DialogAction('保存', primary: true, submitText: true),
        ],
      ),
    );
    if (result == null) return;
    await _update((c) => c.copyWith(ttsVoice: result.trim()));
  }

  /// 导出当前会话：先选格式，再交给 [ChatExportService] 落文件 + 分享。
  Future<void> _exportCurrentSession() async {
    final session = context.read<ChatSessionProvider>();
    final messages = session.messages;
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('这段会话还没有内容可导出')));
      return;
    }

    final format = await showChatExportSheet(context);
    if (format == null || !mounted) return;
    try {
      await ChatExportService.exportAndShare(
        title: session.currentSession?.title ?? 'AI 对话',
        messages: messages,
        format: format,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  Future<void> _confirmClearSessions() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        title: const Text('清空全部会话'),
        content: const Text('所有会话与消息都会被删除，此操作不可恢复。确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.deleteRed,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<ChatSessionProvider>().clearAllSessions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清空全部会话')),
    );
  }
}

/// 编辑对话框里的一个按钮。
class _DialogAction {
  const _DialogAction(
    this.label, {
    this.value,
    this.primary = false,
    this.submitText = false,
  });

  /// 按钮文字
  final String label;

  /// 点击后 `Navigator.pop` 出去的返回值。null = 取消（调用方什么都不做）
  final String? value;

  /// 用 `FilledButton`（主按钮）还是 `TextButton`
  final bool primary;

  /// 返回「输入框里的当前内容」而不是 [value]（「保存」按钮用）
  final bool submitText;
}

/// 「单输入框 + 若干按钮」的编辑对话框。
///
/// ## 为什么必须是 StatefulWidget 自己持有 controller
///
/// `showDialog` 返回的 Future 在 `Navigator.pop` 那一刻就 complete 了，
/// **但对话框还要播完退场动画才会被真正卸载**。如果调用方写成
///
/// ```dart
/// final controller = TextEditingController(...);
/// final result = await showDialog<String>(...);
/// controller.dispose();   // ❌ 太早
/// ```
///
/// 那么退场动画期间的 `TextField` 还会去读已经释放的 controller，抛
/// `A TextEditingController was used after being disposed`，
/// 屏幕上会出现一片红。带 `autofocus: true` 的输入框尤其容易命中
/// （焦点/输入法还挂着）。
///
/// 正确做法是把 controller 的生命周期交给对话框自己的 [State] ——
/// 它在元素被卸载时才 `dispose()`，天然晚于退场动画。
class _TextEditDialog extends StatefulWidget {
  const _TextEditDialog({
    required this.title,
    required this.actions,
    this.initialText = '',
    this.hintText,
    this.helperText,
    this.minLines = 1,
    this.maxLines = 1,
    this.autofocus = false,
  });

  final String title;
  final String initialText;
  final String? hintText;

  /// 输入框下方的小字说明（没有就不显示）
  final String? helperText;
  final int minLines;
  final int maxLines;
  final bool autofocus;
  final List<_DialogAction> actions;

  @override
  State<_TextEditDialog> createState() => _TextEditDialogState();
}

class _TextEditDialogState extends State<_TextEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _valueOf(_DialogAction action) =>
      action.submitText ? _controller.text : action.value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtle = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return AlertDialog(
      backgroundColor:
          isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
      title: Text(
        widget.title,
        style: AppTextStyles.heading.copyWith(
          color: isDark ? AppColors.darkTitleText : AppColors.titleText,
          fontSize: 18,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              style: AppTextStyles.body.copyWith(
                color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
              ),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: widget.hintText,
              ),
            ),
            if (widget.helperText != null) ...[
              const SizedBox(height: 10),
              Text(
                widget.helperText!,
                style: AppTextStyles.pageNumber
                    .copyWith(color: subtle, height: 1.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        for (final action in widget.actions)
          if (action.primary)
            FilledButton(
              onPressed: () => Navigator.pop(context, _valueOf(action)),
              child: Text(action.label),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context, _valueOf(action)),
              child: Text(
                action.label,
                style: action.value == null ? TextStyle(color: subtle) : null,
              ),
            ),
      ],
    );
  }
}
