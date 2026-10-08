import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/chat_message_record.dart';
import '../models/streaming_draft.dart';
import 'chat_bubble.dart';
import 'thinking_dots.dart';

/// 流式回答的草稿气泡。
///
/// 只订阅 [draft] 这一个 ValueNotifier —— 逐 token 的重建被限制在这一个
/// 气泡内部，不会波及整个消息列表（见 `ChatProvider` 的刷新纪律）。
///
/// 草稿为空时显示「正在思考」三点；有内容后直接复用 [ChatBubble]，
/// 于是思考面板、Markdown 渲染、附件排版全都白拿，不必再写一套。
class StreamingDraftBubble extends StatelessWidget {
  final ValueNotifier<StreamingDraft> draft;

  /// 是否展示思考过程（透传给 [ChatBubble]）
  final bool showReasoning;

  /// 是否按 Markdown 渲染（透传给 [ChatBubble]）
  final bool renderMarkdown;

  /// 气泡字号倍率（透传给 [ChatBubble]）
  final double bubbleFontScale;

  const StreamingDraftBubble({
    super.key,
    required this.draft,
    this.showReasoning = true,
    this.renderMarkdown = true,
    this.bubbleFontScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StreamingDraft>(
      valueListenable: draft,
      builder: (context, value, _) {
        // 关掉思考展示时，只有思考内容的草稿对用户来说等于「还在想」——
        // 否则会渲染出一个空气泡
        final visible = value.content.isNotEmpty ||
            (showReasoning && value.reasoning.isNotEmpty);
        if (!visible) return const _ThinkingBubble();

        return ChatBubble(
          message: ChatMessageRecord(
            // 草稿不落库，sessionId / id 都只是占位
            sessionId: 0,
            role: ChatMessageRecord.roleAssistant,
            content: value.content,
            reasoning: value.reasoning,
          ),
          showReasoning: showReasoning,
          renderMarkdown: renderMarkdown,
          bubbleFontScale: bubbleFontScale,
        );
      },
    );
  }
}

/// 「正在思考」气泡。
///
/// 头像、左对齐、外边距都与正式助手气泡一致 —— 否则从「思考中」切到
/// 第一段文字时整块会跳一下。
class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatAvatar(isUser: false, isDark: isDark),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.chatBubbleOf(context),
              borderRadius: BorderRadius.circular(ChatBubble.radius),
              boxShadow: AppColors.chatBubbleShadowOf(context),
            ),
            child: ThinkingDots(
              color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
            ),
          ),
        ],
      ),
    );
  }
}
