import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/widgets/api_config_dialog.dart';
import '../../chat/services/llm_service.dart';

class AiSettingsSection extends StatelessWidget {
  const AiSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.chat_bubble_outline, color: goldColor),
          title: Text(
            'AI 聊天',
            style: AppTextStyles.body.copyWith(color: textColor),
          ),
          subtitle: Text(
            '与 AI 助手对话，探索你的日记',
            style: AppTextStyles.label.copyWith(color: subtleColor),
          ),
          trailing: Icon(Icons.chevron_right, color: subtleColor, size: 20),
          onTap: () async {
            final configured = await LlmService.isConfigured();
            if (!configured && context.mounted) {
              _showNeedConfigHint(context, isDark, goldColor);
              return;
            }
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              );
            }
          },
        ),
        Divider(
          height: 1,
          color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine,
        ),
        ListTile(
          leading: Icon(Icons.vpn_key_outlined, color: goldColor),
          title: Text(
            'API 配置',
            style: AppTextStyles.body.copyWith(color: textColor),
          ),
          subtitle: Text(
            '设置大模型 API Key 和模型',
            style: AppTextStyles.label.copyWith(color: subtleColor),
          ),
          trailing: Icon(Icons.chevron_right, color: subtleColor, size: 20),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => const ApiConfigDialog(),
            );
          },
        ),
      ],
    );
  }

  void _showNeedConfigHint(BuildContext context, bool isDark, Color goldColor) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        title: Text(
          '需要配置 API',
          style: AppTextStyles.heading.copyWith(
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
          ),
        ),
        content: Text(
          '请先在「API 配置」中设置 API Key 和模型，才能使用 AI 聊天功能。',
          style: AppTextStyles.body.copyWith(
            color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(
              color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
            )),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => const ApiConfigDialog(),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: goldColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('去配置'),
          ),
        ],
      ),
    );
  }
}
