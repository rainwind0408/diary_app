import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/template.dart';

class CreateTemplateDialog extends StatefulWidget {
  const CreateTemplateDialog({super.key});

  static Future<DiaryTemplate?> show(BuildContext context) {
    return showDialog<DiaryTemplate>(
      context: context,
      builder: (_) => const CreateTemplateDialog(),
    );
  }

  @override
  State<CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<CreateTemplateDialog> {
  static const _emojiOptions = [
    '📝', '💡', '❤️', '🌟', '🎯', '🤔', '📖', '✨',
    '🌈', '🎨', '💪', '🙏', '☀️', '🌙', '🎵', '🍵',
    '📷', '🏠', '💼', '🎓',
  ];

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedEmoji = _emojiOptions[0];
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validate);
    _contentController.addListener(_validate);
  }

  void _validate() {
    final can =
        _nameController.text.trim().isNotEmpty && _contentController.text.trim().isNotEmpty;
    if (can != _canSave) setState(() => _canSave = can);
  }

  void _save() {
    final template = DiaryTemplate(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      icon: _selectedEmoji,
      description: _descController.text.trim(),
      content: _contentController.text,
      category: TemplateCategory.custom,
      isDefault: false,
      isCustom: true,
    );
    Navigator.pop(context, template);
  }

  @override
  void dispose() {
    _nameController.removeListener(_validate);
    _nameController.dispose();
    _descController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final accentColor = isDark ? AppColors.darkPink : AppColors.pink;

    return AlertDialog(
      backgroundColor: bgColor,
      title: Text(
        '创建模板',
        style: AppTextStyles.heading.copyWith(color: textColor, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 名称
            Text('模板名称', style: AppTextStyles.label.copyWith(color: subtleColor)),
            const SizedBox(height: 4),
            TextField(
              controller: _nameController,
              style: AppTextStyles.body.copyWith(color: textColor),
              decoration: _inputDecoration(
                hint: '输入模板名称',
                isDark: isDark,
                accentColor: accentColor,
              ),
            ),
            const SizedBox(height: 16),

            // 图标
            Text('选择图标', style: AppTextStyles.label.copyWith(color: subtleColor)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojiOptions.map((emoji) {
                final selected = emoji == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? accentColor.withValues(alpha: 0.15)
                          : (isDark
                              ? AppColors.darkPageBackground
                              : AppColors.pageBackground),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? accentColor
                            : accentColor.withValues(alpha: 0.2),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 描述
            Text('描述（选填）', style: AppTextStyles.label.copyWith(color: subtleColor)),
            const SizedBox(height: 4),
            TextField(
              controller: _descController,
              style: AppTextStyles.body.copyWith(color: textColor),
              decoration: _inputDecoration(
                hint: '简短描述模板用途',
                isDark: isDark,
                accentColor: accentColor,
              ),
            ),
            const SizedBox(height: 16),

            // 内容
            Text('模板内容', style: AppTextStyles.label.copyWith(color: subtleColor)),
            const SizedBox(height: 4),
            TextField(
              controller: _contentController,
              maxLines: 6,
              style: AppTextStyles.body.copyWith(color: textColor, fontSize: 14),
              decoration: _inputDecoration(
                hint: '输入模板正文，如：\n【今日完成】\n\n【明日计划】',
                isDark: isDark,
                accentColor: accentColor,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: subtleColor)),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          style: FilledButton.styleFrom(
            backgroundColor: _canSave ? accentColor : subtleColor.withValues(alpha: 0.3),
            disabledBackgroundColor: subtleColor.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            '保存',
            style: TextStyle(color: _canSave ? Colors.white : subtleColor),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool isDark,
    required Color accentColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.body.copyWith(
        color: isDark ? AppColors.darkPlaceholderText : AppColors.placeholderText,
        fontSize: 14,
      ),
      filled: true,
      fillColor: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor),
      ),
    );
  }
}
