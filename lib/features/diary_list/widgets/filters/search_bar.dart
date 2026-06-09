import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class DiarySearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;

  const DiarySearchBar({
    super.key,
    required this.onSearch,
    required this.onClear,
  });

  @override
  State<DiarySearchBar> createState() => _DiarySearchBarState();
}

class _DiarySearchBarState extends State<DiarySearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onSearch(value);
    });
  }

  void _onClear() {
    _controller.clear();
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackgroundAlt : AppColors.cardBackgroundAlt;
    final borderColor = isDark ? AppColors.darkDividerLine : AppColors.dividerLine;
    final hintColor = isDark ? AppColors.darkPlaceholderText : AppColors.placeholderText;
    final textColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        style: AppTextStyles.body.copyWith(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          hintText: '搜索日记标题或内容...',
          hintStyle: AppTextStyles.body.copyWith(color: hintColor, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: hintColor, size: 20),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  onPressed: _onClear,
                  icon: Icon(Icons.close, color: hintColor, size: 18),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
