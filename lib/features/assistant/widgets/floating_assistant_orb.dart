import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/providers/app_chrome_provider.dart';
import '../../chat/models/ai_provider.dart';
import '../../chat/models/reply_style.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/providers/chat_session_provider.dart';
import '../../chat/screens/ai_assistant_settings_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/services/ai_config_store.dart';
import '../../chat/services/local_model_store.dart';
import '../../chat/services/stt_client.dart';
import '../../chat/services/tts_player.dart';
import '../../chat/services/voice_recorder.dart';
import '../services/assistant_route_observer.dart';
import '../services/orb_geometry.dart';
import '../services/orb_position_store.dart';
import '../services/orb_reply.dart';
import '../services/orb_tap_arbiter.dart';
import '../services/orb_visibility.dart';
import '../services/voice_direct.dart';
import 'orb_reply_bubble.dart';

/// 可自由拖动的 AI 助手悬浮球。
///
/// 挂在 `MaterialApp.builder` 的 Stack 里（见 `app.dart`）——
/// 只有挂在这一层它才不会被 `Navigator.push` 出来的页面盖住。
/// 代价是它也会盖住弹层，所以必须靠 [AssistantRouteObserver] 做路由感知。
///
/// ## 手势
///
/// | 手势 | 行为 |
/// |---|---|
/// | 单击 | 打开 AI 助手聊天页 |
/// | 双击 | 打开 AI 助手设置页 |
/// | 长按 | 语音直通：按住说话，松手直接发给 AI（上滑取消） |
/// | 拖动 | 移动，松手吸附到最近的左/右边 |
///
/// 四种手势共存的关键是**不用 Flutter 内置的 `onDoubleTap`** ——
/// 它会 hold 住手势竞技场，把单击拖到 300ms 之后。判定逻辑在纯 Dart 的
/// [OrbTapArbiter] 里（见该文件的注释）。
///
/// ## 语音直通（P5-2）
///
/// 与聊天输入框的长按说话有两点不同：**不转文字确认**（识别完直接发），
/// 以及**原音频用完即删**（见 [deleteTempAudio]）。判定与常量都在纯 Dart 的
/// [VoiceDirectPolicy] 里。
///
/// ## 回复气泡（P5-7）
///
/// 松手转完文字之后，回复**不再跳转聊天页**，而是显示在球旁边一枚带
/// 圆弧小尾巴的气泡里（见 [OrbReplyBubble]）。三条约束：
/// **不显示思考过程**（只读 `draft.content`）、**随内容自适应大小**、
/// **全部文字显示完之后驻留 5 秒自动消失**（点气泡外任意位置也能提前关掉，
/// 但点球本身不关 —— 球的手势全部照旧）。
///
/// 双方消息照旧落库到 AI 助手聊天页 —— 那是 [ChatProvider.sendMessage] 内部
/// 就做好的，这里一行都不用改。
class FloatingAssistantOrb extends StatefulWidget {
  const FloatingAssistantOrb({super.key});

  /// 空闲多久后降低透明度（避免长期遮挡内容）
  static const Duration idleAfter = Duration(seconds: 30);

  /// 空闲时的透明度
  static const double idleOpacity = 0.7;

  /// 手指上滑超过这个距离（逻辑像素）就进入「松手取消」。
  ///
  /// 单一真相来源在 [VoiceDirectPolicy.cancelSlop]（纯 Dart，可单测）。
  static const double cancelSlop = VoiceDirectPolicy.cancelSlop;

  /// 拖动结束后的「忽略单击」窗口。
  ///
  /// 拖完手指抬起时常会带一点残余位移/抖动，会和上一次点击凑成一次假双击，
  /// 把设置页打开。宁可丢掉一次刚拖完的单击。
  static const Duration postDragTapGuard = Duration(milliseconds: 300);

  @override
  State<FloatingAssistantOrb> createState() => _FloatingAssistantOrbState();
}

