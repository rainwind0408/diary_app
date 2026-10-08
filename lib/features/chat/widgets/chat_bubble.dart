import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/chat_message_record.dart';
import '../models/chat_attachment.dart';
import '../models/media_marker.dart';
import 'attachment_view.dart';
import 'message_action_sheet.dart';

/// 消息气泡（QQ 风格）。
///
/// 和上一版（微信风）的区别，都是为了「不那么挤」：
/// - **没有小尾巴**，就是一枚圆角矩形 —— 尾巴既要单独画路径，又要为它在一侧
///   多留 7px 内边距，左右永远不对称；
/// - **没有描边**，边界靠「白气泡 / 暖灰画布」的明度差自然形成。上一版画布
///   `#FFF8F0` 和气泡 `#FFFDF9` 几乎同色，只能到处描边，这才是拥挤的根源；
/// - 头像从圆形改成圆角方形，和气泡的直角语言统一。
///
/// 长按整行触发 [onLongPress]（复制 / 删除 / 重新生成由调用方决定）；
/// [ChatMessageRecord.statusFailed] 时在气泡旁显示红色感叹号，点击走 [onRetry]。
class ChatBubble extends StatelessWidget {
  final ChatMessageRecord message;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;

  /// 点「朗读 / 停止」。[isSpeaking] 为 true 时显示成停止。
  final VoidCallback? onRead;
  final bool isSpeaking;

  /// 是否展示模型的思考过程（对应设置里的「显示思考过程」）。
  /// 关掉时思考内容仍在库里，只是不渲染。
  final bool showReasoning;

  /// 助手回复是否按 Markdown 渲染；关掉退化为纯文本
  final bool renderMarkdown;

  /// 气泡字号倍率（叠加在全局字号之上）
  final double bubbleFontScale;

  const ChatBubble({
    super.key,
    required this.message,
    this.onLongPress,
    this.onRetry,
    this.onRead,
    this.isSpeaking = false,
    this.showReasoning = true,
    this.renderMarkdown = true,
    this.bubbleFontScale = 1.0,
  });

  /// 气泡圆角。QQ 是 8 左右 —— 比微信的 10 更利落，又不至于方正。
  static const double radius = 8;

