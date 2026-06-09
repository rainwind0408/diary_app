import 'package:flutter/material.dart';

/// 水彩装饰元素层
/// 在页面角落显示花朵、云朵、星星等装饰图片
class WatercolorDecorations extends StatelessWidget {
  final double opacity;

  const WatercolorDecorations({super.key, this.opacity = 0.6});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // 右上角花朵
          Positioned(
            top: -10,
            right: -10,
            child: Opacity(
              opacity: opacity,
              child: Image.asset(
                'assets/decorations/deco_flower_1.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          // 左下角云朵
          Positioned(
            bottom: 100,
            left: -20,
            child: Opacity(
              opacity: opacity * 0.7,
              child: Image.asset(
                'assets/decorations/deco_cloud_1.png',
                width: 140,
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          // 右下角小星星
          Positioned(
            bottom: 200,
            right: 30,
            child: Opacity(
              opacity: opacity * 0.5,
              child: Image.asset(
                'assets/decorations/deco_star_1.png',
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
