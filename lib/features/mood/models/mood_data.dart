class MoodData {
  final String emoji;
  final String label;
  final int intensity; // 1-5
  final String? note;

  const MoodData({
    required this.emoji,
    required this.label,
    this.intensity = 3,
    this.note,
  });

  MoodData copyWith({
    String? emoji,
    String? label,
    int? intensity,
    String? note,
  }) {
    return MoodData(
      emoji: emoji ?? this.emoji,
      label: label ?? this.label,
      intensity: intensity ?? this.intensity,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emoji': emoji,
      'label': label,
      'intensity': intensity,
      'note': note,
    };
  }

  factory MoodData.fromMap(Map<String, dynamic> map) {
    return MoodData(
      emoji: map['emoji'] as String? ?? '',
      label: map['label'] as String? ?? '',
      intensity: (map['intensity'] as int?) ?? 3,
      note: map['note'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoodData &&
          runtimeType == other.runtimeType &&
          emoji == other.emoji &&
          label == other.label &&
          intensity == other.intensity &&
          note == other.note;

  @override
  int get hashCode =>
      emoji.hashCode ^
      label.hashCode ^
      intensity.hashCode ^
      (note?.hashCode ?? 0);

  @override
  String toString() {
    return 'MoodData(emoji: $emoji, label: $label, intensity: $intensity, note: $note)';
  }
}
