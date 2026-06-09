import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/repositories/diary_repository.dart';

class TagCloud extends StatefulWidget {
  final String? selectedTag;
  final ValueChanged<String?> onTagSelected;
  final DateTime? date;

  const TagCloud({
    super.key,
    this.selectedTag,
    required this.onTagSelected,
    this.date,
  });

  @override
  State<TagCloud> createState() => _TagCloudState();
}

class _TagCloudState extends State<TagCloud> {
  final DiaryRepository _repository = DiaryRepository();
  Map<String, int> _tagCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void didUpdateWidget(TagCloud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _loadTags();
    }
  }

  Future<void> _loadTags() async {
    final tags = widget.date != null
        ? await _repository.getTagsByDate(widget.date!)
        : await _repository.getAllTags();
    if (mounted) {
      setState(() {
        _tagCounts = tags;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _tagCounts.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    final sortedTags = _tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "All" tag
          _TagChip(
            label: '全部',
            count: null,
            isSelected: widget.selectedTag == null,
            goldColor: goldColor,
            subtleColor: subtleColor,
            isDark: isDark,
            onTap: () => widget.onTagSelected(null),
          ),
          const SizedBox(width: 6),
          // Tag chips
          ...sortedTags.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _TagChip(
                label: '#${entry.key}',
                count: entry.value,
                isSelected: widget.selectedTag == entry.key,
                goldColor: goldColor,
                subtleColor: subtleColor,
                isDark: isDark,
                onTap: () => widget.onTagSelected(
                  widget.selectedTag == entry.key ? null : entry.key,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool isSelected;
  final Color goldColor;
  final Color subtleColor;
  final bool isDark;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    this.count,
    required this.isSelected,
    required this.goldColor,
    required this.subtleColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = count != null ? '$label($count)' : label;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? goldColor
              : isDark
                  ? AppColors.darkCardBackgroundAlt
                  : AppColors.cardBackgroundAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? goldColor : goldColor.withValues(alpha: 0.25),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          displayLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? (isDark ? AppColors.darkCardBackground : AppColors.cardBackground)
                : goldColor,
          ),
        ),
      ),
    );
  }
}
