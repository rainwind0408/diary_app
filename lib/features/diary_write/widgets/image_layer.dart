import 'package:flutter/material.dart';
import '../../../data/models/placed_image.dart';
import 'placeable_image.dart';

class ImageLayer extends StatefulWidget {
  final List<PlacedImage> images;
  final ValueChanged<List<PlacedImage>> onImagesChanged;
  final VoidCallback onInteractionStart;
  final VoidCallback onInteractionEnd;
  final ValueChanged<PlacedImage>? onDoubleTapBelowImage;
  final ValueChanged<PlacedImage>? onImageView;

  const ImageLayer({
    super.key,
    required this.images,
    required this.onImagesChanged,
    required this.onInteractionStart,
    required this.onInteractionEnd,
    this.onDoubleTapBelowImage,
    this.onImageView,
  });

  @override
  State<ImageLayer> createState() => _ImageLayerState();
}

class _ImageLayerState extends State<ImageLayer> {
  int _selectedIndex = -1;

  void _updateImage(int index, PlacedImage updated) {
    final list = List<PlacedImage>.from(widget.images);
    list[index] = updated;
    widget.onImagesChanged(list);
  }

  void _removeImage(int index) {
    final list = List<PlacedImage>.from(widget.images);
    list.removeAt(index);
    setState(() => _selectedIndex = -1);
    widget.onImagesChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 只在有图片选中时，点击空白区域取消选中
        if (_selectedIndex != -1)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() => _selectedIndex = -1);
              },
            ),
          ),
        // 渲染每张图片
        ...widget.images.asMap().entries.map((entry) {
          final index = entry.key;
          final img = entry.value;
          return PlaceableImage(
            key: ValueKey('${img.path}_$index'),
            placedImage: img,
            isSelected: index == _selectedIndex,
            onTap: () {
              if (index == _selectedIndex) {
                // 已选中状态下再次点击：打开大图查看
                widget.onImageView?.call(img);
              } else {
                // 未选中：选中
                setState(() => _selectedIndex = index);
              }
            },
            onDoubleTap: widget.onImageView != null
                ? () => widget.onImageView!.call(img)
                : null,
            onDelete: () => _removeImage(index),
            onUpdate: (updated) => _updateImage(index, updated),
            onInteractionStart: widget.onInteractionStart,
            onInteractionEnd: widget.onInteractionEnd,
            onDoubleTapBelow: widget.onDoubleTapBelowImage != null
                ? () => widget.onDoubleTapBelowImage!.call(img)
                : null,
          );
        }),
      ],
    );
  }
}
