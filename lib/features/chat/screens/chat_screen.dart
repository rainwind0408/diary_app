import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/chat_message_record.dart';
import '../../assistant/services/orb_visibility.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_session_provider.dart';
import '../services/ai_config_store.dart';
import '../services/tts_player.dart';
import '../utils/chat_time_format.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/chat_time_divider.dart';
import '../widgets/image_prompt_sheet.dart';
import '../widgets/message_action_sheet.dart';
import '../widgets/session_drawer.dart';
import '../widgets/streaming_draft_bubble.dart';
import 'ai_assistant_settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _lastMessageCount = 0;
  int? _lastSessionId;

  /// 用于订阅流式草稿的增长（跟着往下滚）
  ChatProvider? _chat;

  // ── 以下四项来自设置页的「显示」分组 ──
  // 设置页用本地 setState，不会通知到这里，所以从设置页返回时要主动同步一次。

  /// 「显示思考过程」
  bool _showReasoning = true;

  /// 相邻消息间隔 >5 分钟时是否显示居中时间
  bool _showTimestamp = true;

  /// 助手回复是否按 Markdown 渲染
  bool _renderMarkdown = true;

  /// 气泡正文的字号倍率
  double _bubbleFontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _syncDisplayPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatSessionProvider>().loadSessions();
    });
  }

  /// 从配置同步「显示」分组。
  ///
  /// 四个值一起读、一起比 —— 分开写四次 setState 只会让返回设置页时多重建几次。
  Future<void> _syncDisplayPrefs() async {
    final config = await AiConfigStore.load();
    if (!mounted) return;
    if (config.showReasoning == _showReasoning &&
        config.showTimestamp == _showTimestamp &&
        config.renderMarkdown == _renderMarkdown &&
        config.bubbleFontScale == _bubbleFontScale) {
      return;
    }
    setState(() {
      _showReasoning = config.showReasoning;
      _showTimestamp = config.showTimestamp;
      _renderMarkdown = config.renderMarkdown;
      _bubbleFontScale = config.bubbleFontScale;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chat = context.read<ChatProvider>();
    if (identical(_chat, chat)) return;
    _chat?.draft.removeListener(_onDraftChanged);
    _chat = chat;
    chat.draft.addListener(_onDraftChanged);
  }

  @override
  void dispose() {
    _chat?.draft.removeListener(_onDraftChanged);
    _scrollController.dispose();
    super.dispose();
  }

  /// 草稿变长时跟着往下滚。
  ///
  /// 只在用户**本来就贴着底部**时才滚 —— 否则会把他往上翻看历史的手给拽回来。
  /// 用 `jumpTo` 而不是动画：流式期间每 50ms 触发一次，反复重启动画反而更抖。
  void _onDraftChanged() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels > 120) return;
    _scrollToBottom(animate: false);
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chat = context.watch<ChatProvider>();
    final session = context.watch<ChatSessionProvider>();
    final messages = session.messages;

    // 正在生成的请求是不是属于**当前这个会话**。
    //
    // 不能直接用 `chat.isLoading`：它只表示「有没有请求在跑」，不区分会话。
    // 在会话 A 生成的过程中切到会话 B，A 的半截回复会作为草稿气泡画在 B 里，
    // 看起来就像「上一个会话的回复跑进新会话了」。
    final generatingHere = chat.isGeneratingFor(session.currentSessionId);

    // 切换会话时直接跳到底；同一会话内新增消息则平滑滚动
    final currentId = session.currentSessionId;
    if (currentId != _lastSessionId) {
      _lastSessionId = currentId;
      _lastMessageCount = messages.length;
      _scrollToBottom(animate: false);
    } else if (messages.length != _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom(animate: messages.isNotEmpty);
    }

    return Scaffold(
      key: _scaffoldKey,
      // 聊天页用自己的暖灰画布，而不是全局的米白 pageBackground ——
      // 只有和「白气泡」拉开明度差，气泡才不需要描边（见 AppColors.chatCanvas）。
      backgroundColor: AppColors.chatCanvasOf(context),
      drawer: const SessionDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.chatCanvasOf(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkTitleText : AppColors.titleText,
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  session.currentSession?.title ?? 'AI 助手',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading.copyWith(
                    color:
                        isDark ? AppColors.darkTitleText : AppColors.titleText,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: '会话列表',
            icon: Icon(
              Icons.forum_outlined,
              color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          IconButton(
            tooltip: 'AI 助手设置',
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  // 必须显式命名：悬浮球靠它判断「现在是不是设置类页面」
                  settings: const RouteSettings(name: OrbRoutes.aiSettings),
                  builder: (_) => const AiAssistantSettingsScreen(),
                ),
              );
              await _syncDisplayPrefs();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: session.isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : (messages.isEmpty && !generatingHere)
                    ? _EmptyState(isDark: isDark)
                    : _buildList(isDark, messages, chat, generatingHere),
          ),
          if (chat.error != null) _errorBanner(isDark, chat),
          ChatInput(
            onSend: (text, attachments) => chat.sendMessage(
              text,
              session: context.read<ChatSessionProvider>(),
              attachments: attachments,
            ),
            // 只反映**当前会话**是否在生成。别的会话在跑时这里要保持「可发送」，
            // 否则用户在新会话里既看不到草稿、又发不出消息，会以为卡死了。
            isLoading: generatingHere,
            onStop: chat.stopStreaming,
            onGenerateImage: () => _startImageGen(chat),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    bool isDark,
    List<ChatMessageRecord> messages,
    ChatProvider chat,
    bool showDraft,
  ) {
    // 回复期间在末尾追加一行草稿（含「正在思考」态），让用户立刻看到反馈。
    // 草稿自己订阅 draft，所以逐 token 的刷新不会重建整个列表。
    //
    // showDraft 由调用方**按会话**判定（见 build 里的 generatingHere），
    // 不能直接写 `chat.isLoading` —— 那会把别的会话的草稿画到这个列表里。
    final itemCount = messages.length + (showDraft ? 1 : 0);

    // 「正在朗读哪条」是全局单例状态，只有它变时才重建这个列表 ——
    // 比让它跟着 ChatProvider 的每次 notifyListeners 一起刷便宜得多。
    return ValueListenableBuilder<int?>(
      valueListenable: TtsPlayer.speakingId,
      builder: (context, speakingId, _) => ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 6, bottom: 12),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= messages.length) {
            return StreamingDraftBubble(
              draft: chat.draft,
              showReasoning: _showReasoning,
              renderMarkdown: _renderMarkdown,
              bubbleFontScale: _bubbleFontScale,
            );
          }

          final message = messages[index];
          final previous = index == 0 ? null : messages[index - 1].createdAt;
          final showTime = _showTimestamp &&
              ChatTimeFormat.shouldShow(previous, message.createdAt);
          final isLast = index == messages.length - 1;
          final canRead = !message.isUser && message.content.trim().isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTime) ChatTimeDivider(time: message.createdAt),
              ChatBubble(
                message: message,
                showReasoning: _showReasoning,
                renderMarkdown: _renderMarkdown,
                bubbleFontScale: _bubbleFontScale,
                isSpeaking: canRead && speakingId != null &&
                    speakingId == message.id,
                onRead: canRead ? () => _toggleRead(message) : null,
                onRetry: message.isUser
                    ? () => chat.retry(
                          session: context.read<ChatSessionProvider>(),
                          messageId: message.id!,
                        )
                    : null,
                onLongPress: () => _onLongPress(
                  isDark,
                  chat,
                  message,
                  isLastAssistant: isLast && !message.isUser && !message.isTool,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 朗读 / 停止朗读一条助手消息。
  ///
  /// 再点一次就是「停止」—— 这是最自然的切换方式，比让用户去别处找停止按钮好。
  Future<void> _toggleRead(ChatMessageRecord message) async {
    final id = message.id;
    if (id == null) return;

    if (TtsPlayer.speakingId.value == id) {
      await TtsPlayer.stop();
      return;
    }

    await TtsPlayer.speak(messageId: id, markdown: message.content);
    if (!mounted) return;
    final err = TtsPlayer.lastError;
    if (err == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(err)));
  }

  /// 「AI 画图」入口：先确认配置，再让用户写描述，最后交给 [ChatProvider]。
  ///
  /// 配置检查放在弹输入框**之前** —— 让用户写完一整段描述才告诉他「你没配 API
  /// Key」，是最容易劝退人的做法。
  Future<void> _startImageGen(ChatProvider chat) async {
    final blocked = await chat.imageGenBlockReason();
    if (!mounted) return;
    if (blocked != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(blocked)));
      return;
    }

    final request = await showImagePromptSheet(context);
    if (request == null || !mounted) return;
    await chat.generateImage(
      request.prompt,
      session: context.read<ChatSessionProvider>(),
      referenceImagePath: request.referencePath,
    );
  }

  Widget _errorBanner(bool isDark, ChatProvider chat) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      color: AppColors.toastWarning.withValues(alpha: 0.12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chat.error!,
              style: AppTextStyles.label.copyWith(
                color: AppColors.toastWarning,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.toastWarning,
            onPressed: chat.clearError,
          ),
        ],
      ),
    );
  }

  Future<void> _onLongPress(
    bool isDark,
    ChatProvider chat,
    ChatMessageRecord message, {
    required bool isLastAssistant,
  }) async {
    if (message.isTool) return;

    final canRead = !message.isUser && message.content.trim().isNotEmpty;
    final action = await showMessageActionSheet(
      context,
      isUser: message.isUser,
      isFailed: message.status == ChatMessageRecord.statusFailed,
      isLastAssistant: isLastAssistant,
      canRead: canRead,
      isSpeaking: canRead && TtsPlayer.speakingId.value == message.id,
    );
    if (action == null || !mounted) return;

    final session = context.read<ChatSessionProvider>();

    switch (action) {
      case MessageAction.copy:
        await copyMessageText(context, message.content);
      case MessageAction.read:
        await _toggleRead(message);
      case MessageAction.retry:
        await chat.retry(session: session, messageId: message.id!);
      case MessageAction.regenerate:
        final lastUser = session.lastUserMessage;
        if (lastUser?.id == null) return;
        await session.deleteMessagesAfter(lastUser!.id!);
        await chat.retry(session: session, messageId: lastUser.id!);
      case MessageAction.delete:
        await session.deleteMessage(message.id!);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 64,
              color: (isDark ? AppColors.darkPink : AppColors.pink)
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '和 AI 聊聊你的日记吧',
              style: AppTextStyles.heading.copyWith(
                color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '试试问：\n"我写了多少篇日记？"\n"最近心情怎么样？"\n"帮我回忆一下上周的事"',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: (isDark ? AppColors.darkSubtleText : AppColors.subtleText)
                    .withValues(alpha: 0.7),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
