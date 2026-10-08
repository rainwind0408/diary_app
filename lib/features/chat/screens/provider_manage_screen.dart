import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/ai_config.dart';
import '../models/ai_provider.dart';
import '../models/local_model.dart';
import '../services/ai_config_store.dart';
import '../services/llm_service.dart';
import '../services/system_tts.dart';
import '../widgets/local_model_section.dart';

/// 某个能力（对话 / 生图 / 语音识别 / 语音合成）下的厂商管理。
///
/// 支持：选择当前厂商、编辑（API Key / 地址 / 模型）、新增自定义厂商、删除自定义厂商。
class ProviderManageScreen extends StatefulWidget {
  final AiCapability capability;

  const ProviderManageScreen({super.key, required this.capability});

  @override
  State<ProviderManageScreen> createState() => _ProviderManageScreenState();
}

class _ProviderManageScreenState extends State<ProviderManageScreen> {
  AiConfig? _config;
  bool _busy = false;

  /// 系统语音试听中（按钮要显示「朗读中…」并禁用，避免叠着播）
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    // 试听中途退出页面，得把引擎停掉，否则会继续念
    SystemTts.stop();
    super.dispose();
  }

  Future<void> _reload() async {
    final config = await AiConfigStore.load(force: true);
    if (!mounted) return;
    setState(() => _config = config);
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
          '${widget.capability.label}厂商',
          style: AppTextStyles.heading.copyWith(
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            fontSize: 20,
          ),
        ),
      ),
      body: config == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _hint(isDark),
                const SizedBox(height: 8),
                // 「系统语音」只跟语音合成有关，单独一个分区 ——
                // 它没有地址 / 密钥 / 模型，混进下面的云端列表会显示成
                // 「未设置地址 · 未配置密钥」，看着像没配好。
                if (widget.capability == AiCapability.tts) ...[
                  _systemVoiceTile(isDark, config),
                  const SizedBox(height: 12),
                ],
                // 本地模型分区只对语音两个能力出现（生图/对话没有离线模型）。
                // 它自带「云端厂商」小标题，所以必须紧贴下面的列表。
                if (LocalModelCatalog.of(widget.capability).isNotEmpty) ...[
                  LocalModelSection(
                    capability: widget.capability,
                    config: config,
                    onChanged: _reload,
                  ),
                  const SizedBox(height: 8),
                ],
                // 本地模型与系统语音已经在上面的分区里露过面了，别在这里重复 ——
                // 而且它们在下面这个列表里是「不能编辑、不能删」的哑项。
                ...config
                    .providersOf(widget.capability)
                    .where((p) =>
                        p.protocol != AiProtocol.local &&
                        p.protocol != AiProtocol.system)
                    .map((p) => _providerTile(isDark, config, p)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: config == null || _busy ? null : () => _addCustom(config),
        backgroundColor: isDark ? AppColors.darkPink : AppColors.pink,
        foregroundColor: isDark ? AppColors.darkPageBackground : Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('自定义厂商'),
      ),
    );
  }

  Widget _hint(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '选中的厂商将用于${widget.capability.label}。'
        '${widget.capability == AiCapability.image ? "生图默认不提供预设，请自行添加。" : ""}'
        '密钥以明文保存在本机。',
        style: AppTextStyles.pageNumber.copyWith(
          color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
          height: 1.6,
        ),
      ),
    );
  }

  /// 「系统语音」卡片（只对语音合成出现）。
  ///
  /// 它是内置厂商（`AiProviderPresets.systemTtsId` / [AiProtocol.system]），
  /// 走 Android 标准 `TextToSpeech` 调**手机自带**的语音引擎：
  /// 零体积、零权限、开箱即用。代价是**拿不到音频字节**（边合成边播），
  /// 所以依赖音频字节的功能（导出音频）对它不可用。
  ///
  /// 带一个**试听**按钮 —— 「这台手机到底能不能出声、好不好听」当场听一下
  /// 最直接，比任何文字说明都强。
  Widget _systemVoiceTile(bool isDark, AiConfig config) {
    final provider = config.providerById(AiProviderPresets.systemTtsId);
    if (provider == null) return const SizedBox.shrink();

    final accent = isDark ? AppColors.darkPink : AppColors.pinkDark;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final isActive = config.activeIdOf(AiCapability.tts) == provider.id;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive
              ? accent
              : (isDark ? AppColors.darkDividerLine : AppColors.dividerLine),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(
          isActive ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isActive ? accent : subColor,
          size: 20,
        ),
        title: Row(
          children: [
            Text(
              '系统语音',
              style: AppTextStyles.body.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: subColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '免下载 · 零权限',
                style: AppTextStyles.pageNumber.copyWith(color: subColor),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '用手机自带的语音引擎朗读，断网也能用。\n'
            '不支持导出音频（引擎边合成边播，拿不到音频文件）。',
            style: AppTextStyles.pageNumber.copyWith(color: subColor),
          ),
        ),
        isThreeLine: true,
        trailing: TextButton(
          onPressed: _previewing ? null : _previewSystemVoice,
          child: Text(
            _previewing ? '朗读中…' : '试听',
            style: AppTextStyles.label.copyWith(color: accent),
          ),
        ),
        onTap: _busy
            ? null
            : () async {
                await AiConfigStore.update(
                  (c) => c.selectProvider(AiCapability.tts, provider.id),
                );
                await _reload();
              },
      ),
    );
  }

  /// 试听系统语音。**不抛异常** —— 调用方是按钮回调，抛出去只会变成红屏。
  Future<void> _previewSystemVoice() async {
    if (_previewing) return;
    setState(() => _previewing = true);

    void finish() {
      if (mounted) setState(() => _previewing = false);
    }

    try {
      final config = await AiConfigStore.load();
      if (!await SystemTts.isAvailable()) {
        _toast('这台手机没有可用的系统语音引擎，或者没装中文语音包');
        finish();
        return;
      }
      await SystemTts.speak(
        text: '今天天气不错，我们去公园散步吧。',
        speed: config.ttsSpeed,
        // 对系统语音来说「音色」其实是语言标签（见 tts_codec.systemDefaultLocale）
        voice: config.ttsVoice,
        onDone: finish,
      );
    } catch (e) {
      final raw = e.toString();
      _toast('试听失败：${raw.startsWith('Exception: ') ? raw.substring(11) : raw}');
      finish();
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _providerTile(bool isDark, AiConfig config, AiProvider provider) {
    final accent = isDark ? AppColors.darkPink : AppColors.pinkDark;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final activeId = config.activeIdOf(widget.capability);
    final isActive = activeId == provider.id;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive
              ? accent
              : (isDark ? AppColors.darkDividerLine : AppColors.dividerLine),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(
          isActive ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isActive ? accent : subColor,
          size: 20,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                provider.name,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (provider.isBuiltin) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: subColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '内置',
                  style: AppTextStyles.pageNumber.copyWith(color: subColor),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '${provider.baseUrl.isEmpty ? "未设置地址" : provider.baseUrl}\n'
            '模型 ${provider.models.length} 个 · '
            '${provider.hasApiKey ? "已配置密钥" : "未配置密钥"}',
            style: AppTextStyles.pageNumber.copyWith(color: subColor),
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: subColor),
          color:
              isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
          onSelected: (value) async {
            if (value == 'edit') {
              await _edit(provider);
            } else if (value == 'delete') {
              await _delete(config, provider);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            if (!provider.isBuiltin)
              const PopupMenuItem(
                value: 'delete',
                child:
                    Text('删除', style: TextStyle(color: AppColors.deleteRed)),
              ),
          ],
        ),
        onTap: _busy
            ? null
            : () async {
                await AiConfigStore.update(
                  (c) => c.selectProvider(widget.capability, provider.id),
                );
                await _reload();
              },
      ),
    );
  }

  Future<void> _edit(AiProvider provider) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderEditScreen(
          provider: provider,
          capability: widget.capability,
        ),
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _addCustom(AiConfig config) async {
    final draft = AiProvider(
      id: AiConfigStore.newProviderId(config, 'custom'),
      name: '自定义厂商',
      capability: widget.capability,
      protocol: AiProtocol.openAiCompat,
      baseUrl: '',
    );
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderEditScreen(
          provider: draft,
          capability: widget.capability,
          isNew: true,
        ),
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _delete(AiConfig config, AiProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除厂商'),
        content: Text('确定删除「${provider.name}」吗？'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AiConfigStore.update((c) => c.removeProvider(provider.id));
    await _reload();
  }
}

/// 单个厂商的编辑页（新增与编辑共用）。
class ProviderEditScreen extends StatefulWidget {
  final AiProvider provider;
  final AiCapability capability;
  final bool isNew;

  const ProviderEditScreen({
    super.key,
    required this.provider,
    required this.capability,
    this.isNew = false,
  });

  @override
  State<ProviderEditScreen> createState() => _ProviderEditScreenState();
}

class _ProviderEditScreenState extends State<ProviderEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  late final TextEditingController _modelController;

  late AiProvider _provider;
  bool _updating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _nameController = TextEditingController(text: _provider.name);
    _urlController = TextEditingController(text: _provider.baseUrl);
    _keyController = TextEditingController(text: _provider.apiKey);
    _modelController = TextEditingController(text: _provider.effectiveModel);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkPink : AppColors.pinkDark;

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
          widget.isNew ? '新增厂商' : '编辑厂商',
          style: AppTextStyles.heading.copyWith(
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              '保存',
              style: AppTextStyles.body.copyWith(color: accent),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _field(
            isDark,
            label: '名称',
            controller: _nameController,
            hint: '例如 我的中转站',
            enabled: !_provider.isBuiltin,
          ),
          _field(
            isDark,
            label: 'API 地址（Base URL）',
            controller: _urlController,
            hint: 'https://api.example.com/v1',
          ),
          _field(
            isDark,
            label: 'API Key（明文保存）',
            controller: _keyController,
            hint: 'sk-...',
            obscure: true,
          ),
          _field(
            isDark,
            label: '当前模型',
            controller: _modelController,
            hint: _provider.models.isEmpty
                ? '先填写或更新模型列表'
                : _provider.models.first,
          ),
          const SizedBox(height: 4),
          _modelChips(isDark, accent),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _updating ? null : _updateModels,
            icon: _updating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_updating ? '正在获取...' : '联网更新模型列表'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: AppTextStyles.label.copyWith(color: AppColors.deleteRed),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '提示：只有 OpenAI 兼容协议的 /models 接口能自动拉取列表，'
            '其他厂商请手动填写模型名。',
            style: AppTextStyles.pageNumber.copyWith(
              color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    bool isDark, {
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: isDark ? AppColors.darkLabelText : AppColors.labelText,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: enabled,
            obscureText: obscure,
            style: AppTextStyles.body.copyWith(
              color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
            ),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: true,
              fillColor:
                  isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelChips(bool isDark, Color accent) {
    if (_provider.models.isEmpty) {
      return Text(
        '暂无模型列表',
        style: AppTextStyles.pageNumber.copyWith(
          color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _provider.models.map((m) {
        final selected = m == _provider.effectiveModel;
        return GestureDetector(
          onTap: () {
            setState(() => _provider = _provider.copyWith(selectedModel: m));
            _modelController.text = m;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.18)
                  : (isDark
                      ? AppColors.darkCardBackground
                      : AppColors.cardBackground),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? accent
                    : (isDark
                        ? AppColors.darkDividerLine
                        : AppColors.dividerLine),
              ),
            ),
            child: Text(
              m,
              style: AppTextStyles.pageNumber.copyWith(
                color: selected
                    ? accent
                    : (isDark ? AppColors.darkBodyText : AppColors.bodyText),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _updateModels() async {
    setState(() {
      _updating = true;
      _error = null;
    });
    try {
      // 先用当前输入框内容落盘，再拉列表（否则拉的是旧地址/旧 key）
      await _persist();
      // 针对「正在编辑的这个厂商」更新，而不是当前选中项
      final count = await LlmService.updateModelsOf(_provider);
      final config = await AiConfigStore.load(force: true);
      final refreshed = config.providerById(_provider.id);
      if (!mounted) return;
      setState(() {
        if (refreshed != null) _provider = refreshed;
        _error = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('模型列表已更新，新增 $count 个')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      setState(() {
        _error = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
      });
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  /// 把输入框内容写回配置。`silent` 仅用于「更新模型列表」前先落盘，
  /// 避免拉到旧地址/旧 key。
  Future<void> _persist() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();
    final model = _modelController.text.trim();

    var next = _provider.copyWith(
      name: name.isEmpty ? _provider.name : name,
      baseUrl: url,
      apiKey: key,
      selectedModel: model.isEmpty ? null : model,
    );
    if (model.isNotEmpty && !next.models.contains(model)) {
      next = next.copyWith(models: [...next.models, model]);
    }
    _provider = next;

    await AiConfigStore.update((c) => c.upsertProvider(next));
  }

  Future<void> _save() async {
    await _persist();
    // 新增的厂商自动选中
    if (widget.isNew) {
      await AiConfigStore.update(
        (c) => c.selectProvider(widget.capability, _provider.id),
      );
    }
    if (mounted) Navigator.pop(context, true);
  }
}
