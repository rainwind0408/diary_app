import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/placed_audio.dart';
import '../../../data/models/placed_image.dart';
import 'audio_layer.dart';
import 'image_layer.dart';
import 'word_count_display.dart';

/// 标题槽的固定高度。
///
/// 之所以要固定：手写横线是画在**纸页坐标系**上的，`contentTop` 必须是个
/// 已知常量。标题区高度若随字体/内容浮动，正文首行基线就会跟着上下移动，
/// 横线整体错位。
const double kTitleSlotHeight = 56.0;

/// 标题区与正文之间的间距
const double kTitleGap = 16.0;

/// 正文区顶部在纸页内的偏移 = 纸页内边距 + 标题槽 + 间距
const double kContentTop =
    AppDimensions.writePagePadding + kTitleSlotHeight + kTitleGap;

/// 正文首行基线的微调补偿（正数 = 横线整体下移）。
///
/// `TextField` 即便设了 `contentPadding: EdgeInsets.zero` 与
/// `InputBorder.none`，`InputDecorator` 仍可能留下 1~2px 的度量差异。
/// 这个值需要**真机校一次**：横线比文字偏上就调大，偏下就调小。
const double kContentBaselineNudge = 0.0;

/// 单页纸：高度随正文增长，整页由外层 `SingleChildScrollView` 滚动。
///
/// 结构自下而上：
/// 1. 纸页容器（圆角 + 边框 + 阴影），`minHeight` 至少容纳媒体；
/// 2. 手写横线（`CustomPaint`，按真实字体度量对齐）；
/// 3. 标题 + 正文（`TextField(maxLines: null)`，不设 `expands`，自然增高）；
/// 4. 图片 / 录音图层（绝对定位叠加在纸页上）。
class DiaryPaper extends StatefulWidget {
  const DiaryPaper({
    super.key,
    required this.titleController,
    required this.contentController,
    required this.wordCount,
    required this.mediaExtent,
    this.minHeight = 0,
    this.onTitleChanged,
    this.onContentChanged,
    this.images = const [],
    this.audios = const [],
    this.onImagesChanged,
    this.onAudiosChanged,
    this.onInteractionStart,
    this.onInteractionEnd,
    this.onImageView,
  });

  final TextEditingController titleController;
  final TextEditingController contentController;

  /// 字数（独立推送，避免打字时整页重建）
  final ValueListenable<int> wordCount;

  /// 媒体占据的纵向范围（相对纸页顶部），用于纸页 `minHeight`
  final double mediaExtent;

  /// 纸页最小高度 —— 内容少时也要铺满视口，看起来仍"是一页纸"
  final double minHeight;

  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<String>? onContentChanged;
  final List<PlacedImage> images;
  final List<PlacedAudio> audios;
  final ValueChanged<List<PlacedImage>>? onImagesChanged;
  final ValueChanged<List<PlacedAudio>>? onAudiosChanged;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;
  final ValueChanged<PlacedImage>? onImageView;

  @override
  State<DiaryPaper> createState() => _DiaryPaperState();
}

