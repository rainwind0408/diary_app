import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Ma Shan Zheng — headings, buttons, dates, tabs
  static const TextStyle heading = TextStyle(
    fontFamily: 'MaShanZheng',
    fontSize: 24,
    color: AppColors.titleText,
    height: 1.4,
    letterSpacing: 1.5,
  );

  static const TextStyle pageTitle = TextStyle(
    fontFamily: 'MaShanZheng',
    fontSize: 28,
    color: AppColors.titleText,
    height: 1.4,
    letterSpacing: 1.5,
  );

  // 参考图风格手写体标题（更大字号，用于"My Diary"等）
  static const TextStyle handwritingTitle = TextStyle(
    fontFamily: 'MaShanZheng',
    fontSize: 32,
    color: AppColors.titleText,
    height: 1.3,
    letterSpacing: 2.0,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: 'MaShanZheng',
    fontSize: 20,
    color: AppColors.titleText,
    height: 1.4,
    letterSpacing: 1.5,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: 'MaShanZheng',
    fontSize: 18,
    color: AppColors.goldAccent,
    letterSpacing: 1.5,
  );

  static const TextStyle tabLabel = TextStyle(
    fontFamily: 'MaShanZheng',
    fontSize: 18,
    color: AppColors.labelText,
    letterSpacing: 1.5,
  );

  static const TextStyle tabLabelActive = TextStyle(
    fontFamily: 'MaShanZheng',
    fontSize: 18,
    color: AppColors.headingText,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.5,
  );

  static const TextStyle dateLabel = TextStyle(
    fontFamily: 'MaShanZheng',
    fontSize: 16,
    color: AppColors.labelText,
    letterSpacing: 1.0,
  );

  static const TextStyle emptyState = TextStyle(
    fontFamily: 'MaShanZheng',
    fontSize: 20,
    color: AppColors.subtleText,
    letterSpacing: 1.5,
  );

  // ZCOOL XiaoWei — body, labels, page numbers
  static const TextStyle body = TextStyle(
    fontFamily: 'ZCOOLXiaoWei',
    fontSize: 16,
    color: AppColors.bodyText,
    height: 1.8,
    letterSpacing: 0.5,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: 'ZCOOLXiaoWei',
    fontSize: 18,
    color: AppColors.titleText,
    height: 1.7,
    letterSpacing: 0.5,
  );

  static const TextStyle cardBody = TextStyle(
    fontFamily: 'ZCOOLXiaoWei',
    fontSize: 15,
    color: AppColors.bodyText,
    height: 1.7,
    letterSpacing: 0.5,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'ZCOOLXiaoWei',
    fontSize: 14,
    color: AppColors.labelText,
    letterSpacing: 0.3,
  );

  static const TextStyle cardDate = TextStyle(
    fontFamily: 'ZCOOLXiaoWei',
    fontSize: 13,
    color: AppColors.subtleText,
    letterSpacing: 0.3,
  );

  static const TextStyle pageNumber = TextStyle(
    fontFamily: 'ZCOOLXiaoWei',
    fontSize: 12,
    color: AppColors.placeholderText,
    letterSpacing: 0.3,
  );

  static const TextStyle hint = TextStyle(
    fontFamily: 'MaShanZheng',
    fontSize: 14,
    color: AppColors.subtleText,
    letterSpacing: 1.0,
  );

  static const TextStyle toast = TextStyle(
    fontFamily: 'ZCOOLXiaoWei',
    fontSize: 16,
    letterSpacing: 0.5,
  );

  /// 根据缩放因子调整字体大小
  static TextStyle scaled(TextStyle style, double scale) {
    if (scale == 1.0) return style;
    return style.copyWith(fontSize: (style.fontSize ?? 16) * scale);
  }
}
