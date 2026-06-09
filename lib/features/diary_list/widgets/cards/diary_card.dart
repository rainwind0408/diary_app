import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/diary_entry.dart';
import '../../../diary_write/services/image_service.dart';

/// 水彩风格大卡片（参考图2/5）
/// 用于水平轮播模式，展示图片缩略图+日期+心情+文字预览
class DiaryCard extends StatefulWidget {
  final DiaryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLock;
  final VoidCallback? onUnlock;

  const DiaryCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    this.onLock,
    this.onUnlock,
  });

  @override
  State<DiaryCard> createState() => _DiaryCardState();
}

class _DiaryCardState extends State<DiaryCard> {
  void _showActionMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entry = widget.entry;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkSubtleText : AppColors.subtleText)
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              if (!entry.isLocked)
                _MenuTile(
                  icon: Icons.edit_outlined,
                  label: '编辑日记',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onEdit();
                  },
                ),
              _MenuTile(
                icon: entry.isLocked ? Icons.lock_open : Icons.lock_outline,
                label: entry.isLocked ? '解锁日记' : '加密日记',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  if (entry.isLocked) {
                    widget.onUnlock?.call();
                  } else {
                    widget.onLock?.call();
                  }
                },
              ),
              _MenuTile(
                icon: Icons.delete_outline,
                label: '删除日记',
                isDark: isDark,
                color: AppColors.deleteRed,
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDelete();
                },
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '取消',
                    style: AppTextStyles.body.copyWith(
                      color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLocked = widget.entry.isLocked;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final bodyColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    // 水彩色轮换（卡片背景色）
    final cardColors = [
      AppColors.pinkLight,
      AppColors.blueLight,
      AppColors.greenLight,
      AppColors.yellowLight,
      AppColors.purpleLight,
    ];
    final cardBgColor = isDark
        ? bgColor
        : cardColors[widget.entry.id != null ? widget.entry.id! % cardColors.length : 0];

    return GestureDetector(
      onTap: isLocked ? null : widget.onEdit,
      onLongPress: _showActionMenu,
      child: Container(
        width: AppDimensions.carouselCardWidth,
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimensions.carouselCardGap / 2,
        ),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(AppDimensions.carouselCardRadius),
          boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片缩略图区域
              if (widget.entry.images.isNotEmpty)
                FutureBuilder<File>(
                  future: ImageService.getImageFile(widget.entry.images.first.path),
                  builder: (ctx, snapshot) {
                    return Container(
                      height: 100,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.15),
                          style: BorderStyle.solid,
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: snapshot.hasData
                            ? Image.file(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 32,
                                    color: accentColor.withValues(alpha: 0.3),
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 32,
                                  color: accentColor.withValues(alpha: 0.3),
                                ),
                              ),
                      ),
                    );
                  },
                ),

              // 日期 + 心情
              Row(
                children: [
                  Text(
                    DateFormatter.formatShort(widget.entry.createdAt),
                    style: AppTextStyles.cardDate.copyWith(
                      color: subtleColor,
                      fontSize: 12,
                    ),
                  ),
                  if (isLocked) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.lock, size: 12, color: accentColor),
                  ],
                  if (widget.entry.mood.isNotEmpty) ...[
                    const Spacer(),
                    Text(widget.entry.mood, style: const TextStyle(fontSize: 18)),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // 标题
              if (widget.entry.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    widget.entry.title,
                    style: AppTextStyles.cardTitle.copyWith(
                      color: textColor,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // 内容预览
              if (isLocked)
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: subtleColor),
                    const SizedBox(width: 6),
                    Text(
                      '此日记已加密',
                      style: AppTextStyles.label.copyWith(
                        color: subtleColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                )
              else
                Expanded(
                  child: Text(
                    widget.entry.content,
                    style: AppTextStyles.cardBody.copyWith(
                      color: bodyColor,
                      fontSize: 13,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              const SizedBox(height: 8),

              // 底部：标签 + 字数
              Row(
                children: [
                  if (widget.entry.tags.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: widget.entry.tags.take(3).map((tag) {
                          return Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 11,
                              color: accentColor.withValues(alpha: 0.7),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  else
                    const Spacer(),
                  if (widget.entry.wordCount > 0)
                    Text(
                      '${widget.entry.wordCount}字',
                      style: TextStyle(
                        fontSize: 11,
                        color: subtleColor.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color? color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.isDark,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (isDark ? AppColors.darkBodyText : AppColors.bodyText);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(width: 16),
            Text(label, style: AppTextStyles.body.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
