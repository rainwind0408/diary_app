import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

class FadeTruncation extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final bool expanded;

  const FadeTruncation({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 3,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (expanded) {
      return Text(text, style: style);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    return Stack(
      children: [
        Text(
          text,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.clip,
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: AppDimensions.fadeHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bgColor.withValues(alpha: 0.0),
                  bgColor,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
