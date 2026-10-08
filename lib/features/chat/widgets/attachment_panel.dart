import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/chat_attachment.dart';
import '../services/attachment_store.dart';

/// 附件来源
enum AttachmentSource {
  galleryImage,
  galleryVideo,
  file;

  String get label {
    switch (this) {
      case AttachmentSource.galleryImage:
        return '相册图片';
      case AttachmentSource.galleryVideo:
        return '相册视频';
      case AttachmentSource.file:
        return '文件';
    }
  }

  IconData get icon {
    switch (this) {
      case AttachmentSource.galleryImage:
        return Icons.photo_library_outlined;
      case AttachmentSource.galleryVideo:
        return Icons.videocam_outlined;
      case AttachmentSource.file:
        return Icons.insert_drive_file_outlined;
    }
  }
}

/// 附件选择：先选来源，再调用系统选择器，最后统一导入到应用私有目录。
class AttachmentPicker {
  AttachmentPicker._();

  /// 弹出面板并完成选择。返回已落盘的附件；用户取消时返回空列表。
  static Future<List<ChatAttachment>> show(BuildContext context) async {
    final source = await showModalBottomSheet<AttachmentSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SourceSheet(),
    );
    if (source == null) return const [];
    if (!context.mounted) return const [];
    return _pick(context, source);
  }

  /// 只选**一张图片**，返回原始路径（不导入私有目录）。
  ///
  /// 给「AI 画图 → 参考图」用：参考图只在这一次请求里读一次，没必要占附件目录，
  /// 也不该被会话的孤儿清理扫到。用户取消或失败都返回 null。
  ///
  /// 顺带压到 1600px / q90：手机原图动辄 4000px、好几 MB，base64 之后更大，
  /// 拿去做图生图既慢又容易撞网关的体积上限。
  static Future<String?> pickSingleImagePath() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      return picked?.path;
    } catch (_) {
      return null;
    }
  }

  static Future<List<ChatAttachment>> _pick(
    BuildContext context,
    AttachmentSource source,
  ) async {
    final picked = <XFile>[];
    try {
      switch (source) {
        case AttachmentSource.galleryImage:
          picked.addAll(await ImagePicker().pickMultiImage());
        case AttachmentSource.galleryVideo:
          final video = await ImagePicker().pickVideo(
            source: ImageSource.gallery,
          );
          if (video != null) picked.add(video);
        case AttachmentSource.file:
          picked.addAll(await openFiles());
      }
    } catch (e) {
      _toast(context, '选择失败：$e');
      return const [];
    }

    if (picked.isEmpty) return const [];

    final result = <ChatAttachment>[];
    for (final xfile in picked) {
      try {
        result.add(await AttachmentStore.import(
          xfile.path,
          name: xfile.name,
          mimeType: xfile.mimeType,
        ));
      } on AttachmentTooLargeException catch (e) {
        _toast(context, e.toString());
      } catch (e) {
        _toast(context, '导入失败：$e');
      }
    }
    return result;
  }

  static void _toast(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkPink : AppColors.pinkDark;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;

    return Container(
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color:
                    (isDark ? AppColors.darkSubtleText : AppColors.subtleText)
                        .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: AttachmentSource.values.map((s) {
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context, s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(s.icon, color: accent, size: 24),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.label,
                          style: AppTextStyles.label.copyWith(color: textColor),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '单个附件上限 '
                '${(AttachmentStore.maxBytes / (1024 * 1024)).toStringAsFixed(0)}MB。'
                '能否识别取决于你所选模型是否支持该类型。',
                textAlign: TextAlign.center,
                style: AppTextStyles.pageNumber.copyWith(
                  color:
                      isDark ? AppColors.darkSubtleText : AppColors.subtleText,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
