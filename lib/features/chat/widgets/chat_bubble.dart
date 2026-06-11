import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUser = message.role == 'user';
    final isTool = message.role == 'tool';

    if (isTool) return _ToolBubble(message: message, isDark: isDark);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: EdgeInsets.only(
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? (isDark ? AppColors.darkPink : AppColors.pinkLight)
              : (isDark ? AppColors.darkCardBackground : AppColors.cardBackground),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : AppColors.subtleText).withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: isUser
            ? SelectableText(
                message.content,
                style: AppTextStyles.body.copyWith(
                  color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                ),
              )
            : MarkdownBody(
                data: message.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: AppTextStyles.body.copyWith(
                    color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                  ),
                  code: AppTextStyles.label.copyWith(
                    backgroundColor: isDark
                        ? AppColors.darkPageBackground
                        : AppColors.pageBackground,
                    color: isDark ? AppColors.darkPink : AppColors.pinkDark,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkPageBackground
                        : AppColors.pageBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  ),
                  h2: AppTextStyles.heading.copyWith(
                    color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                    fontSize: 16,
                  ),
                  listBullet: AppTextStyles.body.copyWith(
                    color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ToolBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isDark;

  const _ToolBubble({required this.message, required this.isDark});

  @override
  State<_ToolBubble> createState() => _ToolBubbleState();
}

class _ToolBubbleState extends State<_ToolBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: const EdgeInsets.only(right: 48, top: 4, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkPageBackground
                : AppColors.pageBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? AppColors.darkPurple.withValues(alpha: 0.3)
                  : AppColors.purple.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.build_outlined,
                    size: 14,
                    color: isDark ? AppColors.darkPurple : AppColors.purple,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '工具: ${widget.message.toolName ?? "未知"}',
                    style: AppTextStyles.label.copyWith(
                      color: isDark ? AppColors.darkPurple : AppColors.purple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 14,
                    color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCardBackground
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _formatJson(widget.message.content),
                    style: AppTextStyles.label.copyWith(
                      color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                      fontSize: 11,
                    ),
                    maxLines: 20,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatJson(String text) {
    try {
      final obj = _parseJson(text);
      return _prettyPrint(obj, 0);
    } catch (_) {
      return text;
    }
  }

  dynamic _parseJson(String str) {
    // Simple approach: just return the string as-is for display
    return str;
  }

  String _prettyPrint(dynamic obj, int indent) {
    if (obj is String) return obj;
    return obj.toString();
  }
}
