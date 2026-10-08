import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/chat_session.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_session_provider.dart';
import '../services/chat_export_service.dart';
import '../utils/chat_time_format.dart';
import 'chat_export_sheet.dart';

/// 会话列表抽屉：新建 / 切换 / 重命名 / 置顶 / 删除 / 清空。
class SessionDrawer extends StatelessWidget {
  const SessionDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ChatSessionProvider>();
    final sessions = provider.sessions;

    return Drawer(
      backgroundColor:
          isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
      child: SafeArea(
        child: Column(
          children: [
            _header(context, isDark, provider),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine,
            ),
            Expanded(
              child: sessions.isEmpty
                  ? _empty(isDark)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark
                            ? AppColors.darkDividerLine
                            : AppColors.dividerLine,
                      ),
                      itemBuilder: (_, i) {
                        final s = sessions[i];
                        return _sessionTile(
                          context,
                          isDark,
                          provider,
                          s,
                          s.id == provider.currentSessionId,
                        );
                      },
                    ),
            ),
            if (sessions.isNotEmpty) ...[
              Divider(
                height: 1,
                color:
                    isDark ? AppColors.darkDividerLine : AppColors.dividerLine,
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined,
                    color: AppColors.deleteRed, size: 20),
                title: Text(
                  '清空全部会话',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.deleteRed),
                ),
                onTap: () => _confirmClearAll(context, isDark, provider),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    bool isDark,
    ChatSessionProvider provider,
  ) {
    final accent = isDark ? AppColors.darkPink : AppColors.pinkDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Icon(Icons.forum_outlined, color: accent, size: 20),
          const SizedBox(width: 8),
          Text(
            '会话',
            style: AppTextStyles.heading.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
              fontSize: 20,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () async {
              _endGeneration(context);
              await provider.createSession();
              if (context.mounted) Navigator.pop(context);
            },
            icon: Icon(Icons.add_rounded, size: 18, color: accent),
            label: Text(
              '新建',
              style: AppTextStyles.label.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }

  /// 切走会话之前，先把正在生成的回复就地收尾。
  ///
  /// 为什么必须收尾：
  /// - 不收尾的话它会继续跑在**原会话**上，用户在新会话里会看到「上一个会话
  ///   的回复」的草稿气泡（即使界面已按会话过滤，输入框也会被 `_isLoading`
  ///   挡住发不出消息）；
  /// - 收尾走的是 `stopStreaming()`，**不是丢弃** —— 已经流出来的半截回答会
  ///   由 `ChatProvider._runLoop` 落库回原会话，切回去还能看到。
  void _endGeneration(BuildContext context) {
    context.read<ChatProvider>().stopStreaming();
  }

  Widget _empty(bool isDark) {
    return Center(
      child: Text(
        '还没有会话',
        style: AppTextStyles.body.copyWith(
          color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
        ),
      ),
    );
  }

  Widget _sessionTile(
    BuildContext context,
    bool isDark,
    ChatSessionProvider provider,
    ChatSession session,
    bool isActive,
  ) {
    final accent = isDark ? AppColors.darkPink : AppColors.pinkDark;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Container(
      color: isActive ? accent.withValues(alpha: 0.10) : Colors.transparent,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        title: Row(
          children: [
            if (session.isPinned) ...[
              Icon(Icons.push_pin, size: 13, color: accent),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: isActive ? accent : titleColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            session.lastMessage.isEmpty
                ? '${session.messageCount} 条消息'
                : '${session.lastMessage} · ${ChatTimeFormat.format(session.updatedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.pageNumber.copyWith(color: subColor),
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: subColor),
          color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
          onSelected: (value) async {
            switch (value) {
              case 'rename':
                await _rename(context, isDark, provider, session);
              case 'pin':
                await provider.togglePin(session.id!);
              case 'export':
                await _export(context, provider, session);
              case 'delete':
                await _confirmDelete(context, isDark, provider, session);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'rename', child: Text('重命名')),
            PopupMenuItem(
              value: 'pin',
              child: Text(session.isPinned ? '取消置顶' : '置顶'),
            ),
            const PopupMenuItem(value: 'export', child: Text('导出')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('删除', style: TextStyle(color: AppColors.deleteRed)),
            ),
          ],
        ),
        onTap: () async {
          _endGeneration(context);
          if (session.id != null) {
            await provider.switchSession(session.id!);
          }
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    bool isDark,
    ChatSessionProvider provider,
    ChatSession session,
  ) async {
    final controller = TextEditingController(text: session.title);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        title: Text(
          '重命名会话',
          style: AppTextStyles.heading.copyWith(
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          style: AppTextStyles.body.copyWith(
            color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
          ),
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              '取消',
              style: TextStyle(
                color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
              ),
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && session.id != null) {
      await provider.renameSession(session.id!, result);
    }
  }

  /// 导出这段会话。**不会**把它切成当前会话 —— 用户只想导个文件。
  Future<void> _export(
    BuildContext context,
    ChatSessionProvider provider,
    ChatSession session,
  ) async {
    final id = session.id;
    if (id == null) return;

    final messages = await provider.messagesOf(id);
    if (!context.mounted) return;
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('这段会话还没有内容可导出')));
      return;
    }

    final format = await showChatExportSheet(context);
    if (format == null || !context.mounted) return;

    try {
      await ChatExportService.exportAndShare(
        title: session.title,
        messages: messages,
        format: format,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    bool isDark,
    ChatSessionProvider provider,
    ChatSession session,
  ) async {
    final ok = await _confirm(
      context,
      isDark,
      title: '删除会话',
      message: '「${session.title}」及其全部消息将被删除，确定吗？',
      confirmText: '删除',
      danger: true,
    );
    if (ok && session.id != null) {
      await provider.deleteSession(session.id!);
    }
  }

  Future<void> _confirmClearAll(
    BuildContext context,
    bool isDark,
    ChatSessionProvider provider,
  ) async {
    final ok = await _confirm(
      context,
      isDark,
      title: '清空全部会话',
      message: '所有会话与消息都会被删除，此操作不可恢复。确定吗？',
      confirmText: '清空',
      danger: true,
    );
    if (ok) {
      await provider.clearAllSessions();
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    bool isDark, {
    required String title,
    required String message,
    required String confirmText,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        title: Text(
          title,
          style: AppTextStyles.heading.copyWith(
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: AppTextStyles.body.copyWith(
            color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              '取消',
              style: TextStyle(
                color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  danger ? AppColors.deleteRed : AppColors.buttonPrimary,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
