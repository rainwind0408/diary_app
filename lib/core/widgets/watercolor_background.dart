import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../utils/solar_terms.dart';
import '../../features/weather/providers/seasonal_provider.dart';
import 'watercolor_decoration.dart';

/// 水彩风格的页面背景
/// 节气主题开启：使用节气对应的背景图
/// 节气主题关闭：使用水彩背景图（根据季节自动选择）
class WatercolorBackground extends StatelessWidget {
  final Widget child;

  const WatercolorBackground({super.key, required this.child});

  /// 根据季节获取水彩背景图路径
  ///
  /// 2026-10-09 体积优化：原为 `.png`。这四张图是 **RGB 无 alpha** 的整屏背景，
  /// 用 PNG 存纯属浪费（每张 4.2~4.7 MB）。转为 JPEG(q88) 后每张约 0.5 MB，
  /// 分辨率保持不变 —— 它们走 `BoxFit.cover` 铺满整屏，降分辨率会被放大回
  /// 屏幕物理像素（1224x2776），得不偿失。
  static String _getWatercolorBgPath(Season season) {
    switch (season) {
      case Season.spring:
        return 'assets/backgrounds/wc_bg_spring.jpg';
      case Season.summer:
        return 'assets/backgrounds/wc_bg_summer.jpg';
      case Season.autumn:
        return 'assets/backgrounds/wc_bg_autumn.jpg';
      case Season.winter:
        return 'assets/backgrounds/wc_bg_winter.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seasonal = context.watch<SeasonalProvider>();
    final palette = seasonal.isEnabled ? seasonal.palette : null;

    // 节气主题开启：使用节气背景图
    final useSeasonalBg = seasonal.isEnabled &&
        !isDark &&
        seasonal.currentBackgroundPath != null;

    // 节气主题关闭：使用水彩背景图
    final currentSeason = SolarTerms.getSeason(DateTime.now());
    final useWatercolorBg = !seasonal.isEnabled && !isDark;

    final bgColor = isDark
        ? AppColors.darkPageBackground
        : (palette?.deskBg ?? AppColors.pageBackground);

    return Container(
      decoration: BoxDecoration(
        color: (useSeasonalBg || useWatercolorBg) ? null : bgColor,
        image: useSeasonalBg
            ? DecorationImage(
                image: AssetImage(seasonal.currentBackgroundPath!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.1),
                  BlendMode.darken,
                ),
              )
            : useWatercolorBg
                ? DecorationImage(
                    image: AssetImage(_getWatercolorBgPath(currentSeason)),
                    fit: BoxFit.cover,
                  )
                : null,
        gradient: (useSeasonalBg || useWatercolorBg)
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [AppColors.darkPageBackground, AppColors.darkPageBackgroundAlt]
                    : [
                        palette?.paperWhite ?? AppColors.pageBackground,
                        palette?.paperWhiteAlt ?? AppColors.pageBackgroundAlt,
                      ],
              ),
      ),
      child: Stack(
        children: [
          // 水彩装饰层（花朵、云朵、星星）
          if (!isDark) const WatercolorDecorations(),
          // 内容层
          child,
        ],
      ),
    );
  }
}
