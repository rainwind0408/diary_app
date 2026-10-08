import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../data/models/chat_message_record.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../diary_list/services/temp_cover_store.dart';
import '../models/chat_attachment.dart';
import '../models/chat_message.dart';
import '../models/image_gen_result.dart';
import '../models/media_marker.dart';
import '../models/reasoning_model.dart';
import '../models/reply_style.dart';
import '../models/streaming_draft.dart';
import '../services/ai_config_store.dart';
import '../services/attachment_codec.dart';
import '../services/attachment_store.dart';
import '../services/chat_context_builder.dart';
import '../services/chat_message_mapper.dart';
import '../services/chat_message_query.dart';
import '../services/diary_mcp.dart';
import '../services/image_gen_service.dart';
import '../services/llm_service.dart';
import '../services/sse_parser.dart';
import '../services/tool_confirmation_gate.dart';
import '../services/tts_player.dart';
import 'chat_session_provider.dart';

/// AI 对话引擎。
///
/// 消息的**唯一真相来源**是 [ChatSessionProvider]（落库）。本类只负责：
/// 组装上下文 → 调 LLM（流式）→ 执行 MCP 工具 → 把结果写回会话。
/// 界面渲染请直接读 [ChatSessionProvider.messages]，不要再从这里取消息。
///
/// **刷新纪律**：正在流式输出时，增量只写进 [draft]（一个独立的
/// `ValueNotifier`），**不要**调 `notifyListeners()` —— 那会让整屏重建，
/// 逐 token 地调必然掉帧。`notifyListeners()` 只用于粗粒度状态变化
/// （开始 / 结束 / 报错 / 落库）。
class ChatProvider extends ChangeNotifier {
  final LlmService _llmService = LlmService();

  /// 生图服务。**必须**和 [_mcpServer] 用同一个实例 —— 否则用户点「停止」时
  /// 调的是这个实例的 [ImageGenService.abort]，中断不了真正在跑的那个请求。
  final ImageGenService _imageGen = ImageGenService();

  late final DiaryMcpServer _mcpServer;

  bool _isLoading = false;
  String? _error;
  bool _stopRequested = false;

  /// 正在生成的这次请求属于哪个会话。
  ///
  /// 请求被「钉」在发起它的那个会话上。用户中途切走时：
  /// ① 它的草稿气泡不该在新会话里露头（看起来就像「上一个会话的回复跑进
  ///    新会话了」）；② 组装上下文时不能拿成新会话的消息（会把两个会话的
  ///    内容串在一起，甚至把新会话的私密内容发给模型）。
  /// 判定入口是 [isGeneratingFor]。
  int? _activeSessionId;

  /// 正在流式输出的草稿。由草稿气泡单独订阅，不走 [notifyListeners]。
  final ValueNotifier<StreamingDraft> draft =
      ValueNotifier(StreamingDraft.empty);

  /// 增量攒批的间隔。
  ///
  /// 模型每秒能吐几十上百个 token，若每个 token 都刷一次草稿，
  /// 草稿气泡里的 Markdown 会跟着重排几十上百次 —— 必然掉帧。
  /// 攒到 ~50ms 刷一次（20 次/秒）视觉上已经足够顺滑。
  static const Duration _flushInterval = Duration(milliseconds: 50);

  Timer? _flushTimer;
  String _pendingContent = '';
  String _pendingReasoning = '';

