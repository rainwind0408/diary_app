import 'package:flutter/material.dart';
import '../models/placed_sticker.dart';
import 'placeable_sticker.dart';

class StickerLayer extends StatelessWidget {
  final List<PlacedSticker> stickers;
  final void Function(int index, PlacedSticker sticker) onStickerUpdated;
  final void Function(int index) onStickerDeleted;
  final VoidCallback? onTapOutside;

  const StickerLayer({
    super.key,
    required this.stickers,
    required this.onStickerUpdated,
    required this.onStickerDeleted,
    this.onTapOutside,
  });

  @override
  Widget build(BuildContext context) {
    if (stickers.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: List.generate(stickers.length, (index) {
        return PlaceableSticker(
          sticker: stickers[index],
          onUpdate: (sticker) => onStickerUpdated(index, sticker),
          onDelete: () => onStickerDeleted(index),
        );
      }),
    );
  }
}
