import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/word_counter.dart';
import '../../../core/utils/text_layout_utils.dart';
import '../../../data/models/placed_image.dart';
import '../../../data/models/placed_audio.dart';
import 'word_count_display.dart';
import 'image_layer.dart';
import 'audio_layer.dart';

class DiaryPage extends StatefulWidget {
  final int pageIndex;
  final String pageContent; // 当前页显示的内容（从连续内容截取）
  final bool isEditable; // 是否是当前编辑页
  final TextEditingController? controller; // 共享控制器（仅编辑页使用）
  final void Function(String currentText, String? overflowText, double width) onContentChanged;
  final ValueChanged<String>? onTitleChanged;
  final String? initialTitle;
  final ValueChanged<List<PlacedImage>>? onImagesChanged;
  final ValueChanged<List<PlacedAudio>>? onAudiosChanged;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;
  final ValueChanged<PlacedImage>? onImageView;
  final List<PlacedImage> images;
  final List<PlacedAudio> audios;

  const DiaryPage({
    super.key,
    required this.pageIndex,
    required this.pageContent,
    required this.isEditable,
    this.controller,
    required this.onContentChanged,
    this.onTitleChanged,
    this.initialTitle,
    this.onImagesChanged,
    this.onAudiosChanged,
    this.onInteractionStart,
    this.onInteractionEnd,
    this.onImageView,
    this.images = const [],
    this.audios = const [],
  });

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
  }

  @override
  void didUpdateWidget(DiaryPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialTitle != oldWidget.initialTitle &&
        widget.initialTitle != null &&
        _titleController.text != widget.initialTitle) {
      _titleController.text = widget.initialTitle!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTitlePage = widget.pageIndex == 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final hintColor =
        isDark ? AppColors.darkPlaceholderText : AppColors.placeholderText;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final cardBg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    return Stack(
      children: [
        // 底层：水彩装饰边框卡片
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pagePaddingH,
            vertical: AppDimensions.md,
          ),
          child: Container(
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
              borderRadius:
                  BorderRadius.circular(AppDimensions.writePageRadius),
              child: Stack(
                children: [
                  // 水彩线条装饰
                  if (!isDark)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _WatercolorLinesPainter(
                          color: accentColor.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  // 文字输入层
                  Padding(
                    padding:
                        const EdgeInsets.all(AppDimensions.writePagePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isTitlePage) ...[
                          TextField(
                            controller: _titleController,
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
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          Text(
                            '第 ${widget.pageIndex + 1} 页',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtleColor.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 28.0 * 15, // 15 行，每行 28 像素
                            ),
                            child: _buildContentArea(
                              textColor: textColor,
                              hintColor: hintColor,
                            ),
                          ),
                        ),
                        if (isTitlePage)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                WordCountDisplay(
                                  count: WordCounter.count(widget.pageContent),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 上层：图片图层
        if (widget.onImagesChanged != null)
          ImageLayer(
            images: widget.images,
            onImagesChanged: widget.onImagesChanged!,
            onInteractionStart: widget.onInteractionStart ?? () {},
            onInteractionEnd: widget.onInteractionEnd ?? () {},
            onDoubleTapBelowImage: _createNewLineBelowImage,
            onImageView: widget.onImageView,
          ),
        // 最上层：录音图层
        if (widget.onAudiosChanged != null)
          AudioLayer(
            audios: widget.audios,
            onAudiosChanged: widget.onAudiosChanged!,
            onInteractionStart: widget.onInteractionStart ?? () {},
            onInteractionEnd: widget.onInteractionEnd ?? () {},
          ),
      ],
    );
  }

  Widget _buildContentArea({
    required Color textColor,
    required Color hintColor,
  }) {
    if (widget.isEditable) {
      // 当前页：可编辑 TextField
      return LayoutBuilder(
        builder: (context, constraints) {
          return TextField(
            controller: widget.controller,
            onChanged: (value) {
              final lineCount = TextLayoutUtils.getVisualLineCount(
                value,
                constraints.maxWidth,
                AppTextStyles.body,
              );

              if (lineCount > 15) {
                final splitIndex = TextLayoutUtils.getSplitIndex(
                  value,
                  constraints.maxWidth,
                  15,
                  AppTextStyles.body,
                );
                final currentText = value.substring(0, splitIndex);
                final overflowText = value.substring(splitIndex);

                widget.onContentChanged(
                    currentText, overflowText, constraints.maxWidth);
              } else {
                widget.onContentChanged(value, null, constraints.maxWidth);
              }
            },
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: AppTextStyles.body.copyWith(color: textColor),
            decoration: InputDecoration(
              hintText: widget.pageIndex == 0
                  ? '今天发生了什么……'
                  : '继续写下你的故事……',
              hintStyle: AppTextStyles.body.copyWith(color: hintColor),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          );
        },
      );
    } else {
      // 其他页：只读文本
      return SingleChildScrollView(
        child: Text(
          widget.pageContent,
          style: AppTextStyles.body.copyWith(color: textColor),
        ),
      );
    }
  }

  /// 在图片下方创建新行
  void _createNewLineBelowImage(PlacedImage img) {
    if (!widget.isEditable || widget.controller == null) return;
    final currentText = widget.controller!.text;
    String newText;
    if (currentText.endsWith('\n')) {
      newText = '$currentText\n';
    } else {
      newText = '$currentText\n\n';
    }

    widget.controller!.text = newText;
    widget.controller!.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );

    FocusScope.of(context).requestFocus();

    // 通知内容变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onContentChanged(newText, null, 300); // width 会在 LayoutBuilder 中更新
      }
    });
  }
}

/// 水彩横线装饰
class _WatercolorLinesPainter extends CustomPainter {
  final Color color;
  final int maxLines;
  _WatercolorLinesPainter({required this.color, this.maxLines = 15});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final lineHeight = 28.0;
    final startY = 80.0;
    int lineCount = 0;

    for (double y = startY; y < size.height - 20 && lineCount < maxLines; y += lineHeight) {
      final path = Path();
      path.moveTo(16, y);
      for (double x = 16; x < size.width - 16; x += 2) {
        final wave = sin(x * 0.02) * 1.5;
        path.lineTo(x, y + wave);
      }
      canvas.drawPath(path, paint);
      lineCount++;
    }
  }

  @override
  bool shouldRepaint(_WatercolorLinesPainter old) => old.color != color || old.maxLines != maxLines;
}
