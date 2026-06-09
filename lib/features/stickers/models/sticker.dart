import 'placed_sticker.dart';

class Sticker {
  final String id;
  final String name;
  final String category;
  final String emoji;
  final bool isDefault;

  const Sticker({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    this.isDefault = true,
  });

  Sticker copyWith({
    String? id,
    String? name,
    String? category,
    String? emoji,
    bool? isDefault,
  }) {
    return Sticker(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      emoji: emoji ?? this.emoji,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  PlacedSticker toPlacedSticker({double dx = 0, double dy = 0, double size = 48}) {
    return PlacedSticker(
      stickerId: id,
      emoji: emoji,
      dx: dx,
      dy: dy,
      size: size,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sticker && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Sticker(id: $id, name: $name, emoji: $emoji)';
}
