import 'dart:math';
import 'package:flutter/material.dart';

/// Draws subtle decorative patterns based on the current solar term theme.
/// Overlay at 3-5% opacity on the paper background.
class SeasonalDecoration extends StatelessWidget {
  final String theme;
  final Color accentColor;
  final double opacity;

  const SeasonalDecoration({
    super.key,
    required this.theme,
    required this.accentColor,
    this.opacity = 0.04,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _DecorationPainter(
          theme: theme,
          color: accentColor.withValues(alpha: opacity),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DecorationPainter extends CustomPainter {
  final String theme;
  final Color color;

  _DecorationPainter({required this.theme, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (theme) {
      // 春季：嫩芽
      case 'lichun':
      case 'yushui':
        _drawSprouts(canvas, size, paint);
        break;
      // 春季：樱花
      case 'jingzhe':
      case 'chunfen':
        _drawSakura(canvas, size, paint);
        break;
      // 春季：雨滴
      case 'qingming':
      case 'guyu':
        _drawRain(canvas, size, paint);
        break;
      // 夏季：绿叶
      case 'lixia':
      case 'xiaoman':
        _drawLeaves(canvas, size, paint);
        break;
      // 夏季：阳光
      case 'mangzhong':
      case 'xiazhi':
        _drawSunshine(canvas, size, paint);
        break;
      // 夏季：向日葵
      case 'xiaoshu':
      case 'dashu':
        _drawSunflower(canvas, size, paint);
        break;
      // 秋季：落叶
      case 'liqiu':
      case 'chushu':
        _drawFallingLeaves(canvas, size, paint);
        break;
      // 秋季：稻穗
      case 'bailu':
      case 'qiufen':
        _drawRice(canvas, size, paint);
        break;
      // 秋季：枫叶
      case 'hanlu':
      case 'shuangjiang':
        _drawMaple(canvas, size, paint);
        break;
      // 冬季：栗子
      case 'lidong':
      case 'xiaoxue':
        _drawChestnut(canvas, size, paint);
        break;
      // 冬季：雪花
      case 'daxue':
      case 'dongzhi':
        _drawSnowflake(canvas, size, paint);
        break;
      // 冬季：雪山
      case 'xiaohan':
      case 'dahan':
        _drawSnowMountain(canvas, size, paint);
        break;
    }
  }

  // 🌱 Sprout: small upward V-shapes
  void _drawSprouts(Canvas canvas, Size size, Paint paint) {
    final random = Random(42);
    for (int i = 0; i < 8; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final h = 12.0 + random.nextDouble() * 8;
      final path = Path()
        ..moveTo(x - 4, y)
        ..quadraticBezierTo(x - 2, y - h * 0.6, x, y - h)
        ..quadraticBezierTo(x + 2, y - h * 0.6, x + 4, y);
      canvas.drawPath(path, paint);
    }
  }

  // 🌸 Sakura: small 5-petal flowers
  void _drawSakura(Canvas canvas, Size size, Paint paint) {
    final random = Random(42);
    for (int i = 0; i < 6; i++) {
      final cx = random.nextDouble() * size.width;
      final cy = random.nextDouble() * size.height;
      final r = 4.0 + random.nextDouble() * 3;
      for (int p = 0; p < 5; p++) {
        final angle = p * pi * 2 / 5;
        final px = cx + cos(angle) * r;
        final py = cy + sin(angle) * r;
        canvas.drawCircle(Offset(px, py), r * 0.6, paint);
      }
      canvas.drawCircle(Offset(cx, cy), r * 0.3, paint);
    }
  }

  // 🌧️ Rain: vertical lines
  void _drawRain(Canvas canvas, Size size, Paint paint) {
    final random = Random(42);
    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final len = 15.0 + random.nextDouble() * 10;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 2, y + len),
        paint..strokeWidth = 1,
      );
    }
  }

  // 🌿 Leaves: simple oval shapes
  void _drawLeaves(Canvas canvas, Size size, Paint paint) {
    final random = Random(42);
    for (int i = 0; i < 7; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(random.nextDouble() * pi);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 8, height: 16),
        paint,
      );
      canvas.restore();
    }
  }

