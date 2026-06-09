class DiaryTemplate {
  final String id;
  final String name;
  final String icon;
  final String description;
  final String content;
  final TemplateCategory category;
  final bool isDefault;
  final bool isCustom;

  const DiaryTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.content,
    this.category = TemplateCategory.daily,
    this.isDefault = true,
    this.isCustom = false,
  });

  DiaryTemplate copyWith({
    String? id,
    String? name,
    String? icon,
    String? description,
    String? content,
    TemplateCategory? category,
    bool? isDefault,
    bool? isCustom,
  }) {
    return DiaryTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      content: content ?? this.content,
      category: category ?? this.category,
      isDefault: isDefault ?? this.isDefault,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'description': description,
      'content': content,
      'category': category.index,
      'isDefault': isDefault ? 1 : 0,
      'isCustom': isCustom ? 1 : 0,
    };
  }

  factory DiaryTemplate.fromMap(Map<String, dynamic> map) {
    return DiaryTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: (map['icon'] as String?) ?? '📝',
      description: (map['description'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      category: TemplateCategory.values[(map['category'] as int?) ?? 0],
      isDefault: (map['isDefault'] as int?) == 1,
      isCustom: (map['isCustom'] as int?) == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          content == other.content;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ content.hashCode;

  @override
  String toString() => 'DiaryTemplate(id: $id, name: $name)';
}

enum TemplateCategory {
  daily, // 日常
  special, // 特殊
  festival, // 节日
  custom, // 自定义
}