  /// 气泡内边距。左右对称（没有尾巴要避让了）。
  static const EdgeInsets bubblePadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 9);

  @override
  Widget build(BuildContext context) {
    if (message.isTool) return _ToolBubble(message: message);

    // AI 为了「看见」日记图片而借道注入的一条 user 消息 —— 见
    // [MediaMarker]。用户并没有发过它，所以绝不能长得像用户气泡，
    // 否则历史记录里会出现一句「我什么时候发过这个？」。
    if (message.isUser &&
        message.content.startsWith(MediaMarker.systemPrefix)) {
      return _SystemMediaBubble(message: message);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.isUser;

    final bubbleColor = isUser
        ? (isDark ? AppColors.darkPinkLight : AppColors.chatBubbleUser)
        : AppColors.chatBubbleOf(context);

    final textColor = isUser
        ? (isDark ? AppColors.darkTitleText : AppColors.titleText)
        : (isDark ? AppColors.darkBodyText : AppColors.bodyText);

    final attachments = ChatAttachment.decodeList(message.attachmentsJson);
    final hasText = message.content.trim().isNotEmpty;
    // 带 tool_calls 的助手消息 content 是空的，给个占位避免出现空气泡
    final isToolCallPlaceholder = !hasText &&
        attachments.isEmpty &&
        message.toolCallsJson.trim() != ChatMessageRecord.emptyJsonArray;

    final showReasoningPanel =
        !isUser && message.hasReasoning && showReasoning;

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppColors.chatBubbleShadowOf(context),
        ),
        padding: bubblePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 思考过程属于助手消息，放在回答上方（与 DeepSeek 一致）
            if (showReasoningPanel)
              _ReasoningPanel(reasoning: message.reasoning),
            if (showReasoningPanel && (attachments.isNotEmpty || hasText))
              const SizedBox(height: 8),
            if (attachments.isNotEmpty)
              AttachmentView(
                attachments: attachments,
                isUser: isUser,
                // 助手消息上的图片目前只有 AI 生图的结果 —— 那是这条回复的
                // 主角，缩略图给大一点；用户自己发的图保持小尺寸不占地方。
                thumbSize: isUser
                    ? AttachmentView.defaultThumb
                    : AttachmentView.largeThumb,
              ),
            if (attachments.isNotEmpty && hasText) const SizedBox(height: 8),
            if (hasText)
              isUser
                  ? Text(
                      message.content,
                      style: _scaled(AppTextStyles.body)
                          .copyWith(color: textColor),
                    )
                  : (renderMarkdown
                      ? MarkdownBody(
                          data: message.content,
                          selectable: false,
                          styleSheet: _markdownStyle(isDark),
                        )
                      : Text(
                          message.content,
                          style: _scaled(AppTextStyles.body)
                              .copyWith(color: textColor),
                        )),
            if (isToolCallPlaceholder)
              Text(
                '正在调用工具…',
                style: AppTextStyles.label.copyWith(
                  color:
                      isDark ? AppColors.darkSubtleText : AppColors.subtleText,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );

    final avatar = ChatAvatar(isUser: isUser, isDark: isDark);
    final statusBadge = _StatusBadge(
      status: message.status,
      isUser: isUser,
      onRetry: onRetry,
    );

    // 助手消息下方挂一条操作条。只给有正文的助手消息 —— 生图那种「只有图」
    // 的回复没什么可念的，多一行按钮只是噪音。
    final showActions = !isUser && hasText;
    final block = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        bubble,
        if (showActions) _AssistantActions(
          isDark: isDark,
          isSpeaking: isSpeaking,
          onRead: onRead,
          onCopy: () => copyMessageText(context, message.content),
        ),
      ],
    );

    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // QQ 的呼吸感来自这里：消息之间留得比气泡内边距还大一点
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        child: Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: isUser
              ? [statusBadge, block, const SizedBox(width: 9), avatar]
              : [avatar, const SizedBox(width: 9), block, statusBadge],
        ),
      ),
    );
  }

  /// 按 [bubbleFontScale] 放大字号（1.0 时原样返回，省一次 copyWith）
  TextStyle _scaled(TextStyle base) {
    final size = base.fontSize;
    if (bubbleFontScale == 1.0 || size == null) return base;
    return base.copyWith(fontSize: size * bubbleFontScale);
  }

  MarkdownStyleSheet _markdownStyle(bool isDark) {
    return MarkdownStyleSheet(
      // 收紧段间距：Markdown 默认的段间留白叠在气泡内边距上会显得很空
      p: _scaled(AppTextStyles.body).copyWith(
        color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
        height: 1.6,
      ),
      pPadding: const EdgeInsets.only(bottom: 2),
      code: _scaled(AppTextStyles.label).copyWith(
        backgroundColor:
            isDark ? AppColors.darkPageBackground : AppColors.chatCanvas,
        color: isDark ? AppColors.darkPink : AppColors.pinkDark,
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark ? AppColors.darkPageBackground : AppColors.chatCanvas,
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(10),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? AppColors.darkPink : AppColors.pink,
            width: 3,
          ),
        ),
      ),
      h1: AppTextStyles.heading.copyWith(
        color: isDark ? AppColors.darkTitleText : AppColors.titleText,
        fontSize: 20 * bubbleFontScale,
      ),
      h2: AppTextStyles.heading.copyWith(
        color: isDark ? AppColors.darkTitleText : AppColors.titleText,
        fontSize: 18 * bubbleFontScale,
      ),
      h3: AppTextStyles.heading.copyWith(
        color: isDark ? AppColors.darkTitleText : AppColors.titleText,
        fontSize: 16 * bubbleFontScale,
      ),
      listBullet: _scaled(AppTextStyles.body).copyWith(
        color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
      ),
      a: _scaled(AppTextStyles.body).copyWith(
        color: isDark ? AppColors.darkPink : AppColors.pinkDark,
        decoration: TextDecoration.underline,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine,
          ),
        ),
      ),
    );
  }
}

/// 头像：圆角方形（QQ 风），不是圆形。
///
/// 圆形头像在密集消息列表里会形成一串「点」，和方形的气泡语言打架；
/// 圆角方形和气泡的圆角呼应，整体更整。
///
/// 图标颜色一律取深色。早先是「白图标压在浅粉/浅紫上」——#FFFFFF 对
/// pinkLight 只有约 1.6:1，助手那枚更用了 purpleLight 画在 purple 上，
/// 等于一个看不见的空方块。底色都是中高明度的粉 / 紫，深色图标才读得出来。
class ChatAvatar extends StatelessWidget {
  final bool isUser;
  final bool isDark;

