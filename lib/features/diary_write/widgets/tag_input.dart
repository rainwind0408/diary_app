import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TagInput extends StatefulWidget {
  final List<String> tags;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const TagInput({
    super.key,
    required this.tags,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final TextEditingController _controller = TextEditingController();
  bool _showInput = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final tag = _controller.text.trim();
    if (tag.isNotEmpty) {
      widget.onAdd(tag.startsWith('#') ? tag.substring(1) : tag);
      _controller.clear();
    }
    setState(() => _showInput = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Existing tags
        ...widget.tags.map((tag) {
          return Chip(
            label: Text('#$tag', style: TextStyle(fontSize: 12, color: goldColor)),
            backgroundColor: goldColor.withValues(alpha: 0.1),
            side: BorderSide(color: goldColor.withValues(alpha: 0.3)),
            deleteIcon: Icon(Icons.close, size: 14, color: goldColor),
            onDeleted: () => widget.onRemove(tag),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          );
        }),

        // Add button or input
        if (_showInput)
          SizedBox(
            width: 100,
            height: 32,
            child: TextField(
              controller: _controller,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              style: TextStyle(fontSize: 12, color: goldColor),
              decoration: InputDecoration(
                hintText: '标签名',
                hintStyle: TextStyle(fontSize: 12, color: subtleColor),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: goldColor.withValues(alpha: 0.3)),
                ),
                isDense: true,
              ),
            ),
          )
        else if (widget.tags.length < 10)
          GestureDetector(
            onTap: () => setState(() => _showInput = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: subtleColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14, color: subtleColor),
                  const SizedBox(width: 2),
                  Text('添加标签', style: TextStyle(fontSize: 12, color: subtleColor)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
