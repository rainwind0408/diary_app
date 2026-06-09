enum Season { spring, summer, autumn, winter }

class SolarTerm {
  final String name;
  final DateTime date;
  final int index; // 0-23 in the 24-term cycle

  const SolarTerm(this.name, this.date, this.index);

  Season get season {
    // 立春(2)~立夏(8)前 = spring
    // 立夏(8)~立秋(14)前 = summer
    // 立秋(14)~立冬(20)前 = autumn
    // 立冬(20)~立春(2)前 = winter
    if (index >= 2 && index < 8) return Season.spring;
    if (index >= 8 && index < 14) return Season.summer;
    if (index >= 14 && index < 20) return Season.autumn;
    return Season.winter;
  }

  int daysInto(DateTime date) => date.difference(this.date).inDays;

  @override
  String toString() => 'SolarTerm($name, ${date.year}-${date.month}-${date.day})';
}

class SolarTerms {
  SolarTerms._();

  static const List<String> names = [
    '小寒', '大寒', '立春', '雨水', '惊蛰', '春分',
    '清明', '谷雨', '立夏', '小满', '芒种', '夏至',
    '小暑', '大暑', '立秋', '处暑', '白露', '秋分',
    '寒露', '霜降', '立冬', '小雪', '大雪', '冬至',
  ];

  static const List<String> descriptions = [
    '雁北乡，鹊始巢', '鸡始乳，征鸟厉疾',
    '东风解冻，蛰虫始振', '獭祭鱼，鸿雁来',
    '桃始华，仓庚鸣', '玄鸟至，雷乃发声',
    '桐始华，田鼠化鴽', '萍始生，鸣鸠拂其羽',
    '蝼蝈鸣，蚯蚓出', '苦菜秀，靡草死',
    '螳螂生，鵙始鸣', '鹿角解，蜩始鸣',
    '温风至，蟋蟀居壁', '腐草为萤，土润溽暑',
    '凉风至，白露生', '鹰乃祭鸟，天地始肃',
    '鸿雁来，玄鸟归', '雷始收声，蛰虫坯户',
    '鸿雁来宾，菊有黄华', '豺乃祭兽，草木黄落',
    '水始冰，地始冻', '虹藏不见，天气上升',
    '鹖鴠不鸣，虎始交', '蚯蚓结，麋角解',
  ];

  static const List<String> decorationThemes = [
    'xiaohan', 'dahan',
    'lichun', 'yushui',
    'jingzhe', 'chunfen',
    'qingming', 'guyu',
    'lixia', 'xiaoman',
    'mangzhong', 'xiazhi',
    'xiaoshu', 'dashu',
    'liqiu', 'chushu',
    'bailu', 'qiufen',
    'hanlu', 'shuangjiang',
    'lidong', 'xiaoxue',
    'daxue', 'dongzhi',
  ];

  static const List<String> backgroundImages = [
    'xiaohan', 'dahan',
    'lichun', 'yushui',
    'jingzhe', 'chunfen',
    'qingming', 'guyu',
    'lixia', 'xiaoman',
    'mangzhong', 'xiazhi',
    'xiaoshu', 'dashu',
    'liqiu', 'chushu',
    'bailu', 'qiufen',
    'hanlu', 'shuangjiang',
    'lidong', 'xiaoxue',
    'daxue', 'dongzhi',
  ];

  static String getBackgroundPath(int termIndex) {
    if (termIndex >= 0 && termIndex < backgroundImages.length) {
      return 'assets/backgrounds/${backgroundImages[termIndex]}.jpg';
    }
    return 'assets/backgrounds/lichun.jpg';
  }

  /// 24节气的近似日期（基于天文算法的经验值）
  /// 每个节气的月日近似值
  static const List<(int month, int day)> _termDates = [
    (1, 6),   // 小寒
    (1, 20),  // 大寒
    (2, 4),   // 立春
    (2, 19),  // 雨水
    (3, 6),   // 惊蛰
    (3, 21),  // 春分
    (4, 5),   // 清明
    (4, 20),  // 谷雨
    (5, 6),   // 立夏
    (5, 21),  // 小满
    (6, 5),   // 芒种
    (6, 21),  // 夏至
    (7, 7),   // 小暑
    (7, 23),  // 大暑
    (8, 7),   // 立秋
    (8, 23),  // 处暑
    (9, 8),   // 白露
    (9, 23),  // 秋分
    (10, 8),  // 寒露
    (10, 23), // 霜降
    (11, 7),  // 立冬
    (11, 22), // 小雪
    (12, 7),  // 大雪
    (12, 22), // 冬至
  ];

  /// 获取某年的所有24节气
  static List<SolarTerm> getTermsForYear(int year) {
    final terms = <SolarTerm>[];
    for (int i = 0; i < 24; i++) {
      final (month, day) = _termDates[i];
      final date = DateTime(year, month, day);
      terms.add(SolarTerm(names[i], date, i));
    }
    return terms;
  }

  /// 获取当前节气
  static SolarTerm getCurrentTerm(DateTime date) {
    final yearTerms = getTermsForYear(date.year);

    for (int i = yearTerms.length - 1; i >= 0; i--) {
      if (!date.isBefore(yearTerms[i].date)) {
        return yearTerms[i];
      }
    }

    // 如果在当年第一个节气之前，使用上一年的最后一个节气
    final prevYearTerms = getTermsForYear(date.year - 1);
    return prevYearTerms.last;
  }

  /// 获取当前季节
  static Season getSeason(DateTime date) {
    return getCurrentTerm(date).season;
  }

  /// 获取下一个节气
  static SolarTerm getNextTerm(DateTime date) {
    final yearTerms = getTermsForYear(date.year);

    for (final term in yearTerms) {
      if (term.date.isAfter(date)) {
        return term;
      }
    }

    final nextYearTerms = getTermsForYear(date.year + 1);
    return nextYearTerms.first;
  }
}
