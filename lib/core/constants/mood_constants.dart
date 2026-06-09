class MoodConstants {
  MoodConstants._();

  // 心情分类
  static const List<Map<String, String>> positiveMoods = [
    {'emoji': '😊', 'label': '开心'},
    {'emoji': '🤩', 'label': '兴奋'},
    {'emoji': '🙏', 'label': '感恩'},
    {'emoji': '😌', 'label': '平静'},
    {'emoji': '🥰', 'label': '满足'},
  ];

  static const List<Map<String, String>> neutralMoods = [
    {'emoji': '😐', 'label': '普通'},
    {'emoji': '🤔', 'label': '思考'},
    {'emoji': '😴', 'label': '困倦'},
    {'emoji': '😑', 'label': '无聊'},
  ];

  static const List<Map<String, String>> negativeMoods = [
    {'emoji': '😢', 'label': '难过'},
    {'emoji': '😰', 'label': '焦虑'},
    {'emoji': '😤', 'label': '生气'},
    {'emoji': '😫', 'label': '压力'},
    {'emoji': '😔', 'label': '孤独'},
  ];

  static const List<Map<String, String>> specialMoods = [
    {'emoji': '🥹', 'label': '感动'},
    {'emoji': '😲', 'label': '惊喜'},
    {'emoji': '🤞', 'label': '期待'},
    {'emoji': '🥲', 'label': '怀念'},
  ];

  // 常用心情（快速选择）
  static const List<Map<String, String>> quickMoods = [
    {'emoji': '😊', 'label': '开心'},
    {'emoji': '😌', 'label': '平静'},
    {'emoji': '😐', 'label': '普通'},
    {'emoji': '😢', 'label': '难过'},
    {'emoji': '😰', 'label': '焦虑'},
    {'emoji': '🤩', 'label': '兴奋'},
  ];

  // 强度描述
  static const List<String> intensityLabels = ['轻微', '一般', '明显', '强烈', '非常强烈'];

  // 所有心情（合并分类）
  static List<Map<String, String>> get allMoods => [
    ...positiveMoods,
    ...neutralMoods,
    ...negativeMoods,
    ...specialMoods,
  ];

  // 根据 emoji 查找心情
  static Map<String, String>? findByEmoji(String emoji) {
    for (final mood in allMoods) {
      if (mood['emoji'] == emoji) return mood;
    }
    return null;
  }
}
