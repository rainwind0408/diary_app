import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确定',
  String cancelText = '取消',
  Color? confirmColor,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
      title: Text(title, style: AppTextStyles.cardTitle.copyWith(
        color: isDark ? AppColors.darkTitleText : AppColors.titleText,
      )),
      content: Text(message, style: AppTextStyles.body.copyWith(
        color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText, style: AppTextStyles.label.copyWith(
            color: isDark ? AppColors.darkLabelText : AppColors.labelText,
          )),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmText,
            style: AppTextStyles.label.copyWith(
              color: confirmColor ?? AppColors.deleteRed,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
