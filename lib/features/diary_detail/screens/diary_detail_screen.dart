import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/watercolor_background.dart';
import '../../../data/models/diary_entry.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../diary_write/providers/diary_write_provider.dart';
import '../../diary_write/screens/diary_write_screen.dart';
import '../../weather/providers/seasonal_provider.dart';
import '../widgets/detail_card.dart';

/// 日记详情页（参考图1）
/// 全屏沉浸式展示，支持 Previous/Next 翻页
class DiaryDetailScreen extends StatefulWidget {
  final List<DiaryEntry> allEntries;
  final int initialIndex;

  const DiaryDetailScreen({
    super.key,
    required this.allEntries,
    required this.initialIndex,
  });

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    // 安全检查：确保索引在有效范围内
    _currentIndex = widget.initialIndex.clamp(0, (widget.allEntries.length - 1).clamp(0, widget.allEntries.length));
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.allEntries.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _editEntry() {
    developer.log('_editEntry called, currentIndex=$_currentIndex, total=${widget.allEntries.length}');
    if (_currentIndex < 0 || _currentIndex >= widget.allEntries.length) {
      developer.log('_editEntry: index out of bounds');
      return;
    }
    final entry = widget.allEntries[_currentIndex];
    developer.log('_editEntry: entry id=${entry.id}, title=${entry.title}, isLocked=${entry.isLocked}');
    if (entry.isLocked) return;
    try {
      context.read<DiaryWriteProvider>().loadForEdit(entry);
      developer.log('_editEntry: loadForEdit success, navigating to write screen');
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DiaryWriteScreen()),
      );
    } catch (e, st) {
      developer.log('_editEntry ERROR', error: e, stackTrace: st);
    }
  }

  Future<void> _deleteEntry() async {
    final entry = widget.allEntries[_currentIndex];
    if (entry.id == null) return;

    final confirmed = await showConfirmDialog(
      context,
      title: '删除日记',
      message: '确定要删除这篇日记吗？',
    );
    if (!mounted || !confirmed) return;

    try {
      final repo = DiaryRepository();
      await repo.deleteEntry(entry.id!);
      if (!mounted) return;

      // 从列表中移除并更新状态
      setState(() {
        widget.allEntries.removeAt(_currentIndex);
        if (widget.allEntries.isEmpty) {
          Navigator.of(context).pop();
          return;
        }
        if (_currentIndex >= widget.allEntries.length) {
          _currentIndex = widget.allEntries.length - 1;
        }
      });

      Toast().show(context, '日记已删除', ToastType.success);

      // 列表为空时返回
      if (widget.allEntries.isEmpty && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Toast().show(context, '删除失败，请重试', ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 空列表时直接返回
    if (widget.allEntries.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: WatercolorBackground(
          child: Center(
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entry = widget.allEntries[_currentIndex];
    final weather = context.watch<SeasonalProvider>().weatherData;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WatercolorBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 顶部导航栏
              _buildTopBar(isDark, entry, weather),

              // 日期+天气信息
              _buildDateInfo(isDark, entry, weather),

              // 卡片内容区域
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.allEntries.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: DetailCard(entry: widget.allEntries[index]),
                    );
                  },
                ),
              ),

              // 底部 Previous/Next 按钮
              _buildBottomNav(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark, DiaryEntry entry, dynamic weather) {
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final cardBg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                size: 20, color: isDark ? AppColors.darkBodyText : AppColors.bodyText),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          // 页码指示
          Text(
            '${_currentIndex + 1} / ${widget.allEntries.length}',
            style: TextStyle(
              fontSize: 13,
              color: subtleColor.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          // 编辑按钮（高对比度样式）
          if (!entry.isLocked)
            GestureDetector(
              onTap: _editEntry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      '编辑',
                      style: TextStyle(
                        fontSize: 13,
                        color: accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 删除按钮
          if (!entry.isLocked)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: _deleteEntry,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.deleteRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.deleteRed.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(Icons.delete_outline, size: 16, color: AppColors.deleteRed),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(bool isDark, DiaryEntry entry, dynamic weather) {
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final weekdays = ['日', '一', '二', '三', '四', '五', '六'];
    final weekday = weekdays[entry.createdAt.weekday % 7];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        children: [
          // 日期
          Text(
            '${entry.createdAt.year}.${entry.createdAt.month.toString().padLeft(2, '0')}.${entry.createdAt.day.toString().padLeft(2, '0')}',
            style: AppTextStyles.handwritingTitle.copyWith(
              color: textColor,
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 10),
          // 天气图标
          if (weather != null)
            Text(weather.emoji, style: const TextStyle(fontSize: 18)),
          const Spacer(),
          // 星期
          Text(
            '星期$weekday',
            style: TextStyle(
              fontSize: 14,
              color: subtleColor,
            ),
          ),
          const SizedBox(width: 10),
          // 心情
          if (entry.mood.isNotEmpty)
            Text(entry.mood, style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final canGoBack = _currentIndex > 0;
    final canGoForward = _currentIndex < widget.allEntries.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous 按钮
          _NavButton(
            label: 'Previous',
            icon: Icons.chevron_left,
            enabled: canGoBack,
            accentColor: accentColor,
            subtleColor: subtleColor,
            onTap: canGoBack ? _goToPrevious : null,
          ),
          // Next 按钮
          _NavButton(
            label: 'Next',
            icon: Icons.chevron_right,
            enabled: canGoForward,
            accentColor: accentColor,
            subtleColor: subtleColor,
            onTap: canGoForward ? _goToNext : null,
            isForward: true,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final Color accentColor;
  final Color subtleColor;
  final VoidCallback? onTap;
  final bool isForward;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.accentColor,
    required this.subtleColor,
    this.onTap,
    this.isForward = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: enabled
              ? accentColor.withValues(alpha: 0.12)
              : subtleColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: enabled
                ? accentColor.withValues(alpha: 0.3)
                : subtleColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isForward) ...[
              Icon(icon, size: 18, color: enabled ? accentColor : subtleColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: enabled ? accentColor : subtleColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isForward) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 18, color: enabled ? accentColor : subtleColor),
            ],
          ],
        ),
      ),
    );
  }
}
