import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/ai_config.dart';
import '../models/ai_provider.dart';
import '../models/local_model.dart';
import '../services/ai_config_store.dart';
import '../services/local_model_installer.dart';
import '../services/local_model_store.dart';

/// 「本地模型」分区 —— 挂在厂商管理页顶部（只对语音识别 / 语音合成两个能力出现）。
///
/// ## 它为什么必须存在
///
/// 这台机器（HUAWEI ADA-AL00）**没有 GMS**，`speech_to_text` 依赖的 Google
/// 语音服务根本调不起来。所以离线模型不是「锦上添花」，而是这台设备上唯一
/// 确定可用的语音路径。
///
/// ## 与云端厂商的关系
///
/// **并存**，不是替换。装好的本地模型会以 `isBuiltin: false` 的身份写进
/// `AiConfig.providers`（id 形如 `local-asr-zipformer-14m`），从而能走
/// 「选中厂商 → 调用」这条现成的链路；但它在视觉上**只出现在这个分区里**，
/// 不会混进下面的云端厂商列表（宿主页会按协议过滤掉）。
///
/// ## 三个容易踩的点
///
/// 1. **状态有两个来源**：`LocalModelStore`（装没装）+ `LocalModelInstaller.progress`
///    （正在装 / 刚失败）。只订阅后者会让「重启 App 后」已装模型显示成未装；
///    只看前者则安装过程毫无反馈。
/// 2. **进度是静态单例**：228 MB 要下好几分钟，用户切出去再回来不能丢，
///    所以订阅的是 `LocalModelInstaller.progress` 而不是本地 State。
/// 3. **厂商记录要跟着安装状态走**：装了要写、卸了要删。否则会留下
///    「选了但用不了」的悬空厂商，或者删了模型却还在列表里。
class LocalModelSection extends StatefulWidget {
  final AiCapability capability;

  /// 宿主页当前的配置快照（用来判断哪个模型被选中）
  final AiConfig config;

  /// 分区改变了配置后，通知宿主页重新加载
  final Future<void> Function() onChanged;

  const LocalModelSection({
    super.key,
    required this.capability,
    required this.config,
    required this.onChanged,
  });

  @override
  State<LocalModelSection> createState() => _LocalModelSectionState();
}

class _LocalModelSectionState extends State<LocalModelSection> {
  Map<String, InstalledLocalModel> _installed = const {};

