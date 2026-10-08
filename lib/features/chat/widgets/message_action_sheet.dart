import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// 一条消息上可执行的操作。
enum MessageAction { copy, retry, regenerate, read, delete }

/// 长按消息后弹出的操作菜单（微信式底部弹窗）。
///
/// 返回用户选择的动作；点空白处关闭返回 null。
///
/// [canRead] 为 true 时才出现「朗读」—— 只有助手消息、且正文非空才可念。
/// [isSpeaking] 为 true 时把它显示成「停止朗读」。
Future<MessageAction?> showMessageActionSheet(
  BuildContext context, {
  required bool isUser,
  bool isFailed = false,
  bool isLastAssistant = false,
  bool canRead = false,
  bool isSpeaking = false,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
  final accent = isDark ? AppColors.darkPink : AppColors.pinkDark;

  return showModalBottomSheet<MessageAction>(
    context: context,
    backgroundColor:
        isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      Widget item(
        MessageAction action,
        IconData icon,
        String label, {
        Color? color,
      }) {
        return ListTile(
          leading: Icon(icon, size: 20, color: color ?? textColor),
          title: Text(
            label,
            style: AppTextStyles.body.copyWith(color: color ?? textColor),
          ),
          onTap: () => Navigator.pop(sheetContext, action),
        );
      }

      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color:
                    (isDark ? AppColors.darkSubtleText : AppColors.subtleText)
                        .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            item(MessageAction.copy, Icons.copy_rounded, '复制'),
            if (canRead && !isUser)
              item(
                MessageAction.read,
                isSpeaking
                    ? Icons.stop_circle_outlined
                    : Icons.volume_up_outlined,
                isSpeaking ? '停止朗读' : '朗读',
                color: accent,
              ),
            if (isFailed && isUser)
              item(MessageAction.retry, Icons.refresh_rounded, '重新发送',
                  color: accent),
            if (isLastAssistant && !isUser)
              item(MessageAction.regenerate, Icons.autorenew_rounded, '重新生成',
                  color: accent),
            item(MessageAction.delete, Icons.delete_outline_rounded, '删除',
                color: AppColors.deleteRed),
            const SizedBox(height: 6),
          ],
        ),
      );
    },
  );
}

/// 复制文本并给出轻提示
Future<void> copyMessageText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('已复制'),
      duration: Duration(milliseconds: 1200),
    ),
  );
}
