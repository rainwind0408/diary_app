import 'dart:io';
import 'package:flutter/material.dart';
import '../../../data/models/placed_image.dart';
import '../services/image_service.dart';

class PlaceableImage extends StatefulWidget {
  final PlacedImage placedImage;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<PlacedImage> onUpdate;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;
  final VoidCallback? onDoubleTapBelow;
  final VoidCallback? onDoubleTap;

  const PlaceableImage({
    super.key,
    required this.placedImage,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onUpdate,
    required this.onInteractionStart,
    required this.onInteractionEnd,
    this.onDoubleTapBelow,
    this.onDoubleTap,
  });

  @override
  State<PlaceableImage> createState() => _PlaceableImageState();
}

class _PlaceableImageState extends State<PlaceableImage> {
  double _baseScale = 1.0;
  double _baseRotation = 0.0;
  double _baseDx = 0;
  double _baseDy = 0;
  double _lastFocalPointDx = 0;
  double _lastFocalPointDy = 0;
  bool _isDragging = false;
  Future<File>? _fileFuture;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void didUpdateWidget(PlaceableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placedImage.path != widget.placedImage.path) {
      _loadFile();
    }
  }

  void _loadFile() {
    _fileFuture = ImageService.getImageFile(widget.placedImage.path);
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.placedImage;
    final displayW = img.width * img.scale;
    final displayH = img.height * img.scale;

    return Positioned(
      left: img.dx,
      top: img.dy,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 图片主体（可拖动、缩放）
          Listener(
            onPointerDown: (event) {
              widget.onInteractionStart();
              _baseScale = img.scale;
              _baseRotation = img.rotation;
              _baseDx = img.dx;
              _baseDy = img.dy;
              _lastFocalPointDx = event.position.dx;
              _lastFocalPointDy = event.position.dy;
              _isDragging = true;
            },
            onPointerMove: (event) {
              if (!_isDragging) return;
              final dx = event.position.dx - _lastFocalPointDx;
              final dy = event.position.dy - _lastFocalPointDy;
              _lastFocalPointDx = event.position.dx;
              _lastFocalPointDy = event.position.dy;

              final updated = PlacedImage(
                path: img.path,
                dx: img.dx + dx,
                dy: img.dy + dy,
                width: img.width,
                height: img.height,
                rotation: img.rotation,
                scale: img.scale,
              );
              widget.onUpdate(updated);
            },
            onPointerUp: (event) {
              _isDragging = false;
              widget.onInteractionEnd();
            },
            onPointerCancel: (event) {
              _isDragging = false;
              widget.onInteractionEnd();
            },
            child: GestureDetector(
              onTap: widget.onTap,
              onDoubleTap: widget.onDoubleTap,
              onScaleUpdate: (details) {
                if (details.pointerCount >= 2) {
                  // 双指：缩放和旋转
                  final newScale = (_baseScale * details.scale).clamp(0.3, 3.0);
                  final newRotation = _baseRotation + details.rotation;

                  // 从中心缩放：调整位置使图片中心保持不变
                  final oldCenterX = _baseDx + (img.width * _baseScale) / 2;
                  final oldCenterY = _baseDy + (img.height * _baseScale) / 2;
                  final newDisplayW = img.width * newScale;
                  final newDisplayH = img.height * newScale;
                  final newDx = oldCenterX - newDisplayW / 2;
                  final newDy = oldCenterY - newDisplayH / 2;

                  final updated = PlacedImage(
                    path: img.path,
                    dx: newDx,
                    dy: newDy,
                    width: img.width,
                    height: img.height,
                    rotation: newRotation,
                    scale: newScale,
                  );
                  widget.onUpdate(updated);
                }
              },
              child: Transform.rotate(
                angle: img.rotation,
                child: SizedBox(
                  width: displayW,
                  height: displayH,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(2, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FutureBuilder<File>(
                      future: _fileFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        return Image.file(
                          snapshot.data!,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 选中态：蓝色边框（跟随旋转）
          if (widget.isSelected)
            Positioned(
              left: 0,
              top: 0,
              child: Transform.rotate(
                angle: img.rotation,
                child: Container(
                  width: displayW,
                  height: displayH,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          // 删除按钮（独立于旋转，固定在右上角）
          if (widget.isSelected)
            Positioned(
              right: -12,
              top: -12,
              child: GestureDetector(
                onTap: widget.onDelete,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      size: 18, color: Colors.white),
                ),
              ),
            ),
          // 图片下方的双击区域
          if (widget.onDoubleTapBelow != null)
            Positioned(
              left: 0,
              top: displayH,
              width: displayW,
              height: 28,
              child: GestureDetector(
                onDoubleTap: widget.onDoubleTapBelow,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
