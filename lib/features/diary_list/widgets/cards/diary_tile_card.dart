import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/diary_entry.dart';

class DiaryTileCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const DiaryTileCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final bodyColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        onLongPress: onLongPress != null
            ? () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: goldColor.withValues(alpha: 0.06),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mood + lock + date
                Row(
                  children: [
                    if (entry.mood.isNotEmpty)
                      Text(entry.mood, style: const TextStyle(fontSize: 20)),
                    if (entry.isLocked) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock, size: 14, color: goldColor),
                    ],
                    const Spacer(),
                    Text(
                      DateFormatter.formatShort(entry.createdAt),
                      style: AppTextStyles.cardDate.copyWith(
                        color: subtleColor.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                if (entry.title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      entry.title,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: textColor,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // Content preview
                if (!entry.isLocked)
                  Text(
                    entry.content,
                    style: AppTextStyles.cardBody.copyWith(
                      color: bodyColor,
                      fontSize: 13,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: subtleColor),
                      const SizedBox(width: 6),
                      Text(
                        '已加密',
                        style: AppTextStyles.label.copyWith(
                          color: subtleColor,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                const Spacer(),

                // Bottom row: tags + word count
                Row(
                  children: [
                    if (entry.tags.isNotEmpty)
                      Expanded(
                        child: Text(
                          entry.tags.take(3).map((t) => '#$t').join(' '),
                          style: TextStyle(
                            fontSize: 11,
                            color: goldColor.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (entry.stickers.isNotEmpty) ...[
                      Icon(Icons.emoji_emotions_outlined,
                          size: 12, color: subtleColor.withValues(alpha: 0.4)),
                      const SizedBox(width: 2),
                      Text(
                        '${entry.stickers.length}',
                        style: AppTextStyles.cardDate.copyWith(
                          color: subtleColor.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                      ),
                    ],
                    if (entry.wordCount > 0) ...[
                      if (entry.stickers.isNotEmpty) const SizedBox(width: 6),
                      Text(
                        '${entry.wordCount}字',
                        style: AppTextStyles.cardDate.copyWith(
                          color: subtleColor.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
