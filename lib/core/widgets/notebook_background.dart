import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../utils/solar_terms.dart';
import '../../features/weather/providers/seasonal_provider.dart';

/// 水彩风格的页面背景
/// 节气主题开启：使用节气对应的背景图
/// 节气主题关闭：使用水彩背景图（根据季节自动选择）
class NotebookBackground extends StatelessWidget {
  final Widget child;

  const NotebookBackground({super.key, required this.child});

  /// 根据季节获取水彩背景图路径
  static String _getWatercolorBgPath(Season season) {
    switch (season) {
      case Season.spring:
        return 'assets/backgrounds/wc_bg_spring.png';
      case Season.summer:
        return 'assets/backgrounds/wc_bg_summer.png';
      case Season.autumn:
        return 'assets/backgrounds/wc_bg_autumn.png';
      case Season.winter:
        return 'assets/backgrounds/wc_bg_winter.png';
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
      child: child,
    );
  }
}
