import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class PageTurnHint extends StatelessWidget {
  final bool visible;

  const PageTurnHint({super.key, required this.visible});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: visible
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('向左滑动翻页', style: AppTextStyles.hint),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.subtleText),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