  // ☀️ Sunshine: radiating lines from a point
  void _drawSunshine(Canvas canvas, Size size, Paint paint) {
    final cx = size.width * 0.85;
    final cy = size.height * 0.1;
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final inner = 15.0;
      final outer = 30.0;
      canvas.drawLine(
        Offset(cx + cos(angle) * inner, cy + sin(angle) * inner),
        Offset(cx + cos(angle) * outer, cy + sin(angle) * outer),
        paint..strokeWidth = 1.5,
      );
    }
  }

  // 🌻 Sunflower: circle with petal lines
  void _drawSunflower(Canvas canvas, Size size, Paint paint) {
    final random = Random(42);
    for (int i = 0; i < 3; i++) {
      final cx = random.nextDouble() * size.width;
      final cy = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(cx, cy), 6, paint);
      for (int p = 0; p < 8; p++) {
        final angle = p * pi / 4;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + cos(angle) * 10, cy + sin(angle) * 10),
            width: 4,
            height: 8,
          ),
          paint,
        );
      }
    }
  }

  // 🍂 Falling leaves: tilted ovals
  void _drawFallingLeaves(Canvas canvas, Size size, Paint paint) {
    final random = Random(42);
    for (int i = 0; i < 8; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(random.nextDouble() * pi);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 6, height: 12),
        paint,
      );
      canvas.restore();
    }
  }

  // 🌾 Rice: vertical lines with small side strokes
  void _drawRice(Canvas canvas, Size size, Paint paint) {
    final random = Random(42);
    for (int i = 0; i < 6; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final stem = Path()
        ..moveTo(x, y + 20)
        ..lineTo(x, y);
      canvas.drawPath(stem, paint..strokeWidth = 1);
      // Side strokes
      for (int j = 0; j < 3; j++) {
        final sy = y + j * 5;
        canvas.drawLine(Offset(x, sy), Offset(x + 6, sy - 4), paint..strokeWidth = 0.8);
        canvas.drawLine(Offset(x, sy), Offset(x - 6, sy - 4), paint..strokeWidth = 0.8);
      }
    }
  }

  // 🍁 Maple: 5-pointed star shape
  void _drawMaple(Canvas canvas, Size size, Paint paint) {
    final random = Random(42);
    for (int i = 0; i < 5; i++) {
      final cx = random.nextDouble() * size.width;
      final cy = random.nextDouble() * size.height;
      final r = 6.0 + random.nextDouble() * 4;
      final path = Path();
      for (int p = 0; p < 5; p++) {
        final outerAngle = p * pi * 2 / 5 - pi / 2;
        final innerAngle = outerAngle + pi / 5;
        final ox = cx + cos(outerAngle) * r;
        final oy = cy + sin(outerAngle) * r;
        final ix = cx + cos(innerAngle) * r * 0.4;
        final iy = cy + sin(innerAngle) * r * 0.4;
        if (p == 0) {
          path.moveTo(ox, oy);
        } else {
          path.lineTo(ox, oy);
        }
        path.lineTo(ix, iy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  // 🌰 Chestnut: small circles with spike hints
  void _drawChestnut(Canvas canvas, Size size, Paint paint) {
    final random = Random(42);
    for (int i = 0; i < 5; i++) {
      final cx = random.nextDouble() * size.width;
      final cy = random.nextDouble() * size.height;
      canvas.drawCircle(Offset(cx, cy), 5, paint);
      // Small spikes on top
      for (int s = 0; s < 3; s++) {
        final angle = -pi / 2 + (s - 1) * pi / 6;
        canvas.drawLine(
          Offset(cx + cos(angle) * 5, cy + sin(angle) * 5),
          Offset(cx + cos(angle) * 9, cy + sin(angle) * 9),
          paint..strokeWidth = 0.8,
        );
      }
    }
  }

  // ❄️ Snowflake: 6-armed crystal
  void _drawSnowflake(Canvas canvas, Size size, Paint paint) {
    final random = Random(42);
    for (int i = 0; i < 5; i++) {
      final cx = random.nextDouble() * size.width;
      final cy = random.nextDouble() * size.height;
      final r = 8.0 + random.nextDouble() * 6;
      for (int arm = 0; arm < 6; arm++) {
        final angle = arm * pi / 3;
        final endX = cx + cos(angle) * r;
        final endY = cy + sin(angle) * r;
        canvas.drawLine(Offset(cx, cy), Offset(endX, endY), paint..strokeWidth = 1);
        // Small branches
        final midX = cx + cos(angle) * r * 0.6;
        final midY = cy + sin(angle) * r * 0.6;
        for (int b = -1; b <= 1; b += 2) {
          final branchAngle = angle + b * pi / 4;
          canvas.drawLine(
            Offset(midX, midY),
            Offset(midX + cos(branchAngle) * r * 0.25, midY + sin(branchAngle) * r * 0.25),
            paint..strokeWidth = 0.8,
          );
        }
      }
    }
  }

  // 🏔️ Snow mountain: simple triangular peaks
  void _drawSnowMountain(Canvas canvas, Size size, Paint paint) {
    // Draw at bottom of the page
    final baseY = size.height * 0.85;
    final random = Random(42);
    for (int i = 0; i < 3; i++) {
      final cx = size.width * (0.2 + i * 0.3);
      final h = 40.0 + random.nextDouble() * 20;
      final w = 60.0 + random.nextDouble() * 30;
      final path = Path()
        ..moveTo(cx - w / 2, baseY)
        ..lineTo(cx, baseY - h)
        ..lineTo(cx + w / 2, baseY)
        ..close();
      canvas.drawPath(path, paint);
      // Snow cap
      final capPath = Path()
        ..moveTo(cx - w * 0.15, baseY - h * 0.7)
        ..lineTo(cx, baseY - h)
        ..lineTo(cx + w * 0.15, baseY - h * 0.7)
        ..close();
      canvas.drawPath(capPath, paint);
    }
  }

  @override
  bool shouldRepaint(_DecorationPainter oldDelegate) {
    return oldDelegate.theme != theme || oldDelegate.color != color;
  }
}
