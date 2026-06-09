class PlacedSticker {
  final String stickerId;
  final String emoji;
  double dx;
  double dy;
  double size;
  double rotation;

  PlacedSticker({
    required this.stickerId,
    required this.emoji,
    this.dx = 0,
    this.dy = 0,
    this.size = 48,
    this.rotation = 0,
  });

  PlacedSticker copyWith({
    String? stickerId,
    String? emoji,
    double? dx,
    double? dy,
    double? size,
    double? rotation,
  }) {
    return PlacedSticker(
      stickerId: stickerId ?? this.stickerId,
      emoji: emoji ?? this.emoji,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() => {
        'stickerId': stickerId,
        'emoji': emoji,
        'dx': dx,
        'dy': dy,
        'size': size,
        'rotation': rotation,
      };

  factory PlacedSticker.fromJson(Map<String, dynamic> json) {
    return PlacedSticker(
      stickerId: json['stickerId'] as String,
      emoji: (json['emoji'] as String?) ?? '',
      dx: (json['dx'] as num).toDouble(),
      dy: (json['dy'] as num).toDouble(),
      size: (json['size'] as num?)?.toDouble() ?? 48,
      rotation: (json['rotation'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlacedSticker &&
          runtimeType == other.runtimeType &&
          stickerId == other.stickerId &&
          dx == other.dx &&
          dy == other.dy;

  @override
  int get hashCode => stickerId.hashCode ^ dx.hashCode ^ dy.hashCode;

  @override
  String toString() =>
      'PlacedSticker(id: $stickerId, emoji: $emoji, pos: ($dx, $dy))';
}