  ChatProvider() {
    _mcpServer = DiaryMcpServer(DiaryRepository(), imageGen: _imageGen);
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 正在生成的请求是否属于 [sessionId]。
  ///
  /// 只有判定为「属于」才渲染草稿气泡、才把输入框显示成「生成中」。
  /// [_activeSessionId] 还没定下来时（首条消息正在 `ensureSession` 建会话）
  /// 认为它属于当前会话 —— 那种场景下还不存在第二个会话，不会误判。
  bool isGeneratingFor(int? sessionId) {
    if (!_isLoading || sessionId == null) return false;
    return _activeSessionId == null || _activeSessionId == sessionId;
  }

  /// 用户是否已经按过「停止」
  bool get stopRequested => _stopRequested;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    draft.dispose();
    // Provider 被销毁时工具循环也没了 —— 确认卡片不能继续挂着等一个
    // 永远不会来的用户点击
    ToolConfirmationGate.resolve(false);
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 对外：发送 / 重试 / 停止
  // ─────────────────────────────────────────────

  /// 发送一条用户消息（可带附件），并跑完整个「LLM ↔ 工具」循环。
  ///
  /// [style] 是**回合级**的回复风格。悬浮球语音直通传
  /// [ReplyStyle.voiceBrief]（150 字 + 默认播报）；打字提问用默认值。
  Future<void> sendMessage(
    String content, {
    required ChatSessionProvider session,
    List<ChatAttachment> attachments = const [],
    ReplyStyle style = ReplyStyle.normal,
  }) async {
    final text = content.trim();
    if (text.isEmpty && attachments.isEmpty) return;
    if (_isLoading) {
      // 单飞：同一时刻只跑一个请求。以前是静默 return，用户会以为按钮坏了
      _error = '正在生成回复，请稍候或先点「停止」';
      notifyListeners();
      return;
    }

    _error = null;
    _stopRequested = false;
    _clearDraft();
    _isLoading = true;
    // 先按「当前会话」占位，保证草稿气泡第一帧就能出现；
    // ensureSession 拿到真实 id 后再校正
    _activeSessionId = session.currentSessionId;
    notifyListeners();

    int? userMessageId;
    try {
      final target = await session.ensureSession();
      final sessionId = target.id!;
      _activeSessionId = sessionId;

      final saved = await session.appendMessage(
        ChatMessageRecord(
          sessionId: sessionId,
          role: ChatMessageRecord.roleUser,
          content: text,
          attachmentsJson: ChatAttachment.encodeList(attachments),
          status: ChatMessageRecord.statusSending,
        ),
      );
      userMessageId = saved.id;

      await _runLoop(session, sessionId, style: style);

      if (userMessageId != null) {
        await session.updateMessageStatus(
          userMessageId,
          ChatMessageRecord.statusSent,
        );
      }
    } catch (e) {
      _error = _friendlyError(e);
      if (userMessageId != null) {
        await session.updateMessageStatus(
          userMessageId,
          ChatMessageRecord.statusFailed,
        );
      }
    } finally {
      _isLoading = false;
      _activeSessionId = null;
      _clearDraft();
      notifyListeners();
    }
  }

  /// 重试一条失败的用户消息（不新增消息，只把原消息重新跑一遍）
  Future<void> retry({
    required ChatSessionProvider session,
    required int messageId,
  }) async {
    if (_isLoading) {
      _error = '正在生成回复，请稍候或先点「停止」';
      notifyListeners();
      return;
    }
    final sessionId = session.currentSessionId;
    if (sessionId == null) return;

    _error = null;
    _stopRequested = false;
    _clearDraft();
    _isLoading = true;
    _activeSessionId = sessionId;
    notifyListeners();

    try {
      await session.updateMessageStatus(
        messageId,
        ChatMessageRecord.statusSending,
      );
      await _runLoop(session, sessionId);
      await session.updateMessageStatus(
        messageId,
        ChatMessageRecord.statusSent,
      );
    } catch (e) {
      _error = _friendlyError(e);
      await session.updateMessageStatus(
        messageId,
        ChatMessageRecord.statusFailed,
      );
    } finally {
      _isLoading = false;
      _activeSessionId = null;
      _clearDraft();
      notifyListeners();
    }
  }

  /// 生图是否已就绪；未就绪时返回可以直接给用户看的原因。
  ///
  /// 入口按钮先问一句再弹输入框 —— 免得用户辛辛苦苦写完描述才发现没配 API。
  Future<String?> imageGenBlockReason() => _imageGen.checkReady();

  /// 用户点输入框里的「AI 画图」：把描述直接交给生图接口，**不经过对话模型**。
  ///
  /// 之所以绕一圈走工具执行器（而不是直接调 [ImageGenService]），是为了让
  /// 「用户点按钮」和「模型自己判断」两条路径产出的记录形状一致 ——
  /// 否则界面得维护两套「怎么把图片画出来」的逻辑。
  ///
  /// [referenceImagePath] 是「参考图」（任意临时/私有路径），给了就走图生图。
  /// 它会先落盘进附件目录再挂到用户消息上 —— 这样用户看得见自己引用了哪张，
  /// 下一次对话模型也能从上下文里看到它。
  Future<void> generateImage(
    String prompt, {
    required ChatSessionProvider session,
    String? referenceImagePath,
  }) async {
    final text = prompt.trim();
    if (text.isEmpty) return;
    if (_isLoading) {
      _error = '正在生成回复，请稍候或先点「停止」';
      notifyListeners();
      return;
    }

    final blocked = await _imageGen.checkReady();
    if (blocked != null) {
      // 还没配好就什么都不写进会话，只挂一条提示
      _error = blocked;
      notifyListeners();
      return;
    }

    _error = null;
    _stopRequested = false;
    _clearDraft();
    _isLoading = true;
    _activeSessionId = session.currentSessionId;
    notifyListeners();

    int? userMessageId;
    try {
      final target = await session.ensureSession();
      final sessionId = target.id!;
      _activeSessionId = sessionId;

      // 参考图先导入私有目录：相册给的临时路径随时可能被系统清掉
      final references = <ChatAttachment>[];
      final refPath = (referenceImagePath ?? '').trim();
      if (refPath.isNotEmpty) {
        references.add(await AttachmentStore.import(refPath));
      }

      final saved = await session.appendMessage(
        ChatMessageRecord(
          sessionId: sessionId,
          role: ChatMessageRecord.roleUser,
          content: text,
          attachmentsJson: ChatAttachment.encodeList(references),
          status: ChatMessageRecord.statusSending,
        ),
      );
      userMessageId = saved.id;

      final result = await _mcpServer.execute(
        DiaryMcpServer.imageToolName,
        {
          'prompt': text,
          if (references.isNotEmpty) 'reference_path': references.first.path,
        },
      );

      // 用户中途点了「停止」：结果丢掉，但保留他自己写的那条描述
      if (_stopRequested) {
        await _markUser(session, userMessageId, ChatMessageRecord.statusSent);
        return;
      }

      final image = ImageGenResult.tryParseMarker(result);
      if (image == null) {
        _error = _toolErrorMessage(result);
        await _markUser(session, userMessageId, ChatMessageRecord.statusFailed);
        return;
      }

      // 图片挂在**助手**消息上：这是 AI 给出的东西，不是用户发的。
      // 顺带一提，回传给模型时它会被 [ChatContextBuilder] 剥掉（图片只能出现在
      // user 消息里），所以不用担心下一次请求被判非法。
      final attachment = await AttachmentStore.describeLocalImage(
        image.path,
        name: _imageDisplayName(image.path),
      );
      await session.appendMessage(
        ChatMessageRecord(
          sessionId: sessionId,
          role: ChatMessageRecord.roleAssistant,
          content: '已生成图片',
          attachmentsJson: ChatAttachment.encodeList([attachment]),
        ),
      );
      await _markUser(session, userMessageId, ChatMessageRecord.statusSent);
    } catch (e) {
      _error = _friendlyError(e);
      await _markUser(session, userMessageId, ChatMessageRecord.statusFailed);
    } finally {
      _isLoading = false;
      _activeSessionId = null;
      _clearDraft();
      notifyListeners();
    }
  }

  /// 用户点「停止」：中断请求，但**保留已经流出来的内容**。
  ///
  /// 这里只负责打断；收尾（把半截回答落库）在 [_runLoop] 里做，
  /// 所以不会出现「点了停止，回答整段消失」。
  ///
  /// 生图也会一并中断 —— 它动辄几十秒，不掐掉的话「停止」要等到底才有反应。
  void stopStreaming() {
    // ★ 先放掉可能正挂着的确认卡片。工具循环此刻正 `await` 用户点确认，
    //   不在这里放掉的话，用户点了「停止」卡片还杵在那儿 —— 看起来像卡死了。
    ToolConfirmationGate.resolve(false);
    if (!_isLoading || _stopRequested) return;
    _stopRequested = true;
    _llmService.abortStream();
    _imageGen.abort();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  // 内部：LLM ↔ 工具循环
  // ─────────────────────────────────────────────

  Future<void> _runLoop(
    ChatSessionProvider session,
    int sessionId, {
    int depth = 0,
    ReplyStyle style = ReplyStyle.normal,
  }) async {
    if (depth > 5) {
      await session.appendMessage(
        ChatMessageRecord(
          sessionId: sessionId,
          role: ChatMessageRecord.roleAssistant,
          content: '工具调用次数过多，请尝试简化问题。',
        ),
      );
      return;
    }

    // 用户已经按了「停止」：别再发新请求（例如工具刚跑完、正要进入下一轮）
    if (_stopRequested) return;

    // ★ 必须按 sessionId 取消息，**不能**用 `session.messages`。
    // 用户可能在生成过程中切到别的会话，那时 `session.messages` 已经是另一个
    // 会话的内容了 —— 拿它组装上下文会把两个会话串在一起，甚至把新会话里
    // 的私密内容发给模型。落库时用的也是这里的 sessionId，两边保持一致。
    final records = await session.messagesOf(sessionId);
    final context = _buildContext(records);
    final tools = _mcpServer.getToolDefinitions();

    ChatMessage response;
    try {
      response = await _requestLlm(context, tools, style: style);
    } catch (e) {
      // 附件 base64 后体积膨胀，个别网关会以 413 / "too large" 拒绝整包请求。
      // 此时剥掉**所有**附件（文本全保留）再试一次，尽量别让用户白跑一趟。
      if (_looksLikePayloadTooLarge(e) && context.any((m) => m.hasAttachments)) {
        _clearDraft();
        response = await _requestLlm(
          context,
          tools,
          includeAttachments: false,
          style: style,
        );
        // 必须让用户知道这次没带附件，否则会困惑「AI 怎么装作没看见图片」
        _error = '附件体积过大被网关拒绝，本次已改为只发送文字';
      } else {
        rethrow;
      }
    }

    // 被打断（用户按了停止 / 网络中途断了）：把已经流出来的部分落库，
    // 并且不再继续跑工具 —— 半截回答也比整段消失好，这是「非破坏性收尾」。
    final interrupted = _stopRequested ||
        response.finishReason == LlmService.finishInterrupted;
    if (interrupted) {
      if (response.finishReason == LlmService.finishInterrupted) {
        _error = '网络中断，已保留生成到一半的回答';
      }
      if (_isPersistable(response)) {
        await session.appendMessage(
          ChatMessageMapper.toRecord(response, sessionId: sessionId),
        );
      }
      _clearDraft();
      return;
    }

    if (!_isPersistable(response)) {
      _error = '模型这次没有返回任何内容，请重试';
      _clearDraft();
      return;
    }

    // 思考过程把 max_tokens 吃光了 —— 下次请求已经会自动带上思考预算
    // （见 models/reasoning_model.dart），这里只需要讲清楚这次为什么是空的。
    if (looksTruncatedByReasoning(
      finishReason: response.finishReason,
      content: response.content,
      reasoning: response.reasoning,
    )) {
      _error = '思考过程占满了 token 上限，正文被挤掉了。'
          '已自动为该模型启用「思考预算」，请再试一次。';
    }

    final toolCalls = response.toolCalls;
    final hasTools = toolCalls != null && toolCalls.isNotEmpty;

    // 先落库助手回复（含 tool_calls），再执行工具 —— 顺序不能反，
    // 否则上下文里会出现「工具结果先于调用」的非法序列。
    final saved = await session.appendMessage(
      ChatMessageMapper.toRecord(response, sessionId: sessionId),
    );
    // 紧跟着清草稿：和落库在同一个微任务里，界面上不会出现「草稿 + 正式气泡」同屏
    _clearDraft();

    if (!hasTools) {
      // 用户已经切到别的会话了就别念 —— 在别的会话里突然开口说话很莫名。
      // 回复本身已经落在原会话里，切回去还能看到。
      if (session.currentSessionId == sessionId) {
        await _maybeAutoRead(saved, style: style);
      }
      return;
    }

    for (final toolCall in toolCalls) {
      // 每个工具都重新取一次：工具可能改动了会话（写日记等），
      // 而且要拿的是**这个会话**的消息，不是当前正在看的那个
      final latest = await session.messagesOf(sessionId);
      final result = await _executeTool(toolCall, latest);
      await session.appendMessage(
        ChatMessageRecord(
          sessionId: sessionId,
          role: ChatMessageRecord.roleTool,
          content: result,
          toolCallId: toolCall.id,
          toolName: toolCall.name,
          attachmentsJson: await _imageAttachmentsJson(result),
        ),
      );
      // 日记媒体标记：借一条 user 消息把图片送进模型视野（见方法注释）
      if (_stopRequested) return;
      await _injectMediaMarker(session, sessionId, result);
      // 语音回合（或模型显式要求）生成的图 → 顺带放到首页封面位
      await _maybePublishTempCover(toolCall, result, style);
    }

    await _runLoop(session, sessionId, depth: depth + 1, style: style);
  }

  /// 执行一次工具调用。
  ///
  /// 生图工具特殊一点：模型只说「参考用户最近发的图」，真正的文件路径得由
  /// 这里补上（工具层是无状态的，看不到会话消息）。找不到图就**直接回一句
  /// 明确的错误** —— 否则模型会一边说「照着你那张画的」，一边其实是凭空画的。
  Future<String> _executeTool(
    ToolCall toolCall,
    List<ChatMessageRecord> messages,
  ) async {
    var args = toolCall.arguments;

    if (toolCall.name == DiaryMcpServer.imageToolName &&
        _wantsRecentUserImage(args)) {
      final path = ChatMessageQuery.latestUserImagePath(messages);
      if (path == null) {
        return jsonEncode({
          'error': '对话里还没有用户发过的图片，无法参考。'
              '请先请用户发一张图片，再重试。',
        });
      }
      args = {...args, 'reference_path': path};
    }

    return _mcpServer.execute(toolCall.name, args);
  }

  /// 模型是不是要求「参考用户最近发的图」
  static bool _wantsRecentUserImage(Map<String, dynamic> args) {
    final ref = args['reference'];
    return ref is String && ref.isNotEmpty && ref != 'none';
  }

  /// 发起一次 LLM 请求，增量写进 [draft]
  Future<ChatMessage> _requestLlm(
    List<ChatMessage> context,
    List<Map<String, dynamic>> tools, {
    bool includeAttachments = true,
    ReplyStyle style = ReplyStyle.normal,
  }) async {
    final apiMessages = await _toApiMessages(
      context,
      includeAttachments: includeAttachments,
    );

    // 打字机效果关掉时**根本不走流式**，等整段回复拿到再一次性显示。
    //
    // 为什么不用「流式但攒着不刷」：那样既白占带宽，又让「停止」失去意义
    // （用户看不到进度，按了也还是得等）。代价是这段时间界面上只有
    // 「正在思考」，这是用户自己选的取舍。
    final ChatMessage result;
    if (AiConfigStore.cached?.typewriter == false) {
      result = await _llmService.chat(
        messages: apiMessages,
        tools: tools,
        style: style,
      );
    } else {
      result = await _llmService.chatStream(
        messages: apiMessages,
        tools: tools,
        onDelta: _onDelta,
        style: style,
      );
    }

    return result;
  }

  /// 逐 token 回调。**刻意不调 notifyListeners()** —— 见类文档的刷新纪律。
  ///
  /// 增量先攒进缓冲区，由 [_flushInterval] 的定时器批量刷进 [draft]。
  void _onDelta(StreamDelta delta) {
    if (delta.content.isNotEmpty) _pendingContent += delta.content;
    if (delta.reasoning.isNotEmpty) _pendingReasoning += delta.reasoning;
    if (_pendingContent.isEmpty && _pendingReasoning.isEmpty) return;
    _flushTimer ??= Timer.periodic(_flushInterval, (_) => _flushDraft());
  }

  void _flushDraft() {
    if (_pendingContent.isEmpty && _pendingReasoning.isEmpty) return;
    draft.value = draft.value.append(
      content: _pendingContent,
      reasoning: _pendingReasoning,
    );
    _pendingContent = '';
    _pendingReasoning = '';
  }

  void _clearDraft() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingContent = '';
    _pendingReasoning = '';
    if (draft.value.isEmpty) return;
    draft.value = StreamingDraft.empty;
  }

  /// 这条回答值不值得落库（避免留下一个空气泡）
  static bool _isPersistable(ChatMessage m) =>
      m.content.trim().isNotEmpty ||
      m.hasReasoning ||
      (m.toolCalls?.isNotEmpty ?? false);

  // ─────────────────────────────────────────────
  // 内部：生图结果落到消息上的辅助
  // ─────────────────────────────────────────────

  /// 工具返回的是生图标记时，把落盘的图片挂到这条工具消息上。
  ///
  /// 界面于是可以直接复用 [AttachmentView] 渲染（带点击全屏），
  /// 不必再写一套「解析 marker 画图」的逻辑。返回值里的 marker **原样保留** ——
  /// 模型得看到它才知道图已经画好了。
  Future<String> _imageAttachmentsJson(String toolResult) async {
    final image = ImageGenResult.tryParseMarker(toolResult);
    if (image == null) return ChatMessageRecord.emptyJsonArray;
    final attachment = await AttachmentStore.describeLocalImage(
      image.path,
      name: _imageDisplayName(image.path),
    );
    return ChatAttachment.encodeList([attachment]);
  }

  /// 生图结果落盘时文件名是一串随机戳，这里给它一个体面的显示名
  static String _imageDisplayName(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot >= 0 ? path.substring(dot) : '.png';
    return 'AI生图$ext';
  }

  /// 工具返回日记媒体标记时，追加一条 `role=user` 的消息把图片挂上去。
  ///
  /// ## 为什么非要绕这一圈
  ///
  /// 协议层只认 **user 消息里的附件**：
  /// - 挂在 `tool` 消息上 → 模型看不见（tool 的 content 必须是字符串）；
  /// - 挂在 `assistant` 消息上 → 会被
  ///   `ChatContextBuilder._stripNonUserAttachments` 静默剥掉。
  ///
  /// 所以「让模型看见日记图片」的唯一通路就是这条。生图的
  /// `ImageGenResult` 走的是同一条路（只是它把图挂在 tool 消息上给人看，
  /// 另有一份标记供识别）。
  ///
  /// ## 代价（已知且可接受）
  ///
  /// 会话里会多出一条看着像用户自己发的消息。所以正文带 `[系统] ` 前缀，
  /// 聊天页据此用淡底样式渲染、不显示用户头像（见 `ChatBubble`）。
  /// 另外它会占用附件预算，多张图连着看有超预算风险 ——
  /// `get_diary_media` 的提示词里已经要求模型一次只看一张。
  Future<void> _injectMediaMarker(
    ChatSessionProvider session,
    int sessionId,
    String toolResult,
  ) async {
    final media = MediaMarker.tryParse(toolResult);
    if (media == null) return;

    final attachments = <ChatAttachment>[];
    for (final path in media.imagePaths) {
      // 文件可能已经被用户删了 —— 不存在的图别挂，否则界面上是个破图标
      try {
        if (!await File(path).exists()) continue;
      } catch (_) {
        continue;
      }
      attachments.add(await AttachmentStore.describeLocalImage(path));
    }
    if (attachments.isEmpty) return;

    await session.appendMessage(
      ChatMessageRecord(
        sessionId: sessionId,
        role: ChatMessageRecord.roleUser,
        content: media.messageText,
        attachmentsJson: ChatAttachment.encodeList(attachments),
      ),
    );
  }

  /// 语音回合（或模型显式要求）生成的图 → 顺带放到首页封面位。
  ///
  /// ## 什么时候落
  ///
  /// - **语音回合**（[ReplyStyle.voiceBrief]）：用户按住球说「生成一张…」，
  ///   他要的就是「给我看张图」，顺手放到首页封面位与交互一一对应，
  ///   也不需要模型理解任何新概念；
  /// - **打字回合**：只有模型显式传 `as_cover: true` 才落 —— 打字聊天时
  ///   首页被悄悄改掉会让人莫名其妙。
  ///
  /// ## 什么时候不落
  ///
  /// - 用户点了「停止」/ 生图被中断：`_stopRequested` 为真时路径可能是半成品，
  ///   绝不能发布出去（方案 §6.4）；
  /// - 生图失败：返回值不是图片标记，`tryParseMarker` 返回 null，自然跳过。
  ///
  /// 复制失败（磁盘满 / 权限）不会抛给上层 —— 生图本身是成功的，
  /// 聊天页里的图照常显示。
  Future<void> _maybePublishTempCover(
    ToolCall toolCall,
    String toolResult,
    ReplyStyle style,
  ) async {
    if (toolCall.name != DiaryMcpServer.imageToolName) return;
    if (_stopRequested) return;

    final wantsCover = style == ReplyStyle.voiceBrief ||
        toolCall.arguments['as_cover'] == true;
    if (!wantsCover) return;

    final image = ImageGenResult.tryParseMarker(toolResult);
    if (image == null) return;

    await TempCoverStore.add(image.path, prompt: image.prompt);
  }

  /// 工具执行器把异常统一包成了 `{"error": "工具执行失败: Exception: xxx"}`。
  /// 手动生图这条路上没人去读原始 JSON，得把里面的原因掏出来给用户看。
  static String _toolErrorMessage(String toolResult) {
    try {
      final decoded = jsonDecode(toolResult);
      if (decoded is Map && decoded['error'] is String) {
        return _stripErrorPrefix(decoded['error'] as String);
      }
    } catch (_) {
      // 不是 JSON 就原样展示
    }
    return toolResult;
  }

  static String _stripErrorPrefix(String raw) {
    var s = raw.trim();
    for (final prefix in const ['工具执行失败: ', '工具执行失败：']) {
      if (s.startsWith(prefix)) s = s.substring(prefix.length).trim();
    }
    const exPrefix = 'Exception: ';
    if (s.startsWith(exPrefix)) s = s.substring(exPrefix.length).trim();
    return s;
  }

  /// 更新用户消息状态（id 为空时是「还没落库就失败了」，直接跳过）
  static Future<void> _markUser(
    ChatSessionProvider session,
    int? id,
    String status,
  ) async {
    if (id == null) return;
    await session.updateMessageStatus(id, status);
  }

  /// 开了「自动朗读回复」时，念一遍刚落库的这条助手消息。
  ///
  /// 放在 provider 而不是界面里，是因为「重新生成」也走这条路径 ——
  /// 写在按钮回调里的话，重新生成出来的回复就不会自动念了。
  ///
  /// 只念**最终**回复（没有再要工具的那条），否则一轮对话里会连念好几遍。
  ///
  /// 两个开关是分开的：语音回合看 [AiConfig.ttsAutoReadVoice]（默认**开**，
  /// 用语音提问的人默认就是想听回答），打字回合看 [AiConfig.ttsAutoRead]
  /// （默认关，保持升级前行为）。
  static Future<void> _maybeAutoRead(
    ChatMessageRecord saved, {
    ReplyStyle style = ReplyStyle.normal,
  }) async {
    final config = AiConfigStore.cached;
    if (config == null) return;

    final want = style == ReplyStyle.voiceBrief
        ? config.ttsAutoReadVoice
        : config.ttsAutoRead;
    if (!want) return;
    if (saved.id == null || !saved.isAssistant) return;
    if (saved.content.trim().isEmpty) return;

    // 朗读失败不该把整个发送流程带崩，[TtsPlayer] 内部已把原因收进 lastError。
    // 没配 TTS 厂商时它也是静默返回 —— 正好满足「未配 TTS 时降级为纯文字」。
    await TtsPlayer.speak(messageId: saved.id!, markdown: saved.content);
  }

  /// 取最近 `contextLimit` 条消息作为上下文（截断规则见 [ChatContextBuilder]）
  List<ChatMessage> _buildContext(List<ChatMessageRecord> records) {
    final limit = AiConfigStore.cached?.contextLimit ?? 20;
    return ChatContextBuilder.build(records, limit);
  }

  /// 把业务消息组装成 API 消息体。
  ///
  /// 只有带附件的消息才需要异步编码（读文件 + base64）；纯文本消息直接
  /// 走 [ChatMessage.toApiMap] 的字符串分支，避免无谓的 await 开销。
  ///
  /// [includeAttachments] 为 false 时把所有附件降级为纯文本 —— 供
  /// 「请求体过大」时重试使用。
  Future<List<Map<String, dynamic>>> _toApiMessages(
    List<ChatMessage> messages, {
    bool includeAttachments = true,
  }) async {
    final result = <Map<String, dynamic>>[];
    for (final m in messages) {
      if (!includeAttachments || !m.hasAttachments) {
        result.add(m.toApiMap());
        continue;
      }
      final parts = await AttachmentCodec.toOpenAiParts(m.content, m.attachments);
      result.add(m.toApiMap(contentParts: parts));
    }
    return result;
  }

  /// 粗略判断异常是否由「请求体过大」引起（各家网关措辞不一，只能多匹配几种）
  static bool _looksLikePayloadTooLarge(Object e) {
    final msg = e.toString();
    if (msg.contains('(413)')) return true;
    final lower = msg.toLowerCase();
    return lower.contains('request entity too large') ||
        lower.contains('payload too large') ||
        lower.contains('content too large') ||
        lower.contains('exceeds the maximum') ||
        (lower.contains('too large') && lower.contains('request'));
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    const prefix = 'Exception: ';
    return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
  }
}
