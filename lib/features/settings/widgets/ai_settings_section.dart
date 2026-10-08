import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../assistant/services/orb_visibility.dart';
import '../../chat/screens/chat_screen.dart';

/// 全局设置里的「AI 助手」入口。
///
/// 只负责进入对话。API 配置、模型列表更新、对话参数、会话管理等
/// 已全部迁移到 AI 助手内部的设置页，与全局设置分离。
///
/// 注意：这里**不再**做「未配置就不让进」的拦截——配置入口就在聊天页里，
/// 拦住了用户反而没法配。
class AiSettingsSection extends StatelessWidget {
  const AiSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return ListTile(
      leading: Icon(Icons.chat_bubble_outline, color: goldColor),
      title: Text(
        'AI 助手',
        style: AppTextStyles.body.copyWith(color: textColor),
      ),
      subtitle: Text(
        '与 AI 助手对话，模型与参数在聊天页内设置',
        style: AppTextStyles.label.copyWith(color: subtleColor),
      ),
      trailing: Icon(Icons.chevron_right, color: subtleColor, size: 20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            // 必须显式命名：悬浮球靠它判断「现在是不是聊天页」
            settings: const RouteSettings(name: OrbRoutes.chat),
            builder: (_) => const ChatScreen(),
          ),
        );
      },
    );
  }
}
