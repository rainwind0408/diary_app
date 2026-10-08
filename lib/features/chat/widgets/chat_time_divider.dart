import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../utils/chat_time_format.dart';

/// 聊天时间分隔条。
///
/// 就是一行居中的浅灰小字，**没有胶囊底色** —— 上一版是个灰底圆角块，
/// 一屏里出现三四次就成了视觉噪音。QQ 也是纯文字。
///
/// 判定与文案逻辑在纯 Dart 的 [ChatTimeFormat] 里，这里只负责渲染。
class ChatTimeDivider extends StatelessWidget {
  final DateTime time;

  const ChatTimeDivider({super.key, required this.time});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Center(
        child: Text(
          ChatTimeFormat.format(time),
          style: AppTextStyles.pageNumber.copyWith(
            color: (isDark ? AppColors.darkSubtleText : AppColors.subtleText)
                .withValues(alpha: 0.9),
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
