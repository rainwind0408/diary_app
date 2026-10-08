import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/chat_attachment.dart';

/// 输入框上方的「待发送附件」预览条。
///
/// 每个附件右上角有删除按钮；图片显示真实缩略图，视频/文件显示图标与名称。
///
/// **高度必须是内容撑出来的，不能写死。** 早先这里是 `height: _tile + 26`，
/// 只给「缩略图 + 一行文件名」留了 78 —— 而文件名那一行的实际行高约 14
/// （fontSize 10 × M3 bodyMedium 的 height 1.43，`Text` 会把主题的行高继承下来），
/// 64 + 3 + 14 = 81，于是**每加一个附件就报一次 BOTTOM OVERFLOWED BY 3.0 PIXELS**。
/// 换成自适应布局后，行高随系统字号变化也不会再溢出。
class PendingAttachmentBar extends StatelessWidget {
  final List<ChatAttachment> attachments;
  final ValueChanged<ChatAttachment> onRemove;

  const PendingAttachmentBar({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  static const double _tile = 64;

  /// 删除角标从缩略图右上角探出的距离
  static const double _badgeOverhang = 6;

  /// 缩略图与文件名之间的间距
  static const double _labelGap = 3;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      // 和输入条同色，避免底部出现第二条色带
      color: AppColors.chatCanvasOf(context),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // 角标要探出缩略图，给它留出空间 —— 否则会被滚动视口裁掉半个圆
        padding: const EdgeInsets.only(
          top: _badgeOverhang,
          right: _badgeOverhang,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < attachments.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _tileFor(isDark, attachments[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tileFor(bool isDark, ChatAttachment attachment) {
    return SizedBox(
      width: _tile,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _preview(isDark, attachment),
              Positioned(
                right: -_badgeOverhang,
                top: -_badgeOverhang,
                child: GestureDetector(
                  onTap: () => onRemove(attachment),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.deleteRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _labelGap),
          Text(
            attachment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.pageNumber.copyWith(
              color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(bool isDark, ChatAttachment attachment) {
    final radius = BorderRadius.circular(10);

    if (attachment.isImage) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(attachment.path),
          width: _tile,
          height: _tile,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(
            isDark,
            Icons.broken_image_outlined,
            radius,
          ),
        ),
      );
    }

    if (attachment.isVideo) {
      return ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Image.file(
              File(attachment.path),
              width: _tile,
              height: _tile,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(
                isDark,
                Icons.movie_outlined,
                radius,
              ),
            ),
            Container(
              width: _tile,
              height: _tile,
              color: Colors.black.withValues(alpha: 0.28),
              alignment: Alignment.center,
              child: const Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      );
    }

    return _placeholder(isDark, Icons.insert_drive_file_outlined, radius);
  }

  Widget _placeholder(bool isDark, IconData icon, BorderRadius radius) {
    return Container(
      width: _tile,
      height: _tile,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkChatBubble : AppColors.chatBubble,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 24,
        color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
      ),
    );
  }
}
