import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../services/chat_exporter.dart';

/// 选择导出格式的底部弹窗。点空白处返回 null。
///
/// 抽成共用组件是因为「会话抽屉」和「AI 助手设置」两处都要用它 ——
/// 复制一份的话，将来加格式（比如 PDF）必然会漏掉其中一处。
Future<ChatExportFormat?> showChatExportSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<ChatExportFormat>(
    context: context,
    backgroundColor:
        isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Text(
            '导出为',
            style: AppTextStyles.label.copyWith(
              color: isDark ? AppColors.darkLabelText : AppColors.labelText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...ChatExportFormat.values.map(
            (f) => ListTile(
              leading: Icon(
                iconOfExportFormat(f),
                size: 20,
                color: isDark ? AppColors.darkPink : AppColors.pinkDark,
              ),
              title: Text(
                f.label,
                style: AppTextStyles.body.copyWith(
                  color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                ),
              ),
              subtitle: Text(
                f.hint,
                style: AppTextStyles.label.copyWith(
                  color:
                      isDark ? AppColors.darkLabelText : AppColors.labelText,
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, f),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
}

IconData iconOfExportFormat(ChatExportFormat format) {
  switch (format) {
    case ChatExportFormat.markdown:
      return Icons.article_outlined;
    case ChatExportFormat.plainText:
      return Icons.notes_rounded;
    case ChatExportFormat.json:
      return Icons.data_object_rounded;
  }
}
