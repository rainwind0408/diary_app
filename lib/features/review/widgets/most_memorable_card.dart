import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/diary_entry.dart';
import '../../diary_detail/screens/diary_detail_screen.dart';

/// 「最值得重读」卡片
///
/// 回顾页原本通篇是数字与图表，**一个字的日记内容都不显示**——
/// 这是它「像报表而不像回顾」的根本原因。这张卡把正文请回来：
/// 挑出字数最多的那一篇，露出开头两行，并给一个明确的「重读」出口。
///
/// 选「最长的一篇」而不是「最近的一篇」，是因为长文通常意味着
/// 那天有更多想说的话 —— 更可能是值得回头看的时刻。
class MostMemorableCard extends StatelessWidget {
  final DiaryEntry entry;

  /// 「重读」回调；不传则整卡不可点
  final VoidCallback? onRead;

  const MostMemorableCard({
    super.key,
    required this.entry,
    this.onRead,
  });

  /// 摘要最多显示多少字
  static const int _excerptLength = 62;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pinkColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor =
        isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    final excerpt = _buildExcerpt(entry.content);

    return GestureDetector(
      onTap: onRead,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：标签 + 日期
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: pinkColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.book_outlined, size: 12, color: pinkColor),
                      const SizedBox(width: 4),
                      Text(
                        '最值得重读',
                        style: TextStyle(
                          fontSize: 11,
                          color: pinkColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormatter.formatShort(entry.createdAt),
                  style: TextStyle(fontSize: 11, color: subtleColor),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 正文摘要
            if (excerpt.isNotEmpty)
              Text(
                '「$excerpt」',
                style: AppTextStyles.body.copyWith(
                  color: textColor,
                  fontSize: 14,
                  height: 1.7,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              )
            else
              Text(
                '（这一篇没有留下文字）',
                style: AppTextStyles.body.copyWith(
                  color: subtleColor,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),

            const SizedBox(height: 14),

            // 底部：说明 + 重读按钮
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: subtleColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '这是你写得最长的一篇，共 ${entry.wordCount} 字',
                    style: TextStyle(
                      fontSize: 11,
                      color: subtleColor.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                if (onRead != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '重读',
                        style: TextStyle(
                          fontSize: 12,
                          color: pinkColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 10, color: pinkColor),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 把正文压成一句可读的摘要
  ///
  /// 原文可能有换行、多段空行、以及贴在文字里的图片占位符，
  /// 这里统一把连续空白折叠成单空格，再按字数截断。
  ///
  /// **还要剥掉首尾的引号**：卡片渲染时会自己包一层 `「」`，
  /// 如果原文本身就以 `「` 开头（很多日记确实这么写），
  /// 拼出来就是 `「「如果…」` 这种残缺的嵌套引号 ——
  /// 卡片外的 `」` 只能闭合卡片那一层，里面那层永远闭不上。
  static String _buildExcerpt(String content) {
    var normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    normalized = _stripWrappingQuotes(normalized);
    if (normalized.isEmpty) return '';
    if (normalized.length <= _excerptLength) return normalized;
    return '${normalized.substring(0, _excerptLength)}…';
  }

  /// 去掉首尾成对的引号（中英文都处理），只剥一层
  static String _stripWrappingQuotes(String s) {
    const pairs = [
      ('「', '」'),
      ('“', '”'),
      ('"', '"'),
      ('『', '』'),
      ("'", "'"),
    ];
    for (final (open, close) in pairs) {
      if (s.length >= 2 && s.startsWith(open) && s.endsWith(close)) {
        return s.substring(1, s.length - 1).trim();
      }
    }
    // 只有开头没结尾（截断残留、或作者漏写）：也把开头那个剥掉
    for (final (open, _) in pairs) {
      if (s.startsWith(open)) return s.substring(1).trim();
    }
    return s;
  }
}

/// 打开「最值得重读」那一篇
///
/// 独立成一个入口函数，是因为用户可能从两个地方点进来
/// （回顾页卡片、年报末页），避免两处各写一遍路由逻辑。
///
/// 复用 `DiaryDetailScreen`（传单元素列表）而不是另写一个只读页 ——
/// 它已经处理好了媒体渲染、加密日记、编辑入口等所有细节。
Future<void> openHighlightEntry(
  BuildContext context,
  DiaryEntry entry,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DiaryDetailScreen(
        allEntries: [entry],
        initialIndex: 0,
      ),
    ),
  );
}
