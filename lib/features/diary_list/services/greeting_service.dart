class GreetingService {
  GreetingService._();

  static String generate({
    required DateTime time,
    String? weatherDescription,
    String? weatherEmoji,
    required int streakDays,
  }) {
    final hour = time.hour;
    String greeting;

    // 根据时间选择基础问候
    if (hour >= 6 && hour < 11) {
      greeting = _randomFrom(['早安 ☀️', '早上好 🌅', '早 🌞']);
    } else if (hour >= 11 && hour < 14) {
      greeting = _randomFrom(['中午好 🍱', '午安 ☀️']);
    } else if (hour >= 14 && hour < 18) {
      greeting = _randomFrom(['下午好 🌤️', '下午茶时间 ☕']);
    } else if (hour >= 18 && hour < 22) {
      greeting = _randomFrom(['晚上好 🌙', '晚安前 ✨']);
    } else {
      greeting = _randomFrom(['夜深了 🌙', '还在写日记？🌟']);
    }

    // 根据 streak 添加鼓励
    if (streakDays >= 7) {
      greeting += '\n已连续写作 $streakDays 天，继续保持！';
    } else if (streakDays > 0) {
      greeting += '\n坚持 $streakDays 天了，加油！';
    } else {
      greeting += '\n记录一下今天吧';
    }

    return greeting;
  }

  static String _randomFrom(List<String> list) {
    return list[DateTime.now().millisecond % list.length];
  }
}
