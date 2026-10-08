import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import 'attachment_panel.dart';

/// 「让 AI 画一张图」的输入结果。
class ImagePromptRequest {
  final String prompt;

  /// 参考图路径（图生图用）；没选就是 null，走纯文生图
  final String? referencePath;

  const ImagePromptRequest({required this.prompt, this.referencePath});
}

/// 让用户描述想画的画面（可选带一张参考图）。
///
/// 返回 [ImagePromptRequest]；点空白处关闭返回 null。
///
/// 这里**只负责收集输入**：配置校验、真正的生图请求都由调用方处理 ——
/// 弹窗一旦开始干活就得管加载态、错误态，很容易和聊天页的状态打架。
Future<ImagePromptRequest?> showImagePromptSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<ImagePromptRequest>(
    context: context,
    isScrollControlled: true,
    backgroundColor:
        isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _ImagePromptSheet(),
  );
}

class _ImagePromptSheet extends StatefulWidget {
  const _ImagePromptSheet();

  @override
  State<_ImagePromptSheet> createState() => _ImagePromptSheetState();
}

class _ImagePromptSheetState extends State<_ImagePromptSheet> {
  /// 点一下就补到描述末尾的风格词。
  ///
  /// 大部分人对着一张空白输入框是写不出东西的，给几个具体选项比空喊
  /// 「请描述得更详细」有用得多。
  static const List<String> _styles = [
    '水彩插画',
    '国风水墨',
    '宫崎骏动画',
    '像素风',
    '赛博朋克',
    '胶片质感',
  ];

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  String? _referencePath;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _appendStyle(String style) {
    final current = _controller.text.trimRight();
    final next = current.isEmpty ? style : '$current，$style';
    _controller.text = next;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: next.length),
    );
    _focusNode.requestFocus();
  }

  Future<void> _pickReference() async {
    if (_picking) return;
    _picking = true;
    try {
      final path = await AttachmentPicker.pickSingleImagePath();
      if (!mounted || path == null) return;
      setState(() => _referencePath = path);
    } finally {
      _picking = false;
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(
      context,
      ImagePromptRequest(prompt: text, referencePath: _referencePath),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtle = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final accent = isDark ? AppColors.darkPurple : AppColors.purple;

    return Padding(
      // 键盘弹起来时把整块内容顶上去，否则输入框会被挡住
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        // 内容比可用高度还高时（小屏 + 键盘 + 参考图缩略图）能滚，
        // 而不是把底部按钮挤出屏幕
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtle.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.palette_outlined, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    '让 AI 画一张图',
                    style: AppTextStyles.heading.copyWith(
                      color: textColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '描述你想要的画面。写上主体、风格、氛围、配色，出来的效果会好很多。',
                style: AppTextStyles.label.copyWith(
                  color: subtle,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  // 弹层本身是白面，输入框用暖灰底反衬 —— 和聊天页同一套
                  // 「白面 / 暖灰」语言，不再靠紫色描边划分区域
                  color: isDark ? AppColors.darkChatCanvas : AppColors.chatCanvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  style: AppTextStyles.body.copyWith(
                    color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '例：黄昏的海边小镇，橘色天空，远处有一座灯塔',
                    hintStyle: AppTextStyles.body.copyWith(
                      color: subtle,
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _referenceSection(isDark, subtle, accent),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _styles
                    .map(
                      (s) => ActionChip(
                        label: Text(s),
                        onPressed: () => _appendStyle(s),
                        backgroundColor:
                            isDark ? AppColors.darkChatCanvas : AppColors.chatCanvas,
                        labelStyle: AppTextStyles.label.copyWith(
                          color: isDark
                              ? AppColors.darkBodyText
                              : AppColors.bodyText,
                          fontSize: 12,
                        ),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _hasText ? _submit : null,
                    child: const Text('生成'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 参考图：选了就变成「图生图」，AI 会照着它画
  Widget _referenceSection(bool isDark, Color subtle, Color accent) {
    final path = _referencePath;

    if (path == null) {
      return Row(
        children: [
          OutlinedButton.icon(
            onPressed: _pickReference,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('选一张参考图'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '可选。选了就让 AI 照着这张图画',
              style: AppTextStyles.pageNumber.copyWith(
                color: subtle,
                fontSize: 11,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(path),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: subtle.withValues(alpha: 0.15),
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined,
                      size: 20, color: subtle),
                ),
              ),
            ),
            Positioned(
              right: -6,
              top: -6,
              child: GestureDetector(
                onTap: () => setState(() => _referencePath = null),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.deleteRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 13, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '已选参考图',
                style: AppTextStyles.label.copyWith(
                  color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'AI 会照着它画（图生图）',
                style: AppTextStyles.pageNumber.copyWith(
                  color: subtle,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
