import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/diary_entry.dart';
import '../cards/diary_card.dart';

/// 水平卡片轮播视图（参考图2/5）
/// 替代原来的网格视图，使用 PageView 实现左右滑动
class CardFlowView extends StatefulWidget {
  final List<DiaryEntry> entries;
  final void Function(DiaryEntry) onEdit;
  final void Function(DiaryEntry) onDelete;
  final void Function(DiaryEntry)? onLock;
  final void Function(DiaryEntry)? onUnlock;

  const CardFlowView({
    super.key,
    required this.entries,
    required this.onEdit,
    required this.onDelete,
    this.onLock,
    this.onUnlock,
  });

  @override
  State<CardFlowView> createState() => _CardFlowViewState();
}

class _CardFlowViewState extends State<CardFlowView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: 0,
    );
  }

  @override
  void didUpdateWidget(CardFlowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length) {
      // 如果当前页超出范围，重置到第一页
      if (_currentPage >= widget.entries.length && widget.entries.isNotEmpty) {
        _currentPage = 0;
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;

    return Column(
      children: [
        // 卡片轮播
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.entries.length,
            onPageChanged: (index) {
              HapticFeedback.lightImpact();
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final entry = widget.entries[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                child: DiaryCard(
                  entry: entry,
                  onEdit: () => widget.onEdit(entry),
                  onDelete: () => widget.onDelete(entry),
                  onLock: () => widget.onLock?.call(entry),
                  onUnlock: () => widget.onUnlock?.call(entry),
                ),
              );
            },
          ),
        ),

        // 分页指示器
        if (widget.entries.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.entries.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? accentColor
                        : accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
