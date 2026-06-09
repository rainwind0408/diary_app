import 'package:flutter/material.dart';
import '../models/placed_sticker.dart';

class PlaceableSticker extends StatefulWidget {
  final PlacedSticker sticker;
  final ValueChanged<PlacedSticker> onUpdate;
  final VoidCallback onDelete;

  const PlaceableSticker({
    super.key,
    required this.sticker,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<PlaceableSticker> createState() => _PlaceableStickerState();
}

class _PlaceableStickerState extends State<PlaceableSticker> {
  late double _dx;
  late double _dy;
  late double _size;
  late double _rotation;
  bool _selected = false;

  @override
  void initState() {
    super.initState();
    _dx = widget.sticker.dx;
    _dy = widget.sticker.dy;
    _size = widget.sticker.size;
    _rotation = widget.sticker.rotation;
  }

  void _commitUpdate() {
    widget.onUpdate(PlacedSticker(
      stickerId: widget.sticker.stickerId,
      emoji: widget.sticker.emoji,
      dx: _dx,
      dy: _dy,
      size: _size,
      rotation: _rotation,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _dx,
      top: _dy,
      child: GestureDetector(
        onTap: () => setState(() => _selected = !_selected),
        onPanUpdate: (details) {
          setState(() {
            _dx += details.delta.dx;
            _dy += details.delta.dy;
          });
          _commitUpdate();
        },
        onLongPress: widget.onDelete,
        child: Transform.rotate(
          angle: _rotation,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: _selected
                ? BoxDecoration(
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  widget.sticker.emoji,
                  style: TextStyle(fontSize: _size),
                ),
                if (_selected) ...[
                  // 缩放手柄（右下角）
                  Positioned(
                    right: -8,
                    bottom: -8,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final delta =
                            details.delta.dx + details.delta.dy;
                        setState(() {
                          _size = (_size + delta).clamp(24, 120);
                        });
                        _commitUpdate();
                      },
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  // 旋转手柄（右上角）
                  Positioned(
                    right: -8,
                    top: -8,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _rotation += details.delta.dx * 0.02;
                        });
                        _commitUpdate();
                      },
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.rotate_right,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // 删除按钮（左上角）
                  Positioned(
                    left: -8,
                    top: -8,
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