class _FloatingAssistantOrbState extends State<FloatingAssistantOrb>
    with SingleTickerProviderStateMixin {
  final OrbTapArbiter _taps = OrbTapArbiter();

  /// 录音时向外扩散的光晕。只有采集期间才 repeat —— 常驻动画会白白耗电。
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// 从磁盘读出来的坐标（null = 首次使用，或读取失败）
  OrbPoint? _saved;

  /// 拖动中的实时坐标；null = 还没拖动过，用 [_saved] 或默认落点
  OrbPoint? _pos;

  Timer? _tapTimer;
  Timer? _idleTimer;

  bool _pressed = false;
  bool _dragging = false;
  bool _idle = false;

  /// 长按语音：手指按着、正在采集
  bool _voiceActive = false;

  /// 手指上滑进了取消区，松手就作废
  bool _voiceCancelArmed = false;

  /// 采集真的起来了（拿到麦克风权限后才会置 true）
  bool _voiceStarted = false;

  /// 松手后正在转文字 / 正在交给 AI
  bool _voiceBusy = false;

  /// 这一轮语音失败过 —— 球变红闪一下再回到常态
  bool _voiceFailed = false;

  /// 已录秒数，画在球旁边的计时标签上（`0:03`）
  int _voiceSeconds = 0;

  final VoiceRecorder _recorder = VoiceRecorder();
  Timer? _voiceTimer;
  DateTime? _voiceStartedAt;

  /// 拖动结束后的「忽略单击」截止时间
  DateTime? _ignoreTapUntil;

  // ─────────────────────────────────────────────
  // 回复气泡（语音直通的「后半场」）
  // ─────────────────────────────────────────────

  /// 当前要显示的气泡内容；[OrbReply.hidden] = 不显示
  OrbReply _reply = OrbReply.hidden;

  /// 「全部文字显示完之后再驻留 5 秒」的计时器
  Timer? _replyTimer;

  /// 本轮是否已被用户手动关掉。
  ///
  /// 关掉之后流式增量还会继续来（`draft` 一直在推），不加这个开关的话
  /// 下一个 token 就会把气泡**又弹回来**。
  bool _replySuppressed = false;

  /// 正在跑的语音回合用的是哪个 [ChatProvider]（挂/摘 `draft` 监听要用同一个）
  ChatProvider? _chatForReply;

  /// 气泡的 RenderBox 句柄 —— 「点气泡外关闭」要靠它把**气泡自身**排除掉
  final GlobalKey _bubbleKey = GlobalKey();

  /// 最近一次布局算出的球矩形（屏幕坐标）。
  ///
  /// 缓存下来而不是在指针回调里现算：指针回调不在 build 里，
  /// 那里去 `MediaQuery.sizeOf(context)` 会顺手注册一个 InheritedWidget
  /// 依赖，属于「能用但别扭」的写法。这里存的是**已经布局出来的真实位置**，
  /// 比现算还准。
  Rect _lastOrbRect = Rect.zero;

  /// 全局指针路由是否已挂上
  bool _dismissRouteOn = false;

  @override
  void initState() {
    super.initState();
    _restorePosition();
    _restartIdleTimer();
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _idleTimer?.cancel();
    _voiceTimer?.cancel();
    _replyTimer?.cancel();
    _removeDismissRoute();
    // 正常路径在 `_sendVoiceMessage` 的 finally 里摘；这里兜一次底
    _chatForReply?.draft.removeListener(_onDraftTick);
    _pulse.dispose();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  /// 开关录音光晕。
  void _setPulsing(bool on) {
    if (on) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      if (_pulse.isAnimating) _pulse.stop();
      _pulse.value = 0;
    }
  }

  Future<void> _restorePosition() async {
    final saved = await OrbPositionStore.load();
    if (!mounted) return;
    // 只记录，不在这里钳制 —— 存进去时的屏幕尺寸和现在可能不同
    // （旋转、分屏、换设备恢复），钳制交给 build 里的 _resolve
    setState(() => _saved = saved);
  }

  // ─────────────────────────────────────────────
  // 位置
  // ─────────────────────────────────────────────

  /// 算出这一帧该画在哪。
  ///
  /// 每次都重新钳制：屏幕尺寸/安全区变了（旋转、键盘、分屏）也不会把球
  /// 留在屏幕外。
  OrbPoint _resolve(Size size, EdgeInsets viewPadding) {
    final raw = _pos ??
        _saved ??
        OrbGeometry.defaultPosition(
          width: size.width,
          height: size.height,
          bottomInset: viewPadding.bottom,
        );
    return OrbGeometry.clamp(
      raw,
      width: size.width,
      height: size.height,
      topInset: viewPadding.top,
      bottomInset: viewPadding.bottom,
    );
  }

  // ─────────────────────────────────────────────
  // 空闲降透明度
  // ─────────────────────────────────────────────

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    if (_idle) setState(() => _idle = false);
    _idleTimer = Timer(FloatingAssistantOrb.idleAfter, () {
      if (mounted) setState(() => _idle = true);
    });
  }

  // ─────────────────────────────────────────────
  // 手势
  // ─────────────────────────────────────────────

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  void _onTapUp(TapUpDetails _) {
    _pressed = false;
    _restartIdleTimer();

    // 刚拖完，忽略这一次
    final guard = _ignoreTapUntil;
    if (guard != null && DateTime.now().isBefore(guard)) {
      setState(() {});
      return;
    }

    final action = _taps.registerTap(_nowMs());
    switch (action) {
      case OrbTapAction.doubleTap:
        _tapTimer?.cancel();
        _tapTimer = null;
        setState(() {});
        _openSettings();
      case OrbTapAction.pending:
        _tapTimer?.cancel();
        _tapTimer = Timer(Duration(milliseconds: _taps.windowMs), () {
          _tapTimer = null;
          if (_taps.resolvePending()) _openChat();
        });
        setState(() {});
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    // 长按一旦成立，之前那次「待确认的单击」就作废 ——
    // 否则松手后 200ms 窗口到期会把聊天页打开
    _taps.reset();
    _tapTimer?.cancel();
    _tapTimer = null;
    _restartIdleTimer();
    if (_voiceActive || _voiceBusy) return;

    setState(() {
      _pressed = false;
      _voiceActive = true;
      _voiceCancelArmed = false;
      _voiceFailed = false;
      _voiceStarted = false;
      _voiceSeconds = 0;
    });
    _voiceStartedAt = DateTime.now();
    _setPulsing(true);

    _voiceTimer?.cancel();
    _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_voiceActive) return;
      if (VoiceDirectPolicy.reachedCap(_voiceSeconds + 1)) {
        // 到顶自动收尾，别让用户一直按着
        setState(() => _voiceSeconds = VoiceDirectPolicy.maxHoldSeconds);
        unawaited(_finishVoice());
        return;
      }
      setState(() => _voiceSeconds++);
    });

    unawaited(_beginVoiceRecording());
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details) {
    // ★ 必须先判断是否真的在录音。
    // 同时挂 onTap* 与 onLongPress* 时，**普通点按也会触发 onLongPressCancel**
    // （长按识别器被 reject 时会回调 cancel），不加这个守卫会把状态搞乱。
    if (!_voiceActive) return;
    final armed = VoiceDirectPolicy.cancelArmed(details.offsetFromOrigin.dy);
    if (armed == _voiceCancelArmed) return;
    setState(() => _voiceCancelArmed = armed);
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    // ★ 不在这里清 `_voiceActive` —— 由 `_finishVoice` 自己收尾，
    //   否则「录音还没起来就松手」这条路径会漏掉。
    if (!_voiceActive) return;
    unawaited(_finishVoice());
  }

  void _onLongPressCancel() {
    // ★ 同上：普通点按也会走到这里，必须先判断状态
    if (!_voiceActive) return;
    _abortVoice();
  }

  // ─────────────────────────────────────────────
  // 语音直通
  // ─────────────────────────────────────────────

  /// 启动采集。
  ///
  /// 第一步是 [TtsPlayer.stop]：不先停掉上一条朗读的话，喇叭里的声音会被
  /// 自己的麦克风收进去，识别结果里混进 AI 自己说的话。
  Future<void> _beginVoiceRecording() async {
    await TtsPlayer.stop();
    if (!mounted) return;
    try {
      final ok = await _recorder.start();
      if (!mounted) return;
      if (!ok) {
        _abortVoice('没有麦克风权限，请在系统设置里允许「折花日记」使用麦克风');
        return;
      }
      // ★ 首次使用时 `start()` 里会弹系统授权框，期间长按手势会被系统打断
      //   （`_abortVoice` / `_finishVoice` 已经跑过，`_voiceActive` 已归位）。
      //   这时**必须显式把采集关掉** —— 否则麦克风会一直开着，
      //   而且用户完全看不出来（球已经回到常态）。
      if (!_voiceActive) {
        await _recorder.cancel();
        return;
      }
      _voiceStarted = true;
    } catch (e) {
      if (!mounted) return;
      _abortVoice('语音输入启动失败：${friendlyVoiceError(e)}');
    }
  }

  /// 松手收尾：取消 / 太短 / 转文字 / 直发 AI。
  Future<void> _finishVoice() async {
    if (!_voiceActive) return;

    final cancelled = _voiceCancelArmed;
    final started = _voiceStarted;
    final held = _voiceStartedAt == null
        ? 0
        : DateTime.now().difference(_voiceStartedAt!).inMilliseconds;

    _voiceTimer?.cancel();
    _voiceTimer = null;
    _voiceStartedAt = null;
    _voiceStarted = false;
    _setPulsing(false);
    setState(() {
      _voiceActive = false;
      _voiceCancelArmed = false;
    });

    // 上滑取消：什么都不发生（文件由 recorder 自己删）
    if (cancelled) {
      await _recorder.cancel();
      return;
    }

    // 录音没起来（多半是没给权限），_abortVoice / _beginVoiceRecording 已提示过
    if (!started) return;

    if (!VoiceDirectPolicy.longEnough(held)) {
      await _recorder.cancel();
      _hint('说话时间太短，按住多说一会儿');
      return;
    }

    setState(() => _voiceBusy = true);

    String? path;
    try {
      path = await _recorder.stop();
      if (path == null || path.isEmpty) throw Exception('没有拿到音频文件');

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
      final spoken = text.trim();
      if (spoken.isEmpty) {
        _hint('没有听清，再试一次？');
        return;
      }

      setState(() => _voiceBusy = false);
      unawaited(_sendVoiceMessage(spoken));
    } catch (e) {
      if (!mounted) return;
      _flashVoiceError(friendlyVoiceError(e));
    } finally {
      // ★ D3：原音频不保存，用完即删。
      //    成功与失败路径都要删 —— 否则每次识别失败都会在临时目录留一个 WAV。
      await deleteTempAudio(path);
      if (mounted && _voiceBusy) setState(() => _voiceBusy = false);
    }
  }

  /// 识别结果**不经过输入框、不做二次确认**，直接发给 AI。
  ///
  /// ⚠️ **刻意不跳转聊天页**（用户拍板）—— 回复显示在球旁边的气泡框里。
  /// 双方消息照旧落库到 AI 助手聊天页（由 [ChatProvider.sendMessage] 内部完成），
  /// 用户想看完整对话（含思考过程）时自己点球进去。
  ///
  /// 回复到达后由 [ChatProvider] 按 [ReplyStyle.voiceBrief] 自动朗读。
  Future<void> _sendVoiceMessage(String text) async {
    final chat = context.read<ChatProvider>();
    final session = context.read<ChatSessionProvider>();

    _beginReply();

    // ★ 监听必须在 `sendMessage` **之前**挂上：它开头就会 `_clearDraft()`
    //   并 notifyListeners，挂晚了会丢掉第一段增量。
    _chatForReply = chat;
    chat.draft.addListener(_onDraftTick);

    try {
      await chat.sendMessage(
        text,
        session: session,
        style: ReplyStyle.voiceBrief,
      );
      if (!mounted || _replySuppressed) return;

      // ★ `sendMessage` 的 finally 会 `_clearDraft()`，所以**不能**在这里读
      //   `draft.value`（一定是空的）。权威文本只能从会话里取最后一条助手消息。
      final authoritative = _lastAssistantText(session);
      if (authoritative != null && authoritative.isNotEmpty) {
        _showReplyDone(authoritative);
      } else if ((chat.error ?? '').isNotEmpty) {
        _showReplyFailed(chat.error!);
      } else {
        _dismissReply();
      }
    } catch (e) {
      if (mounted && !_replySuppressed) {
        _showReplyFailed(friendlyVoiceError(e));
      }
    } finally {
      chat.draft.removeListener(_onDraftTick);
      if (identical(_chatForReply, chat)) _chatForReply = null;
    }
  }

  /// 流式镜像：把 `draft.content` 搬到气泡上。
  ///
  /// **只读 `content`，永不读 `reasoning`** —— 这就是「不显示思考」的全部实现。
  void _onDraftTick() {
    if (!mounted || _replySuppressed) return;
    final text = _chatForReply?.draft.value.content ?? '';
    // ★ 必须忽略「被清空」那一次：`sendMessage` 的 finally 会 `_clearDraft()`，
    //   不拦的话它会把已经攒好的整段回复**抹成空**，气泡当场消失。
    if (text.isEmpty) return;
    if (_reply.phase == OrbReplyPhase.streaming && _reply.text == text) return;
    _applyReply(OrbReply(phase: OrbReplyPhase.streaming, text: text));
  }

  /// 从会话里取最后一条助手消息的正文（`sendMessage` 已经把它落库了）
  static String? _lastAssistantText(ChatSessionProvider session) {
    final msgs = session.messages;
    if (msgs.isEmpty) return null;
    final last = msgs.last;
    if (last.isUser) return null;
    final text = last.content.trim();
    return text.isEmpty ? null : text;
  }

  /// 开一轮新气泡（清掉上一轮的「已手动关掉」标记）
  void _beginReply() {
    _replyTimer?.cancel();
    _replyTimer = null;
    _replySuppressed = false;
    _applyReply(const OrbReply(phase: OrbReplyPhase.waiting));
  }

  /// 回复全部到齐 —— 驻留 [OrbReplyPolicy.dwell]（5 秒）后自动消失
  void _showReplyDone(String text) {
    _replyTimer?.cancel();
    _applyReply(OrbReply(phase: OrbReplyPhase.done, text: text));
    _replyTimer = Timer(OrbReplyPolicy.dwell, _dismissReply);
  }

  void _showReplyFailed(String message) {
    _replyTimer?.cancel();
    _applyReply(OrbReply(phase: OrbReplyPhase.failed, text: message));
    // 失败也给自动消失，但留长一点让用户读得完
    _replyTimer = Timer(const Duration(seconds: 8), _dismissReply);
  }

  /// 收起气泡。[suppress] = 本轮不要再被流式增量弹回来。
  void _dismissReply({bool suppress = false}) {
    _replyTimer?.cancel();
    _replyTimer = null;
    if (suppress) _replySuppressed = true;
    _applyReply(OrbReply.hidden);
  }

  void _applyReply(OrbReply reply) {
    if (!mounted) return;
    setState(() => _reply = reply);
    _syncDismissRoute();
  }

  // ─────────────────────────────────────────────
  // 「点气泡外任意位置关闭」
  // ─────────────────────────────────────────────

  /// 让「全局指针路由」的挂载状态与气泡可见性保持一致 ——
  /// 气泡不在时一个回调都不该挂着。
  void _syncDismissRoute() {
    if (_reply.visible) {
      _addDismissRoute();
    } else {
      _removeDismissRoute();
    }
  }

  void _addDismissRoute() {
    if (_dismissRouteOn) return;
    _dismissRouteOn = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
  }

  void _removeDismissRoute() {
    if (!_dismissRouteOn) return;
    _dismissRouteOn = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
  }

  /// 点气泡外任意位置 → 关掉气泡（**AI 助手图标本身除外**）。
  ///
  /// 为什么用**全局指针路由**，而不是铺一层全屏 `GestureDetector`：
  /// 悬浮球挂在 `MaterialApp.builder` 的 Stack 里，任何铺满屏幕、可命中测试
  /// 的层都会**抢掉整个 App 的点击** —— `RenderStack` 的命中测试命中第一个
  /// 子节点就 `return true`，不会再往下走，于是下面的页面全部点不动。
  /// 而 `pointerRouter.addGlobalRoute` 只是**旁听**所有指针事件、完全不参与
  /// 命中测试 —— 所以既能做到「点哪都能关」，又不影响用户继续操作底下的界面。
  void _onGlobalPointer(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    if (!_reply.visible || !mounted) return;

    final p = event.position;
    // ★「AI 助手图标除外」：球上的单击 / 双击 / 长按 / 拖动全部照旧
    if (_orbRect().inflate(4).contains(p)) return;
    // 点气泡本身也不关 —— 用户要的是「点气泡**外**」
    final bubble = _bubbleRect();
    if (bubble != null && bubble.inflate(2).contains(p)) return;

    _dismissReply(suppress: true);
  }

  /// 球的矩形（屏幕坐标）。用于把球排除出「点外面就关」的判定。
  Rect _orbRect() => _lastOrbRect;

  /// 气泡的矩形（屏幕坐标）。气泡还在布局中时返回 null。
  Rect? _bubbleRect() {
    final box = _bubbleKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// 静默作废本次采集（手势被系统打断、权限没给、启动异常）。
  void _abortVoice([String? message]) {
    _voiceTimer?.cancel();
    _voiceTimer = null;
    _voiceStartedAt = null;
    _voiceStarted = false;
    _setPulsing(false);
    if (mounted) {
      setState(() {
        _voiceActive = false;
        _voiceCancelArmed = false;
      });
    } else {
      _voiceActive = false;
      _voiceCancelArmed = false;
    }
    unawaited(_recorder.cancel());
    if (message != null) _hint(message);
  }

  /// 失败时让球变红闪一下，再回到常态。
  void _flashVoiceError(String message) {
    setState(() {
      _voiceBusy = false;
      _voiceFailed = true;
    });
    _hint(message);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _voiceFailed) setState(() => _voiceFailed = false);
    });
  }

  void _onPanStart(DragStartDetails _) {
    _taps.reset();
    _tapTimer?.cancel();
    _tapTimer = null;
    _restartIdleTimer();
    // 理论上长按赢了竞技场之后 pan 就被 reject 了，但真机上「先按住不动、
    // 再横向拖」偶尔两边都会回调 —— 采集中的话必须显式作废，
    // 否则麦克风会一直开着（用户完全看不出来）。
    if (_voiceActive) _abortVoice();
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    setState(() {
      _dragging = true;
      _pressed = false;
      _pos = _resolve(size, padding);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final base = _pos ?? _resolve(size, padding);
    setState(() {
      _pos = OrbGeometry.clamp(
        OrbPoint(base.x + details.delta.dx, base.y + details.delta.dy),
        width: size.width,
        height: size.height,
        topInset: padding.top,
        bottomInset: padding.bottom,
      );
    });
  }

  void _onPanEnd(DragEndDetails _) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final base = _pos ?? _resolve(size, padding);
    final snapped = OrbGeometry.snapToEdge(base, width: size.width);
    setState(() {
      _dragging = false;
      _pos = snapped;
      _ignoreTapUntil = DateTime.now().add(FloatingAssistantOrb.postDragTapGuard);
    });
    unawaited(OrbPositionStore.save(snapped));
  }

  // ─────────────────────────────────────────────
  // 动作
  // ─────────────────────────────────────────────

  void _openChat() {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: OrbRoutes.chat),
        builder: (_) => const ChatScreen(),
      ),
    );
  }

  void _openSettings() {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: OrbRoutes.aiSettings),
        builder: (_) => const AiAssistantSettingsScreen(),
      ),
    );
  }

  void _hint(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ─────────────────────────────────────────────
  // 渲染
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<AppChromeProvider>();

    return ValueListenableBuilder<Route<dynamic>?>(
      valueListenable: AssistantRouteObserver.topRoute,
      builder: (context, route, _) {
        final visible = OrbVisibility.shouldShow(
          OrbVisibilityInput(
            // loaded 之前不渲染：否则用户把球关掉后，每次冷启动都会看到它闪一下
            enabled: chrome.loaded && chrome.orbEnabled,
            shellVisible: chrome.shellVisible,
            topIsPopupRoute: route is PopupRoute,
            topRouteName: route?.settings.name,
            onSettingsTab: chrome.onSettingsTab,
          ),
        );
        if (!visible) return const SizedBox.shrink();

        final size = MediaQuery.sizeOf(context);
        final padding = MediaQuery.viewPaddingOf(context);
        final pos = _resolve(size, padding);

        // 缓存这一帧的真实球矩形，供指针回调判断「点的是不是球」
        _lastOrbRect = Rect.fromLTWH(
          pos.x,
          pos.y,
          OrbGeometry.orbSize,
          OrbGeometry.orbSize,
        );

        return Positioned.fill(
          child: Stack(
            children: [
              AnimatedPositioned(
                // 拖动中不能有动画，否则球会「追着」手指跑
                duration: _dragging
                    ? Duration.zero
                    : OrbGeometry.snapDuration,
                curve: Curves.easeOut,
                left: pos.x,
                top: pos.y,
                child: _orbBody(pos, size),
              ),
              // 回复气泡画在球的**兄弟层**（而不是塞进 `_orbBody` 里）：
              // 免得被球的 `AnimatedOpacity` / `AnimatedScale` 带着一起
              // 变暗、缩小。
              if (_reply.visible) _replyBubble(pos, size, padding),
            ],
          ),
        );
      },
    );
  }

  /// 气泡框的位置与尺寸。
  ///
  /// - **水平**：永远贴在球的**屏幕内侧**（球吸左边时气泡在右，反之在左），
  ///   尾巴朝着球 —— 与 `_voiceBadge` 同一套 `onLeftHalf` 判断；
  /// - **垂直**：让尾巴中心线对齐球心。上界用 `maxHeight` 反推做 clamp，
  ///   所以**不需要先量出气泡高度** —— 避开了「居中要高度、高度要布局」
  ///   那个死循环（量高度要等一帧，会看到气泡跳一下）。
  Widget _replyBubble(OrbPoint pos, Size size, EdgeInsets padding) {
    final onLeftHalf = pos.x + OrbGeometry.orbSize / 2 < size.width / 2;
    final orbCenterY = pos.y + OrbGeometry.orbSize / 2;

    // 可用宽度：从球的内侧边缘一直到屏幕内侧边缘
    final available = onLeftHalf
        ? size.width -
            (pos.x + OrbGeometry.orbSize + OrbReplyPolicy.tailLength) -
            OrbReplyPolicy.screenMargin
        : pos.x - OrbReplyPolicy.tailLength - OrbReplyPolicy.screenMargin;
    final maxW = available.clamp(
      OrbReplyPolicy.minWidth,
      OrbReplyPolicy.maxWidth,
    );
    final maxH = size.height * OrbReplyPolicy.maxHeightRatio;

    // ── 竖直定位 ──
    // 让**尾巴中心线**落在球心上（`tailY` 是尾巴相对气泡自身顶部的高度），
    // 于是「气泡顶部 = 球顶」—— 短气泡尾巴居中、长气泡尾巴靠上，
    // 和 QQ / 微信气泡的观感一致，且**不需要先量出气泡高度**。
    final minTop = padding.top + OrbReplyPolicy.screenMargin;
    final hardBottom = size.height - padding.bottom - OrbReplyPolicy.screenMargin;
    final desiredTop = orbCenterY - OrbReplyPolicy.tailY;

    // ⚠️ 上界**只能**按「至少要放得下一个最小可读气泡」来算。
    //    早先按 `maxH`（= 屏高 45%）反推，等于假设气泡永远长到顶格 ——
    //    球在下半屏时会把气泡一路顶到屏幕中上部，尾巴和球心差了近 180 逻辑像素。
    final minReadable = math.min(120.0, maxH);
    final maxTop = math.max(minTop, hardBottom - minReadable);
    final top = desiredTop.clamp(minTop, maxTop);

    // 高度上限还要再收一次：不能越过下边界。
    // 取 `max(minHeight)` 兜底，否则会出现 minHeight > maxHeight 的非法约束。
    final availH = math.max(
      OrbReplyPolicy.minHeight,
      math.min(maxH, hardBottom - top),
    );

    return Positioned(
      // 这个 key 供 `_bubbleRect()` 用 —— 「点气泡外关闭」要靠它把气泡
      // 自身排除掉，否则点气泡也会关（用户要的是「点气泡外」）
      key: _bubbleKey,
      top: top,
      left: onLeftHalf
          ? pos.x + OrbGeometry.orbSize + OrbReplyPolicy.tailLength
          : null,
      right: onLeftHalf
          ? null
          : size.width - pos.x + OrbReplyPolicy.tailLength,
      child: OrbReplyBubble(
        reply: _reply,
        tailOnLeft: onLeftHalf,
        maxWidth: maxW,
        maxHeight: availH,
      ),
    );
  }

  Widget _orbBody(OrbPoint pos, Size size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 取消态与失败态都变红 —— 红色在这条链路里只有一个含义：这次不会发出去
    final alarming = _voiceCancelArmed || _voiceFailed;
    final accent = alarming
        ? AppColors.deleteRed
        : (isDark ? AppColors.darkPink : AppColors.pink);
    // 中高明度的底一律配深色图标（见 AppColors 里的对比度结论）
    final fg = isDark ? AppColors.darkPageBackground : AppColors.titleText;

    final voiceUi = _voiceActive || _voiceBusy || _voiceFailed;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _restartIdleTimer();
        if (!_pressed) setState(() => _pressed = true);
      },
      onTapUp: _onTapUp,
      onTapCancel: () {
        if (_pressed) setState(() => _pressed = false);
      },
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMove,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _idle && !_pressed && !_dragging && !voiceUi
            ? FloatingAssistantOrb.idleOpacity
            : 1.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _dragging
              ? 1.08
              : (_pressed || _voiceActive ? 0.94 : 1.0),
          child: SizedBox(
            width: OrbGeometry.orbSize,
            height: OrbGeometry.orbSize,
            // Clip.none：脉冲光晕与计时标签都要画到球的框外面去
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (_voiceActive)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => _pulseRing(accent),
                  ),
                _orbCore(isDark, accent, fg),
                if (voiceUi) _voiceBadge(pos, size, isDark, accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 球体本身（底色 + 投影 + 图标/转圈）。
  Widget _orbCore(bool isDark, Color accent, Color fg) {
    return Container(
      width: OrbGeometry.orbSize,
      height: OrbGeometry.orbSize,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.22),
            blurRadius: _dragging ? 14 : 10,
            offset: Offset(0, _dragging ? 4 : 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: _orbGlyph(fg),
    );
  }

  Widget _orbGlyph(Color fg) {
    if (_voiceBusy) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
      );
    }

    final IconData icon;
    if (_voiceFailed) {
      icon = Icons.error_outline_rounded;
    } else if (_voiceCancelArmed) {
      icon = Icons.close_rounded;
    } else if (_voiceActive) {
      icon = Icons.mic_rounded;
    } else {
      icon = Icons.auto_awesome;
    }
    return Icon(icon, size: 24, color: fg);
  }

  /// 采集期间从球体向外扩散的光晕 —— 这是「麦克风真的开着」的唯一动效。
  Widget _pulseRing(Color accent) {
    final t = _pulse.value; // 0 → 1
    final diameter = OrbGeometry.orbSize * (1 + 0.35 * t);
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 扩散到最大时刚好淡出，不会留一个硬边
          color: accent.withValues(alpha: 0.32 * (1 - t)),
        ),
      ),
    );
  }

  /// 球旁边的状态标签：`0:03` / `取消` / `识别中` / `失败`。
  ///
  /// 贴在球**靠屏幕内侧**的一侧 —— 球吸在左边缘时标签在右，反之在左，
  /// 这样标签永远不会被挤到屏幕外。
  Widget _voiceBadge(OrbPoint pos, Size size, bool isDark, Color accent) {
    final label = _voiceFailed
        ? '失败'
        : _voiceBusy
            ? '识别中'
            : _voiceCancelArmed
                ? '取消'
                : VoiceDirectPolicy.formatSeconds(_voiceSeconds);

    final onLeftHalf = pos.x + OrbGeometry.orbSize / 2 < size.width / 2;
    const gap = 8.0;

    return Positioned(
      top: OrbGeometry.orbSize / 2 - 13,
      left: onLeftHalf ? OrbGeometry.orbSize + gap : null,
      right: onLeftHalf ? null : OrbGeometry.orbSize + gap,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkChatBubble : AppColors.chatBubble,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: _voiceFailed || _voiceCancelArmed
                  ? AppColors.deleteRed
                  : accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              // 等宽数字：秒数跳动时标签宽度不会来回抖
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
