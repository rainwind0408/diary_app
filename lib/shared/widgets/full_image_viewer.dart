import 'dart:io';
import 'package:flutter/material.dart';

/// 通用全屏图片查看器
///
/// 黑底沉浸式展示 + 双指缩放，点击右上角关闭。
/// 日记详情页与首页封面图卡片共用，避免各写一份。
class FullImageViewer extends StatelessWidget {
  final File file;
  final String? heroTag;

  const FullImageViewer({super.key, required this.file, this.heroTag});

  /// 以全屏弹窗形式打开图片
  static Future<void> show(
    BuildContext context,
    File file, {
    String? heroTag,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => FullImageViewer(file: file, heroTag: heroTag),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: heroTag == null
                  ? Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const _BrokenImage(),
                    )
                  : Hero(
                      tag: heroTag!,
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const _BrokenImage(),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
          SizedBox(height: 12),
          Text('图片已无法读取', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}