  static const double size = 38;
  static const double _radius = 6;

  const ChatAvatar({super.key, required this.isUser, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // 我方底色用 pinkDark 而不是气泡色：和气泡同色会被看成气泡上长出的一个把手
    final bg = isUser
        ? (isDark ? AppColors.darkPink : AppColors.pinkDark)
        : (isDark ? AppColors.darkPurple : AppColors.purple);
    final fg = isDark ? AppColors.darkPageBackground : AppColors.titleText;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_radius),
      ),
      alignment: Alignment.center,
      child: Icon(
        isUser ? Icons.person : Icons.auto_awesome,
        size: 20,
        color: fg,
      ),
    );
  }
}

/// 气泡旁的状态角标：发送中转圈 / 发送失败可重试
class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isUser;
  final VoidCallback? onRetry;

  const _StatusBadge({
    required this.status,
    required this.isUser,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (status == ChatMessageRecord.statusSending) {
      return Padding(
        padding: EdgeInsets.only(
          left: isUser ? 0 : 6,
          right: isUser ? 6 : 0,
          top: 10,
        ),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
          ),
        ),
      );
    }

    if (status == ChatMessageRecord.statusFailed && isUser) {
      return Padding(
        padding: const EdgeInsets.only(right: 6, top: 8),
        child: InkWell(
          onTap: onRetry,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(
              Icons.error,
              size: 18,
              color: AppColors.deleteRed,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// 「AI 翻出了日记里的图片」这条系统注入消息的气泡。
///
/// 它是一条 `role=user` 的消息（协议要求图片只能出现在 user 消息里），
/// 但**不是用户发的**。所以刻意不用粉色用户气泡、不带头像，
/// 改成居中的淡底卡片 + 一行灰字说明，读起来像一条系统提示。
class _SystemMediaBubble extends StatelessWidget {
  final ChatMessageRecord message;

  const _SystemMediaBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtle = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final attachments = ChatAttachment.decodeList(message.attachmentsJson);
    final text = message.content.startsWith(MediaMarker.systemPrefix)
        ? message.content.substring(MediaMarker.systemPrefix.length)
        : message.content;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachments.isNotEmpty)
            // 用 isUser: false —— 它决定的是圆角/尺寸那套内嵌片的样式，
            // 与「谁发的」无关
            AttachmentView(
              attachments: attachments,
              isUser: false,
              thumbSize: AttachmentView.largeThumb,
            ),
          if (text.isNotEmpty) ...[
            if (attachments.isNotEmpty) const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, size: 12, color: subtle),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.pageNumber.copyWith(
                      color: subtle,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 工具调用气泡。
///
/// 刻意**不做成**一枚正式气泡：它既不是用户说的，也不是 AI 说的，而是中间过程。
/// 用一层极淡的底 + 灰字把它压到背景里，不再描紫边（那是上一版最吵的框之一）。
class _ToolBubble extends StatefulWidget {
  final ChatMessageRecord message;

  const _ToolBubble({required this.message});

  @override
  State<_ToolBubble> createState() => _ToolBubbleState();
}

class _ToolBubbleState extends State<_ToolBubble> {
  bool _expanded = false;

  /// 工具产出物（目前只有 AI 生图的结果会挂上来）
  List<ChatAttachment> _attachments = const [];

  @override
  void initState() {
    super.initState();
    _syncAttachments();
  }

  @override
  void didUpdateWidget(_ToolBubble old) {
    super.didUpdateWidget(old);
    if (old.message.attachmentsJson != widget.message.attachmentsJson) {
      _syncAttachments();
    }
  }

  void _syncAttachments() {
    _attachments = ChatAttachment.decodeList(widget.message.attachmentsJson);
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtle = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final hasImage = _attachments.isNotEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(left: 61, right: 52, top: 3, bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: subtle.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(ChatBubble.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 只有标题栏负责折叠 —— 图片自带「点击看大图」，外层再套一层
            // 点击手势两者会打架（谁赢取决于手势竞技场，不该赌）。
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasImage ? Icons.palette_outlined : Icons.build_outlined,
                    size: 13,
                    color: subtle,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _title(hasImage),
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: subtle,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 14,
                    color: subtle,
                  ),
                ],
              ),
            ),
            if (hasImage) ...[
              const SizedBox(height: 8),
              AttachmentView(
                attachments: _attachments,
                thumbSize: AttachmentView.largeThumb,
              ),
            ],
            if (_expanded) ...[
              const SizedBox(height: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.chatBubbleOf(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    widget.message.content,
                    style: AppTextStyles.label.copyWith(
                      color:
                          isDark ? AppColors.darkBodyText : AppColors.bodyText,
                      fontSize: 11,
                      height: 1.5,
                    ),
                    maxLines: 24,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 生图成功的工具气泡不用再报工具名 —— 用户关心的是图，不是 `generate_image`
  String _title(bool hasImage) {
    if (hasImage) return 'AI 生成的图片';
    final name =
        widget.message.toolName.isEmpty ? '未知' : widget.message.toolName;
    return '已调用工具 · $name';
  }
}

/// 助手消息的「思考过程」面板 —— 对齐 DeepSeek 网页版。
///
/// 三条关键差异（相对上一版）：
/// 1. **默认收起**，只留一行「已思考 ⌄」；
/// 2. **没有边框也没有底色**，靠左侧一条竖线 + 灰色小字表达「这是附注」；
/// 3. 正文按空行拆成**分步圆点**，而不是一整块灰底文字。
///
/// 它仍然长在**同一个气泡里**（回答的上方），不是独立的一块。
class _ReasoningPanel extends StatefulWidget {
  final String reasoning;

  const _ReasoningPanel({required this.reasoning});

  @override
  State<_ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<_ReasoningPanel> {
  /// 展开时的最大高度，超出部分内部滚动
  static const double _maxBodyHeight = 220;

  /// 超过这个字数才做内部滚动。
  ///
  /// 不无条件套 SingleChildScrollView 的原因：它**即使没有可滚内容也会吃掉
  /// 竖直拖拽**，导致手指按在气泡上时外层消息列表滚不动。
  static const int _scrollThreshold = 400;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtle = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '已思考',
                  style: AppTextStyles.label.copyWith(
                    color: subtle,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: subtle,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) _body(subtle),
      ],
    );
  }

  /// 正文：左侧一条竖线 + 分步圆点，短文本直接铺开、长文本限高滚动
  Widget _body(Color subtle) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final step in _splitSteps(widget.reasoning)) _step(step, subtle),
      ],
    );

    final lined = Container(
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: subtle.withValues(alpha: 0.30), width: 1.5),
        ),
      ),
      child: content,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: widget.reasoning.length <= _scrollThreshold
          ? lined
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _maxBodyHeight),
              child: SingleChildScrollView(child: lined),
            ),
    );
  }

  Widget _step(String text, Color subtle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 圆点用固定上边距对齐首行，不靠试数
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: subtle.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              text,
              style: AppTextStyles.label.copyWith(
                color: subtle,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 把思考过程拆成「步骤」。
  ///
  /// 模型大多用空行分段；但也有把每步写成单独一行的（只用一个 `\n`）。
  /// 先按空行拆，拆不出多段再退回按单换行拆 —— 只有一段时就保持一段，
  /// 不为了凑圆点硬切句子。
  static List<String> _splitSteps(String raw) {
    List<String> split(String pattern) => raw
        .split(RegExp(pattern))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    var parts = split(r'\n\s*\n');
    if (parts.length <= 1) parts = split(r'\n');
    return parts.isEmpty ? <String>[raw.trim()] : parts;
  }
}

/// 助手气泡下方的操作条：朗读 / 复制。
///
/// 刻意做得很轻（小图标 + 小字、低对比色）—— 它是「需要时才找得到」的功能，
/// 不该和正文抢注意力。
class _AssistantActions extends StatelessWidget {
  final bool isDark;
  final bool isSpeaking;
  final VoidCallback? onRead;
  final VoidCallback? onCopy;

  const _AssistantActions({
    required this.isDark,
    required this.isSpeaking,
    this.onRead,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final subtle = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final accent = isDark ? AppColors.darkPink : AppColors.pinkDark;

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onRead != null)
            _ActionButton(
              icon: isSpeaking
                  ? Icons.stop_circle_outlined
                  : Icons.volume_up_outlined,
              label: isSpeaking ? '停止' : '朗读',
              color: isSpeaking ? accent : subtle,
              onTap: onRead!,
            ),
          if (onRead != null && onCopy != null) const SizedBox(width: 16),
          if (onCopy != null)
            _ActionButton(
              icon: Icons.copy_rounded,
              label: '复制',
              color: subtle,
              onTap: onCopy!,
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: AppTextStyles.pageNumber.copyWith(
                color: color,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
