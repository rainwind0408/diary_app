import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/ai_provider.dart';
import '../models/chat_attachment.dart';
import '../models/voice_hold_view.dart';
import '../services/ai_config_store.dart';
import '../services/local_model_store.dart';
import '../services/stt_client.dart';
import '../services/voice_recorder.dart';
import 'attachment_panel.dart';
import 'pending_attachment_bar.dart';
import 'voice_hold_overlay.dart';

/// 聊天输入条。
///
/// 自带「待发送附件」状态：点左侧 `+` 走 [AttachmentPicker] 选择并落盘，
/// 选中的附件显示在上方 [PendingAttachmentBar] 里，可逐个删除；
/// 发送时连同文本一起交给 [onSend]，然后清空。
///
/// 右侧麦克风是**长按说话**（微信那种）：按住即开始听，松手转文字并
/// **回填输入框**（不自动发送，用户确认后再发）；手指上滑后松手则作废。
///
/// ## 输入框上方的工具条
///
/// 一个胶囊按钮：**AI 画图**（走 [onGenerateImage]，弹描述框直接生图，
/// 不经过对话模型）。它只是个入口，不做开关语义，所以始终是实心的。
///
/// 原先这里还有一个「联网搜索」开关（切换 `AiConfig.webSearchEnabled`），
/// 2026-10-08 按需求移除 —— 连同 `web_search.dart` 协议层与 `llm_service`
/// 的 `enable_search` 注入一并删掉了，不是只藏了入口。
///
/// 注意：`+` 与麦克风在模型回复期间**依然可用** —— 用户可以先把图选好、
/// 把话说完，等这一轮回复结束再发，不该因为 isLoading 就把入口锁死。
/// 会随 isLoading 变样的只有发送键（变成「停止」，走 [onStop]）和画图键
/// （变淡禁用 —— 它一按就发请求，没有「先准备好」的中间态）。
class ChatInput extends StatefulWidget {
  /// 发送回调。附件已由本组件落盘，这里拿到的是可直接入库的 [ChatAttachment]。
  final void Function(String text, List<ChatAttachment> attachments) onSend;
  final bool isLoading;

  /// 模型正在回复时，发送键会变成「停止」，点击走这个回调。
  final VoidCallback? onStop;

  /// 点「AI 画图」按钮。弹输入框、校验配置都由调用方负责 ——
  /// 这里只负责把「用户想画图」这件事报上去。
  final VoidCallback? onGenerateImage;

