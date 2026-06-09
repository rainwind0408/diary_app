import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ChatProvider>();

    // Scroll to bottom when messages change
    if (provider.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI 助手',
          style: AppTextStyles.heading.copyWith(
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
          ),
        ),
        actions: [
          if (provider.messages.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
              ),
              onPressed: () => _confirmClear(context, provider),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: provider.messages.isEmpty
                ? _EmptyState(isDark: isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: provider.messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: provider.messages[index]);
                    },
                  ),
          ),
          if (provider.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.toastWarning.withValues(alpha: 0.1),
              child: Text(
                provider.error!,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.toastWarning,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ChatInput(
            onSend: (text) => provider.sendMessage(text),
            isLoading: provider.isLoading,
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, ChatProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        title: Text(
          '清空对话',
          style: AppTextStyles.heading.copyWith(
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
          ),
        ),
        content: Text(
          '确定要清空所有对话记录吗？',
          style: AppTextStyles.body.copyWith(
            color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(
                color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              provider.clearMessages();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? AppColors.darkPink : AppColors.pink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 64,
            color: (isDark ? AppColors.darkPink : AppColors.pink).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '和 AI 聊聊你的日记吧',
            style: AppTextStyles.heading.copyWith(
              color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
            ),
          ),
          const SizedBox(height: 8),
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
    );
  }
}
