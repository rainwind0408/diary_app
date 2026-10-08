import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';

/// 卡片层级
///
/// 全项目此前有 42 个文件各自手写 `Container + BoxDecoration` 当卡片壳，
/// 圆角、阴影、内边距三样东西散落各处、互相对不上。这里收敛成三档**语义**：
///
/// - [CardTier.hero]    主角卡：柔和渐变底、**无阴影**、圆角 20。一屏最多一张。
/// - [CardTier.primary] 常规卡：不透明白底 + 柔和阴影、圆角 20。默认值。
/// - [CardTier.quiet]   安静卡：无阴影浅底、圆角 14。用于「分组容器」——
///   把几个小图表收进一张卡里，而不是每个图表各占一张卡。
///
/// **三档一律不透明**，这是实测结论而非偏好：亮色模式下 `WatercolorBackground`
/// 永远铺整幅水彩背景图，卡片一旦半透明，正文对比度就压不住背景。
/// 逐像素测过 30 张背景图，没有一张能让正文达到 WCAG AA（冬至平均对比度仅
/// 1.23:1，要达标需 alpha 0.93）。所以「安静」靠小圆角 + 无阴影 + 浅底色表达，
/// **不靠透出背景**。
enum CardTier { hero, primary, quiet }

/// 通用卡片容器
///
/// 新增卡片一律用它，别再造第 43 个 `Container + BoxDecoration`。
class AppCard extends StatelessWidget {
  final CardTier tier;
  final Widget child;

  /// 覆盖默认内边距；不传则按层级取 [AppDimensions] 的对应档
  final EdgeInsetsGeometry? padding;

  /// 传了就用 [InkWell] 包一层（有涟漪、语义上可点）
  final VoidCallback? onTap;

  /// 覆盖默认圆角
  final double? radius;

  const AppCard({
    super.key,
    this.tier = CardTier.primary,
    required this.child,
    this.padding,
    this.onTap,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color color;
    final Gradient? gradient;
    final List<BoxShadow> shadow;
    final double r;

    switch (tier) {
      case CardTier.hero:
        r = radius ?? AppDimensions.cardRadius;
        shadow = const <BoxShadow>[];
        if (isDark) {
          color = Colors.transparent;
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.darkCardBackgroundAlt, AppColors.darkCardBackground],
          );
        } else {
          color = Colors.transparent;
          gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.pinkLight, AppColors.cardBackground],
          );
        }

      case CardTier.primary:
        r = radius ?? AppDimensions.cardRadius;
        color = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
        gradient = null;
        shadow = isDark ? AppColors.darkCardShadow : AppColors.cardShadow;

      case CardTier.quiet:
        r = radius ?? 14;
        color =
            isDark ? AppColors.darkCardBackgroundAlt : AppColors.cardBackgroundAlt;
        gradient = null;
        shadow = const <BoxShadow>[];
    }

    final defaultPadding = switch (tier) {
      CardTier.hero => const EdgeInsets.all(AppDimensions.lg),
      CardTier.primary => const EdgeInsets.all(AppDimensions.md),
      CardTier.quiet => const EdgeInsets.all(AppDimensions.md),
    };

    Widget inner = Padding(
      padding: padding ?? defaultPadding,
      child: child,
    );

    if (onTap != null) {
      inner = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: inner),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(r),
        boxShadow: shadow,
      ),
      child: inner,
    );
  }
}
