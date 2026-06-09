class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final AchievementCategory category;
  final DateTime? unlockedAt;
  final bool isRead;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    this.unlockedAt,
    this.isRead = false,
  });

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    AchievementCategory? category,
    DateTime? unlockedAt,
    bool? isRead,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      isRead: isRead ?? this.isRead,
    );
  }

  bool get isUnlocked => unlockedAt != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'is_read': isRead ? 1 : 0,
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] as String,
      name: '',
      description: '',
      icon: '',
      category: AchievementCategory.writing,
      unlockedAt: map['unlocked_at'] != null
          ? DateTime.parse(map['unlocked_at'] as String)
          : null,
      isRead: (map['is_read'] as int?) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Achievement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          unlockedAt == other.unlockedAt &&
          isRead == other.isRead;

  @override
  int get hashCode => id.hashCode ^ unlockedAt.hashCode ^ isRead.hashCode;

  @override
  String toString() {
    return 'Achievement(id: $id, name: $name, unlocked: $isUnlocked)';
  }
}

enum AchievementCategory {
  writing,   // 写作成就
  streak,    // 连续写作
  feature,   // 功能使用
  special,   // 特殊成就
}
