import 'package:flutter/material.dart';

class TextLayoutUtils {
  /// 计算视觉行数
  static int getVisualLineCount(String text, double maxWidth, TextStyle style) {
    if (text.isEmpty) return 0;

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    textPainter.layout(maxWidth: maxWidth);

    final lineHeight = style.fontSize! * (style.height ?? 1.2);
    return (textPainter.height / lineHeight).ceil();
  }

  /// 获取第 N 行末尾的字符位置
  static int getSplitIndex(
    String text,
    double maxWidth,
    int maxLines,
    TextStyle style,
  ) {
    if (text.isEmpty) return 0;

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    textPainter.layout(maxWidth: maxWidth);

    final lineHeight = style.fontSize! * (style.height ?? 1.2);
    final targetY = maxLines * lineHeight;

    final position = textPainter.getPositionForOffset(Offset(0, targetY));
    return position.offset;
  }
}