  List<LocalModelSpec> get _specs =>
      LocalModelCatalog.of(widget.capability);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final map = await LocalModelStore.load(force: true);
    if (!mounted) return;
    setState(() => _installed = map);
    await _syncProviders();
  }

  /// 让 `AiConfig.providers` 与磁盘上的安装状态对齐。
  ///
  /// - 装了但记录缺失 → 补一条本地厂商（这样才选得中）
  /// - 没装但记录还在 → 删掉（否则是个「选了也用不了」的幽灵项）
  Future<void> _syncProviders() async {
    final specs = _specs;
    if (specs.isEmpty) return;

    var changed = false;
    await AiConfigStore.update((c) {
      var next = c;
      for (final spec in specs) {
        final pid = spec.providerId;
        final exists = next.providerById(pid) != null;
        final shouldExist = _installed.containsKey(spec.id);
        if (shouldExist && !exists) {
          next = next.upsertProvider(_providerOf(spec));
          changed = true;
        } else if (!shouldExist && exists) {
          next = next.removeProvider(pid);
          changed = true;
        }
      }
      return next;
    });

    if (changed && mounted) await widget.onChanged();
  }

  /// 本地模型在 `AiConfig.providers` 里的形态。
  ///
  /// `models` 刻意留空 —— 引擎侧按厂商 id 反推模型 id
  /// （见 `LocalModelCatalog.modelIdOfProvider`），填了反而要维护两份真相。
  AiProvider _providerOf(LocalModelSpec spec) => AiProvider(
        id: spec.providerId,
        name: spec.displayName,
        capability: spec.capability,
        protocol: AiProtocol.local,
        // 用户手动装的，得能删
        isBuiltin: false,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final specs = _specs;
    if (specs.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<Map<String, LocalInstallProgress>>(
      valueListenable: LocalModelInstaller.progress,
      builder: (context, progress, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(isDark),
            const SizedBox(height: 6),
            ...specs.map(
              (s) => _tile(isDark, s, progress[s.id]),
            ),
            const SizedBox(height: 14),
            _divider(isDark),
            const SizedBox(height: 10),
            _cloudLabel(isDark),
          ],
        );
      },
    );
  }

  Widget _header(bool isDark) {
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 16,
              color: isDark ? AppColors.darkPink : AppColors.pinkDark,
            ),
            const SizedBox(width: 6),
            Text(
              '本地模型（离线，无需密钥）',
              style: AppTextStyles.body.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '装在手机里、断网也能用。需要手动下载，界面已标出体积。'
          '与下面的云端厂商可以同时存在，随时切换。',
          style: AppTextStyles.pageNumber.copyWith(
            color: subColor,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _divider(bool isDark) => Container(
        height: 1,
        color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine,
      );

  Widget _cloudLabel(bool isDark) => Text(
        '云端厂商（需要 API Key）',
        style: AppTextStyles.body.copyWith(
          color: isDark ? AppColors.darkTitleText : AppColors.titleText,
          fontWeight: FontWeight.w600,
        ),
      );

  // ─────────────────────────────────────────────

  Widget _tile(bool isDark, LocalModelSpec spec, LocalInstallProgress? p) {
    final accent = isDark ? AppColors.darkPink : AppColors.pinkDark;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final installed = _installed.containsKey(spec.id);
    final isActive = widget.config.activeIdOf(widget.capability) == spec.providerId;

    final running = p != null && p.isRunning;
    final failed = p?.stage == LocalInstallStage.failed;

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 装好了才是可选项；没装的位置留给状态图标，不误导用户去点
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    installed
                        ? (isActive
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off)
                        : Icons.download_for_offline_outlined,
                    size: 20,
                    color: installed
                        ? (isActive ? accent : subColor)
                        : subColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              spec.name,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _sizeBadge(isDark, spec.sizeLabel),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        spec.summary,
                        style: AppTextStyles.pageNumber.copyWith(color: subColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusLine(spec, installed: installed, p: p),
                        style: AppTextStyles.pageNumber.copyWith(
                          color: failed ? AppColors.deleteRed : subColor,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _trailingAction(
                  isDark: isDark,
                  accent: accent,
                  subColor: subColor,
                  spec: spec,
                  installed: installed,
                  running: running,
                  failed: failed,
                ),
              ],
            ),
            if (running) ...[
              const SizedBox(height: 10),
              _progressBar(isDark, accent, subColor, p),
            ],
            if (installed && spec.capability == AiCapability.tts) ...[
              const SizedBox(height: 8),
              _voiceRow(isDark, accent, subColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sizeBadge(bool isDark, String label) {
    final subColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: subColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTextStyles.pageNumber.copyWith(color: subColor),
      ),
    );
  }

  String _statusLine(
    LocalModelSpec spec, {
    required bool installed,
    required LocalInstallProgress? p,
  }) {
    if (p != null) {
      switch (p.stage) {
        case LocalInstallStage.listing:
        case LocalInstallStage.downloading:
        case LocalInstallStage.verifying:
          final file = p.currentFile.split('/').last;
          return '${p.percentLabel}'
              '${file.isEmpty ? "" : " · ${_shorten(file)}"}';
        case LocalInstallStage.failed:
          return '安装失败：${p.error ?? "未知错误"}';
        case LocalInstallStage.cancelled:
          return '已取消。可以重新点安装，已下好的部分不会重下。';
        case LocalInstallStage.done:
          return '已安装 · ${spec.sizeLabel}';
      }
    }
    return installed ? '已安装 · ${spec.sizeLabel}' : '未安装 · 需要下载 ${spec.sizeLabel}';
  }

  String _shorten(String s) =>
      s.length <= 28 ? s : '…${s.substring(s.length - 27)}';

  Widget _progressBar(
    bool isDark,
    Color accent,
    Color subColor,
    LocalInstallProgress p,
  ) {
    final indeterminate = p.stage == LocalInstallStage.listing ||
        p.stage == LocalInstallStage.verifying ||
        p.totalBytes <= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: indeterminate ? null : p.fraction,
            minHeight: 5,
            backgroundColor:
                isDark ? AppColors.darkDividerLine : AppColors.dividerLine,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        if (p.totalFiles > 0) ...[
          const SizedBox(height: 4),
          Text(
            '${p.doneFiles} / ${p.totalFiles} 个文件 · '
            '${LocalModelCatalog.formatSize(p.receivedBytes / 1048576)}'
            ' / ${LocalModelCatalog.formatSize(p.totalBytes / 1048576)}',
            style: AppTextStyles.pageNumber.copyWith(color: subColor),
          ),
        ],
      ],
    );
  }

  /// 已装的 Kokoro 才给音色入口 —— 没装的时候选音色没有意义
  Widget _voiceRow(bool isDark, Color accent, Color subColor) {
    final voice = widget.config.ttsVoice;
    final sid = KokoroVoices.resolve(voice);
    final label = voice.trim().isEmpty
        ? '默认 · ${KokoroVoices.shortLabel(sid)}'
        : KokoroVoices.describe(sid);

    return InkWell(
      onTap: () => _pickVoice(widget.config),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.record_voice_over_outlined, size: 16, color: accent),
            const SizedBox(width: 6),
            Text(
              '音色',
              style: AppTextStyles.pageNumber.copyWith(color: subColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.pageNumber.copyWith(color: accent),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: subColor),
          ],
        ),
      ),
    );
  }

  Widget _trailingAction({
    required bool isDark,
    required Color accent,
    required Color subColor,
    required LocalModelSpec spec,
    required bool installed,
    required bool running,
    required bool failed,
  }) {
    if (running) {
      return TextButton(
        onPressed: () => LocalModelInstaller.cancel(spec.id),
        child: Text(
          '取消',
          style: AppTextStyles.label.copyWith(color: AppColors.deleteRed),
        ),
      );
    }
    if (installed) {
      return IconButton(
        tooltip: '删除',
        icon: Icon(Icons.delete_outline, size: 20, color: subColor),
        onPressed: () => _confirmUninstall(spec),
      );
    }
    return TextButton(
      onPressed: () => _confirmInstall(spec),
      child: Text(
        failed ? '重试' : '安装',
        style: AppTextStyles.label.copyWith(color: accent),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 交互
  // ─────────────────────────────────────────────

  Future<void> _confirmInstall(LocalModelSpec spec) async {
    // 先把上一次的「失败」横幅清掉，否则点完重试界面还挂着旧错误
    LocalModelInstaller.clearProgress(spec.id);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('安装「${spec.name}」'),
        content: Text(
          '需要下载 ${spec.sizeLabel}，建议在 Wi-Fi 下进行。\n\n'
          '${spec.summary}\n\n'
          '下载源：hf-mirror.com（模型来源见方案文档）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('开始下载 ${spec.sizeLabel}'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final success = await LocalModelInstaller.install(spec);
    if (!mounted) return;

    if (success) {
      // 装好了 → 写厂商记录并自动选中，用户点完就能直接用
      await _refresh();
      await AiConfigStore.update(
        (c) => c.selectProvider(widget.capability, spec.providerId),
      );
      if (mounted) await widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${spec.name}」安装完成，已自动选用')),
        );
      }
    }
    // 失败时原因已经写在进度里，界面会显示，不再弹一次
  }

  Future<void> _confirmUninstall(LocalModelSpec spec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除本地模型'),
        content: Text(
          '确定删除「${spec.name}」吗？将释放约 ${spec.sizeLabel} 空间。\n'
          '删除后需要重新下载才能再用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.deleteRed),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await LocalModelStore.uninstall(spec.id);
    LocalModelInstaller.clearProgress(spec.id);
    if (!mounted) return;
    // 先刷新安装状态，_syncProviders 才会知道该把厂商记录删掉
    await _refresh();
  }

  /// Kokoro 的 54 个音色。默认把 8 个中文音色排在前面 ——
  /// 这是个中文日记 App，先看到中文音色比先看到 20 个美音合理得多。
  Future<void> _pickVoice(AiConfig config) async {
    final current = KokoroVoices.resolve(config.ttsVoice);

    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final subColor =
            isDark ? AppColors.darkSubtleText : AppColors.subtleText;
        final accent = isDark ? AppColors.darkPink : AppColors.pinkDark;

        final chinese = KokoroVoices.chineseIds;
        final others = [
          for (var i = 0; i < KokoroVoices.count; i++)
            if (!chinese.contains(i)) i,
        ];

        return AlertDialog(
          title: const Text('朗读音色'),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '中文音色',
                    style: AppTextStyles.label.copyWith(color: subColor),
                  ),
                ),
                ...chinese.map((i) => _voiceItem(dialogContext, isDark, accent, i, current)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '其他语言',
                    style: AppTextStyles.label.copyWith(color: subColor),
                  ),
                ),
                ...others.map((i) => _voiceItem(dialogContext, isDark, accent, i, current)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, KokoroVoices.defaultVoiceId),
              child: const Text('用默认'),
            ),
          ],
        );
      },
    );

    if (picked == null) return;
    // 存成数字 sid：跨版本最稳（音色名表万一调整，序号也不会变）
    await AiConfigStore.update((c) => c.copyWith(ttsVoice: '$picked'));
    if (mounted) await widget.onChanged();
  }

  Widget _voiceItem(
    BuildContext dialogContext,
    bool isDark,
    Color accent,
    int id,
    int current,
  ) {
    final selected = id == current;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        size: 18,
        color: selected ? accent : subColor,
      ),
      title: Text(
        KokoroVoices.shortLabel(id),
        style: AppTextStyles.body.copyWith(
          color: selected ? accent : titleColor,
        ),
      ),
      subtitle: Text(
        'sid $id · ${KokoroVoices.names[id]}',
        style: AppTextStyles.pageNumber.copyWith(color: subColor),
      ),
      // 必须用对话框自己的 context：用外层的也能 pop 掉（同一个 Navigator），
      // 但那是在赌「对话框一定是最上面那个路由」，换个调用方式就会静默弹错页。
      onTap: () => Navigator.pop(dialogContext, id),
    );
  }
}
