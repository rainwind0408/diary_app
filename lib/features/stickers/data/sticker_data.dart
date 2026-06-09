import '../models/sticker.dart';

class StickerData {
  StickerData._();

  static const List<Sticker> presets = [
    // 心情贴纸
    Sticker(id: 'mood_happy', name: '开心', category: '心情', emoji: '😊'),
    Sticker(id: 'mood_love', name: '爱心', category: '心情', emoji: '❤️'),
    Sticker(id: 'mood_sad', name: '难过', category: '心情', emoji: '😢'),
    Sticker(id: 'mood_angry', name: '生气', category: '心情', emoji: '😤'),
    Sticker(id: 'mood_cool', name: '酷', category: '心情', emoji: '😎'),
    Sticker(id: 'mood_think', name: '思考', category: '心情', emoji: '🤔'),
    Sticker(id: 'mood_sleep', name: '困了', category: '心情', emoji: '😴'),
    Sticker(id: 'mood_laugh', name: '大笑', category: '心情', emoji: '😂'),

    // 天气贴纸
    Sticker(id: 'weather_sun', name: '晴天', category: '天气', emoji: '☀️'),
    Sticker(id: 'weather_cloud', name: '多云', category: '天气', emoji: '⛅'),
    Sticker(id: 'weather_rain', name: '下雨', category: '天气', emoji: '🌧️'),
    Sticker(id: 'weather_snow', name: '下雪', category: '天气', emoji: '❄️'),
    Sticker(id: 'weather_wind', name: '刮风', category: '天气', emoji: '🌬️'),
    Sticker(id: 'weather_rainbow', name: '彩虹', category: '天气', emoji: '🌈'),
    Sticker(id: 'weather_moon', name: '月亮', category: '天气', emoji: '🌙'),
    Sticker(id: 'weather_star', name: '星星', category: '天气', emoji: '⭐'),

    // 食物贴纸
    Sticker(id: 'food_cake', name: '蛋糕', category: '食物', emoji: '🎂'),
    Sticker(id: 'food_coffee', name: '咖啡', category: '食物', emoji: '☕'),
    Sticker(id: 'food_noodle', name: '面条', category: '食物', emoji: '🍜'),
    Sticker(id: 'food_fruit', name: '水果', category: '食物', emoji: '🍎'),
    Sticker(id: 'food_ice', name: '冰淇淋', category: '食物', emoji: '🍦'),
    Sticker(id: 'food_beer', name: '啤酒', category: '食物', emoji: '🍺'),
    Sticker(id: 'food_bread', name: '面包', category: '食物', emoji: '🍞'),
    Sticker(id: 'food_dumpling', name: '饺子', category: '食物', emoji: '🥟'),

    // 动物贴纸
    Sticker(id: 'animal_cat', name: '猫咪', category: '动物', emoji: '🐱'),
    Sticker(id: 'animal_dog', name: '狗狗', category: '动物', emoji: '🐶'),
    Sticker(id: 'animal_rabbit', name: '兔子', category: '动物', emoji: '🐰'),
    Sticker(id: 'animal_bear', name: '小熊', category: '动物', emoji: '🐻'),
    Sticker(id: 'animal_fox', name: '狐狸', category: '动物', emoji: '🦊'),
    Sticker(id: 'animal_panda', name: '熊猫', category: '动物', emoji: '🐼'),
    Sticker(id: 'animal_butterfly', name: '蝴蝶', category: '动物', emoji: '🦋'),
    Sticker(id: 'animal_bird', name: '小鸟', category: '动物', emoji: '🐦'),

    // 装饰贴纸
    Sticker(id: 'deco_flower', name: '花朵', category: '装饰', emoji: '🌸'),
    Sticker(id: 'deco_tree', name: '大树', category: '装饰', emoji: '🌳'),
    Sticker(id: 'deco_leaf', name: '叶子', category: '装饰', emoji: '🍃'),
    Sticker(id: 'deco_heart', name: '心跳', category: '装饰', emoji: '💓'),
    Sticker(id: 'deco_sparkle', name: '闪光', category: '装饰', emoji: '✨'),
    Sticker(id: 'deco_fire', name: '火焰', category: '装饰', emoji: '🔥'),
    Sticker(id: 'deco_gem', name: '宝石', category: '装饰', emoji: '💎'),
    Sticker(id: 'deco_crown', name: '皇冠', category: '装饰', emoji: '👑'),

    // 节日贴纸
    Sticker(id: 'fest_gift', name: '礼物', category: '节日', emoji: '🎁'),
    Sticker(id: 'fest_balloon', name: '气球', category: '节日', emoji: '🎈'),
    Sticker(id: 'fest_confetti', name: '彩带', category: '节日', emoji: '🎊'),
    Sticker(id: 'fest_tada', name: '庆祝', category: '节日', emoji: '🎉'),
    Sticker(id: 'fest_clap', name: '鼓掌', category: '节日', emoji: '👏'),
    Sticker(id: 'fest_thanks', name: '感谢', category: '节日', emoji: '🙏'),
    Sticker(id: 'fest_party', name: '派对', category: '节日', emoji: '🥳'),
    Sticker(id: 'fest_ribbon', name: '丝带', category: '节日', emoji: '🎀'),
  ];

  static List<String> get categories =>
      presets.map((s) => s.category).toSet().toList();
}
