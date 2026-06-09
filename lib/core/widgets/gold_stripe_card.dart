import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// 水彩风格的柔和卡片
/// 替代原来的金色条纹卡片
class GoldStripeCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? borderRadius;

  const GoldStripeCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? AppDimensions.cardRadius;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        onLongPress: onLongPress != null
            ? () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              }
            : null,
        borderRadius: BorderRadius.circular(radius),
        splashColor: (isDark ? AppColors.darkPink : AppColors.pinkLight)
            .withValues(alpha: 0.15),
        highlightColor:
            (isDark ? AppColors.darkPink : AppColors.pinkLight)
                .withValues(alpha: 0.08),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
