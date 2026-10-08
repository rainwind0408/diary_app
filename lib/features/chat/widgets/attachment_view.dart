import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/chat_attachment.dart';
import '../services/gallery_saver.dart';

/// 气泡内的附件展示。
///
/// - 图片：圆角缩略图，点击全屏查看
/// - 视频：缩略图 + 播放角标，点击交给系统用其他应用打开
/// - 文件：图标 + 文件名 + 大小，点击同上
class AttachmentView extends StatelessWidget {
  final List<ChatAttachment> attachments;
  final bool isUser;

  /// 图片缩略图边长。默认 92 —— 用户随手发的图看个大概就够，
  /// 点开有全屏；AI 生图的结果是这次对话的主角，调用方会传大一些。
  final double thumbSize;

  const AttachmentView({
    super.key,
    required this.attachments,
    this.isUser = false,
    this.thumbSize = defaultThumb,
  });

  static const double defaultThumb = 92;

  /// AI 生图结果的缩略图边长
  static const double largeThumb = 168;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final images = attachments.where((a) => a.isImage).toList();
    final others = attachments.where((a) => !a.isImage).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty) _imageGrid(context, images),
        if (images.isNotEmpty && others.isNotEmpty)
          const SizedBox(height: 6),
        ...others.map((a) => Padding(
              padding: EdgeInsets.only(top: a == others.first ? 0 : 6),
              child: _attachmentCard(context, a),
            )),
      ],
    );
  }

  Widget _imageGrid(BuildContext context, List<ChatAttachment> images) {
    final size = thumbSize;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: images
          .map((a) => GestureDetector(
                onTap: () => showImagePreview(context, a),
                // 长按存图。内层的手势会赢过 ChatBubble 外层那个「长按出消息菜单」，
                // 所以按在图上和按在气泡别处是两套菜单，互不打扰。
                onLongPress: () => showImageActions(context, a),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(a.path),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: size,
                      height: size,
                      color: AppColors.subtleText.withValues(alpha: 0.12),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 22,
                        color: AppColors.subtleText,
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _attachmentCard(BuildContext context, ChatAttachment attachment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 文件/视频卡是「白色气泡里的一块内嵌片」：用暖灰画布色当底，
    // 否则和气泡同色，只能靠一条描边才能看出边界（这正是之前显乱的原因）
    final surface =
        isDark ? AppColors.darkChatCanvas : AppColors.chatCanvas;
    final textColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final subtle = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return GestureDetector(
      onTap: () => openWithOtherApp(attachment),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (attachment.isVideo)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Image.file(
                      File(attachment.path),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 44,
                        height: 44,
                        color: subtle.withValues(alpha: 0.15),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.movie_outlined,
                          size: 20,
                          color: subtle,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.28),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: subtle.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  size: 20,
                  color: subtle,
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attachment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: textColor,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${attachment.kind.label} · ${attachment.sizeLabel}',
                    style: AppTextStyles.pageNumber.copyWith(
                      color: subtle,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 全屏查看图片（支持双指缩放）
Future<void> showImagePreview(
  BuildContext context,
  ChatAttachment attachment,
) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (dialogContext) => GestureDetector(
      onTap: () => Navigator.pop(dialogContext),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Image.file(
                  File(attachment.path),
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 交给系统用其他应用打开（视频 / 文件）。
///
/// 项目没有内置播放器与文件查看器，走系统分享面板让用户挑应用，
/// 比「点了没反应」友好得多。
Future<void> openWithOtherApp(ChatAttachment attachment) async {
  try {
    await Share.shareXFiles([XFile(attachment.path)], text: attachment.name);
  } catch (_) {
    // 分享失败（例如没有可处理的应用）不打断聊天
  }
}

enum _ImageAction { save, share }

/// 长按图片弹出的操作菜单。
///
/// 「保存到相册」是最常用的一个（AI 生图的结果要能留下来），
/// 所以放第一位；分享是顺带的。
Future<void> showImageActions(
  BuildContext context,
  ChatAttachment attachment,
) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;

  final action = await showModalBottomSheet<_ImageAction>(
    context: context,
    backgroundColor:
        isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      Widget item(_ImageAction value, IconData icon, String label) {
        return ListTile(
          leading: Icon(icon, size: 20, color: textColor),
          title: Text(
            label,
            style: AppTextStyles.body.copyWith(color: textColor),
          ),
          onTap: () => Navigator.pop(sheetContext, value),
        );
      }

      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
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
            const SizedBox(height: 6),
            item(_ImageAction.save, Icons.download_rounded, '保存到相册'),
            item(_ImageAction.share, Icons.ios_share_rounded, '分享'),
            const SizedBox(height: 6),
          ],
        ),
      );
    },
  );

  if (action == null || !context.mounted) return;

  switch (action) {
    case _ImageAction.save:
      await saveImageToGallery(context, attachment);
    case _ImageAction.share:
      await openWithOtherApp(attachment);
  }
}

/// 保存到系统相册，并给出明确的成功 / 失败反馈。
Future<void> saveImageToGallery(
  BuildContext context,
  ChatAttachment attachment,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final ext = GallerySaver.extensionOf(attachment.path);
    await GallerySaver.saveImage(
      attachment.path,
      name: GallerySaver.suggestedName(extension: ext),
      mimeType: attachment.mimeType.isEmpty
          ? 'image/${ext.replaceFirst('.', '')}'
          : attachment.mimeType,
    );
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('已保存到相册')));
  } catch (e) {
    final raw = e.toString();
    const prefix = 'Exception: ';
    final message = raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('保存失败：$message')));
  }
}