  const ChatInput({
    super.key,
    required this.onSend,
    this.isLoading = false,
    this.onStop,
    this.onGenerateImage,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  /// 一次长按说话的时长上限（秒），到点自动收尾。
  static const int _maxHoldSeconds = 60;

  /// 手指上滑超过这个距离（逻辑像素）就进入「松手取消」。
  static const double _cancelSlop = -80;

  /// 按得太短当作误触，不白跑一次识别请求。
  static const int _minHoldMs = 600;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final List<ChatAttachment> _pending = [];
  bool _hasText = false;
  bool _picking = false;

  // ── 长按说话 ──
  final VoiceRecorder _recorder = VoiceRecorder();
  final ValueNotifier<VoiceHoldView> _holdView =
      ValueNotifier(const VoiceHoldView(phase: VoiceHoldPhase.listening));
  OverlayEntry? _overlay;
  Timer? _holdTimer;
  DateTime? _holdStartedAt;
  int _holdSeconds = 0;
  bool _cancelArmed = false;
  bool _holding = false;
  bool _startedRecording = false;

  bool get _canSend => _hasText || _pending.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChange);
  }

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // 焦点获取后延迟触发键盘，适配华为 HarmonyOS
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _focusNode.hasFocus) {
          SystemChannels.textInput.invokeMethod('TextInput.show');
        }
      });
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _dismissOverlay();
    _holdView.dispose();
    _recorder.dispose();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 附件
  // ─────────────────────────────────────────────

  Future<void> _pickAttachments() async {
    if (_picking) return;
    _picking = true;
    try {
      final picked = await AttachmentPicker.show(context);
      if (!mounted || picked.isEmpty) return;
      setState(() => _pending.addAll(picked));
    } finally {
      _picking = false;
    }
  }

  void _removeAttachment(ChatAttachment attachment) {
    setState(() => _pending.remove(attachment));
  }

  // ─────────────────────────────────────────────
  // 长按说话
  // ─────────────────────────────────────────────

  void _handleHoldStart(LongPressStartDetails _) {
    if (_holding) return;
    _holding = true;
    _holdSeconds = 0;
    _cancelArmed = false;
    _startedRecording = false;
    _holdStartedAt = DateTime.now();
    _holdView.value = const VoiceHoldView(phase: VoiceHoldPhase.listening);
    _insertOverlay();
    setState(() {});

    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_holding) return;
      _holdSeconds++;
      if (_holdSeconds >= _maxHoldSeconds) {
        unawaited(_finishHold());
        return;
      }
      _publishHold();
    });

    unawaited(_beginRecording());
  }

  Future<void> _beginRecording() async {
    try {
      final ok = await _recorder.start();
      if (!ok) {
        _abortHold('没有麦克风权限，请在系统设置里允许「折花日记」使用麦克风');
        return;
      }
      // ★ 首次使用时 `start()` 里会弹系统授权框，期间长按手势会被系统打断
      //   （`_handleHoldCancel` 已经跑过，`_holding` 已归位）。这时必须显式
      //   关掉采集 —— 否则麦克风会一直开着，而界面看不出任何异常。
      if (!_holding) {
        await _recorder.cancel();
        return;
      }
      _startedRecording = true;
    } catch (e) {
      _abortHold('语音输入启动失败：$e');
    }
  }

  void _handleHoldMove(LongPressMoveUpdateDetails details) {
    if (!_holding) return;
    final armed = details.offsetFromOrigin.dy < _cancelSlop;
    if (armed == _cancelArmed) return;
    _cancelArmed = armed;
    _publishHold();
  }

  /// 手势被系统打断（来电、切后台等）——直接作废，别留个浮层挂着。
  void _handleHoldCancel() {
    if (!_holding) return;
    _holding = false;
    _holdTimer?.cancel();
    _holdTimer = null;
    _startedRecording = false;
    _holdStartedAt = null;
    unawaited(_recorder.cancel());
    _dismissOverlay();
    if (mounted) setState(() {});
  }

  Future<void> _finishHold() async {
    if (!_holding) return;
    _holding = false;
    _holdTimer?.cancel();
    _holdTimer = null;
    if (mounted) setState(() {});

    if (_cancelArmed) {
      _holdStartedAt = null;
      _startedRecording = false;
      await _recorder.cancel();
      _dismissOverlay();
      return;
    }

    final held = _holdStartedAt == null
        ? 0
        : DateTime.now().difference(_holdStartedAt!).inMilliseconds;
    _holdStartedAt = null;

    // 语音都没起来（多半是权限没给），_abortHold 已经提示过了
    if (!_startedRecording) {
      _dismissOverlay();
      return;
    }
    _startedRecording = false;

    if (held < _minHoldMs) {
      await _recorder.cancel();
      _dismissOverlay();
      _toast('说话时间太短，按住多说一会儿');
      return;
    }

    _holdView.value = VoiceHoldView(
      phase: VoiceHoldPhase.recognizing,
      seconds: _holdSeconds,
      maxSeconds: _maxHoldSeconds,
    );

    try {
      final path = await _recorder.stop();
      if (path == null) throw Exception('没有拿到音频文件');

      final config = await AiConfigStore.load();
      final provider = config.activeProvider(AiCapability.stt);
      if (provider == null) {
        throw Exception('还没有配置语音识别厂商，请到「AI 助手设置 → 语音识别」里添加');
      }

      final text = await SttClient.transcribe(
        provider: provider,
        model: config.activeModel(AiCapability.stt) ?? '',
        audioPath: path,
        // 选中的是本地模型时给出它的目录；否则为 null（云端链路不用）
        localModelDir: await LocalModelStore.dirForProvider(provider),
      );

      if (!mounted) return;
      _dismissOverlay();

      if (text.trim().isEmpty) {
        _toast('没有听清，再试一次？');
        return;
      }

      _controller.text = text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _focusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      _dismissOverlay();
      _toast(_friendly(e));
    }
  }

  /// 失败即收场：撤掉浮层，用 SnackBar 说明原因（不会卡住界面）。
  void _abortHold(String message) {
    _holding = false;
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdStartedAt = null;
    _startedRecording = false;
    unawaited(_recorder.cancel());
    _dismissOverlay();
    if (mounted) setState(() {});
    _toast(message);
  }

  void _publishHold() {
    _holdView.value = VoiceHoldView(
      phase: _cancelArmed ? VoiceHoldPhase.canceling : VoiceHoldPhase.listening,
      seconds: _holdSeconds,
      maxSeconds: _maxHoldSeconds,
    );
  }

  void _insertOverlay() {
    _dismissOverlay();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<VoiceHoldView>(
        valueListenable: _holdView,
        builder: (_, view, __) => VoiceHoldOverlay(view: view),
      ),
    );
    _overlay = entry;
    overlay.insert(entry);
  }

  void _dismissOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendly(Object e) {
    final raw = e.toString();
    const prefix = 'Exception: ';
    return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
  }

  // ─────────────────────────────────────────────
  // 发送
  // ─────────────────────────────────────────────

  void _handleSend() {
    final text = _controller.text.trim();
    if ((text.isEmpty && _pending.isEmpty) || widget.isLoading) return;

    final attachments = List<ChatAttachment>.from(_pending);
    _controller.clear();
    setState(() {
      _hasText = false;
      _pending.clear();
    });
    widget.onSend(text, attachments);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 输入条本身和聊天画布同色，靠「白面输入框」拉开层次 ——
    // 这样底部不会出现一条和画布不一样颜色的横带。
    final bgColor = AppColors.chatBubbleOf(context);
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final hintColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final accentColor = isDark ? AppColors.darkPink : AppColors.pink;

    return Container(
      color: AppColors.chatCanvasOf(context),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PendingAttachmentBar(
              attachments: _pending,
              onRemove: _removeAttachment,
            ),
            _toolBar(accentColor, hintColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _circleButton(
                    icon: Icons.add_rounded,
                    iconSize: 24,
                    iconColor: hintColor,
                    onTap: _pickAttachments,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppColors.chatBubbleShadowOf(context),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        style: AppTextStyles.body.copyWith(color: textColor),
                        decoration: InputDecoration(
                          hintText: '和AI聊聊...',
                          hintStyle:
                              AppTextStyles.body.copyWith(color: hintColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _holdToTalkButton(isDark: isDark, iconColor: hintColor),
                  const SizedBox(width: 6),
                  Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    child: _circleButton(
                      // 回复中变「停止」：用户随时能打断，半截回答会保留
                      icon: widget.isLoading
                          ? Icons.stop_rounded
                          : Icons.arrow_upward_rounded,
                      iconSize: 22,
                      iconColor: Colors.white,
                      onTap: widget.isLoading
                          ? widget.onStop
                          : (_canSend ? _handleSend : null),
                      background: widget.isLoading
                          ? accentColor
                          : _canSend
                              ? accentColor
                              : hintColor.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 输入框上方的工具条：目前只有 AI 画图。
  ///
  /// 单独一行而不是塞进输入框那一行 —— 那一行已经有 `+` / 麦克风 / 发送
  /// 三个按钮，再挤会把输入框压到只剩一百来个像素。
  ///
  /// 左对齐（和参考设计一致），右侧留白由 [Spacer] 吃掉。
  Widget _toolBar(Color accentColor, Color hintColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          _toolChip(
            icon: Icons.palette_outlined,
            label: 'AI 画图',
            // 它是个入口不是开关，所以永远「亮着」
            active: true,
            // 忙的时候变淡禁用 —— 它一按就发网络请求，
            // 不像 `+` / 麦克风那样只是「先把内容准备好」
            enabled: !widget.isLoading,
            accent: accentColor,
            idle: hintColor,
            onTap: widget.onGenerateImage,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  /// 一个胶囊工具按钮。
  ///
  /// 关闭态刻意做成**半透明**（灰底 + 半透明灰字），开启态才是实心高亮 ——
  /// 开关型按钮必须让人一眼看出当前状态，不能靠记忆。
  Widget _toolChip({
    required IconData icon,
    required String label,
    required bool active,
    required bool enabled,
    required Color accent,
    required Color idle,
    required VoidCallback? onTap,
  }) {
    final background =
        active ? accent.withValues(alpha: 0.16) : idle.withValues(alpha: 0.10);
    final foreground = active ? accent : idle.withValues(alpha: 0.55);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: foreground,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 长按说话按钮。
  ///
  /// 短按只给一句提示（不然用户根本不知道这里要「按住」），
  /// 长按才真正开始听。
  Widget _holdToTalkButton({
    required bool isDark,
    required Color iconColor,
  }) {
    final accent = isDark ? AppColors.darkPink : AppColors.pink;
    final idleBg = AppColors.chatBubbleOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toast('按住说话，松手转成文字'),
      onLongPressStart: _handleHoldStart,
      onLongPressMoveUpdate: _handleHoldMove,
      onLongPressEnd: (_) => unawaited(_finishHold()),
      onLongPressCancel: _handleHoldCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _holding ? accent.withValues(alpha: 0.22) : idleBg,
          shape: BoxShape.circle,
          border: _holding ? Border.all(color: accent, width: 1.2) : null,
        ),
        child: Icon(
          _holding ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: _holding ? accent : iconColor,
          size: 22,
        ),
      ),
    );
  }

  /// 统一的圆形按钮：无背景时用气泡白，有 [background] 时用其填充。
  Widget _circleButton({
    required IconData icon,
    required double iconSize,
    required Color iconColor,
    required VoidCallback? onTap,
    Color? background,
  }) {
    return Material(
      color: background ?? AppColors.chatBubbleOf(context),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );
  }
}