class _DiaryPaperState extends State<DiaryPaper> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final hintColor =
        isDark ? AppColors.darkPlaceholderText : AppColors.placeholderText;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final cardBg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    final textScaler = MediaQuery.textScalerOf(context);
    final bodyStyle = AppTextStyles.body.copyWith(color: textColor);
    // 行高与首行基线走真实字体度量 —— 支持全局字号缩放（FontSizeProvider）
    final metrics = _TextMetrics.of(bodyStyle, textScaler);

    return Stack(
      children: [
        // ===== 纸页本体 =====
        Container(
          constraints: BoxConstraints(
            minHeight: math.max(
              widget.minHeight,
              widget.mediaExtent + AppDimensions.writePagePadding * 2,
            ),
          ),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppDimensions.writePageRadius),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.writePageRadius),
            child: Stack(
              children: [
                // 手写横线
                if (!isDark)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RuledLinesPainter(
                        color: accentColor.withValues(alpha: 0.08),
                        lineHeight: metrics.lineHeight,
                        firstBaseline: metrics.firstBaseline,
                        contentTop: kContentTop + kContentBaselineNudge,
                      ),
                    ),
                  ),
                // 标题 + 正文
                Padding(
                  padding:
                      const EdgeInsets.all(AppDimensions.writePagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: kTitleSlotHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: widget.titleController,
                            onChanged: widget.onTitleChanged,
                            style: AppTextStyles.handwritingTitle.copyWith(
                              fontSize: 22,
                              color: titleColor,
                            ),
                            decoration: InputDecoration(
                              hintText: '标题（可选）',
                              hintStyle:
                                  AppTextStyles.handwritingTitle.copyWith(
                                color: hintColor,
                                fontSize: 22,
                              ),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: accentColor.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: accentColor, width: 1.5),
                              ),
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: kTitleGap),
                      // 正文：maxLines = null 且**不设 expands**，
                      // 高度由内容决定 —— 这是单页化最关键的一行。
                      TextField(
                        controller: widget.contentController,
                        onChanged: widget.onContentChanged,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textAlignVertical: TextAlignVertical.top,
                        style: bodyStyle,
                        decoration: InputDecoration(
                          hintText: '今天发生了什么……',
                          hintStyle:
                              AppTextStyles.body.copyWith(color: hintColor),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ValueListenableBuilder<int>(
                            valueListenable: widget.wordCount,
                            builder: (_, count, __) =>
                                WordCountDisplay(count: count),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ===== 图片图层 =====
        if (widget.onImagesChanged != null)
          Positioned.fill(
            child: ImageLayer(
              images: widget.images,
              onImagesChanged: widget.onImagesChanged!,
              onInteractionStart: widget.onInteractionStart ?? () {},
              onInteractionEnd: widget.onInteractionEnd ?? () {},
              onDoubleTapBelowImage: _createNewLineBelowImage,
              onImageView: widget.onImageView,
            ),
          ),

        // ===== 录音图层 =====
        if (widget.onAudiosChanged != null)
          Positioned.fill(
            child: AudioLayer(
              audios: widget.audios,
              onAudiosChanged: widget.onAudiosChanged!,
              onInteractionStart: widget.onInteractionStart ?? () {},
              onInteractionEnd: widget.onInteractionEnd ?? () {},
            ),
          ),
      ],
    );
  }

  /// 在图片下方补一个空行（双击图片触发的快捷排版）
  void _createNewLineBelowImage(PlacedImage img) {
    final controller = widget.contentController;
    final currentText = controller.text;
    final newText =
        currentText.endsWith('\n') ? '$currentText\n' : '$currentText\n\n';

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    widget.onContentChanged?.call(newText);
    FocusScope.of(context).requestFocus();
  }
}

/// 真实字体度量：行高与首行基线偏移
class _TextMetrics {
  const _TextMetrics(this.lineHeight, this.firstBaseline);

  final double lineHeight;
  final double firstBaseline;

  static _TextMetrics of(TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: '折花日记Ag', style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();

    return _TextMetrics(
      painter.preferredLineHeight,
      painter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
    );
  }
}

/// 手写横线。
///
/// 行高与首行基线都取自 `TextPainter` 的真实字体度量，而不是硬编码的
/// `28.0`：旧实现里 `lineHeight = 28.0`，而 `AppTextStyles.body` 实际是
/// `16 × 1.8 = 28.8`，每行差 0.8px。旧版每页只有 15 行，误差被翻页掩盖；
/// 单页写到上百行会累积成好几行的偏移，文字会彻底脱离横线。
class _RuledLinesPainter extends CustomPainter {
  _RuledLinesPainter({
    required this.color,
    required this.lineHeight,
    required this.firstBaseline,
    required this.contentTop,
  });

  final Color color;
  final double lineHeight;
  final double firstBaseline;
  final double contentTop;

  @override
  void paint(Canvas canvas, Size size) {
    if (lineHeight <= 0 || size.width <= 32) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // 横线压在基线稍下方，模拟"字写在横线上"的观感
    final baselineToRule = lineHeight * 0.18;
    const double startX = 16;
    final double endX = math.max(startX + 1, size.width - 16);

    for (double y = contentTop + firstBaseline + baselineToRule;
        y < size.height - 12;
        y += lineHeight) {
      final path = Path()..moveTo(startX, y);
      for (double x = startX; x < endX; x += 2) {
        path.lineTo(x, y + math.sin(x * 0.02) * 1.5);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RuledLinesPainter old) =>
      old.color != color ||
      old.lineHeight != lineHeight ||
      old.firstBaseline != firstBaseline ||
      old.contentTop != contentTop;
}
