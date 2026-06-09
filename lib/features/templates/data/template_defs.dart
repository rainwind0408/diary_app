import '../models/template.dart';

class TemplateDefs {
  TemplateDefs._();

  static const List<DiaryTemplate> presets = [
    // 日常模板
    DiaryTemplate(
      id: 'work_review',
      name: '工作复盘',
      icon: '💼',
      description: '回顾今天的工作收获',
      content: '【今日完成】\n\n\n【遇到的问题】\n\n\n【明日计划】\n\n\n【一句话总结】\n',
      category: TemplateCategory.daily,
    ),
    DiaryTemplate(
      id: 'emotion',
      name: '情绪日记',
      icon: '💭',
      description: '觉察和梳理当下的情绪',
      content: '此刻我的心情是：\n\n\n这种情绪从什么时候开始的：\n\n\n我在想什么：\n\n\n我能为自己做点什么：\n',
      category: TemplateCategory.daily,
    ),
    DiaryTemplate(
      id: 'three_things',
      name: '每日三件事',
      icon: '📝',
      description: '记录今天最重要的三件事',
      content: '今天最重要的三件事：\n\n① \n\n② \n\n③ \n\n完成后的感受：\n',
      category: TemplateCategory.daily,
    ),
    // 特殊模板
    DiaryTemplate(
      id: 'travel',
      name: '旅行日记',
      icon: '✈️',
      description: '记录旅途中的点滴',
      content: '📍 目的地：\n📅 日期：\n🌤️ 天气：\n\n【行程记录】\n\n\n【美食推荐】\n\n\n【旅行感悟】\n',
      category: TemplateCategory.special,
    ),
    DiaryTemplate(
      id: 'food',
      name: '美食日记',
      icon: '🍽️',
      description: '记录美味的食物体验',
      content: '🍽️ 餐厅：\n📍 地址：\n⭐ 评分：\n\n【菜品记录】\n\n\n【总体评价】\n',
      category: TemplateCategory.special,
    ),
    DiaryTemplate(
      id: 'movie',
      name: '观影日记',
      icon: '🎬',
      description: '记录观影感受',
      content: '🎬 电影：\n⭐ 评分：\n\n【剧情简介】\n\n\n【个人感想】\n\n\n【经典台词】\n',
      category: TemplateCategory.special,
    ),
    DiaryTemplate(
      id: 'reading',
      name: '读书笔记',
      icon: '📚',
      description: '记录阅读收获',
      content: '📚 书名：\n✍️ 作者：\n\n【摘录】\n\n\n【感悟】\n\n\n【行动项】\n',
      category: TemplateCategory.special,
    ),
    DiaryTemplate(
      id: 'exercise',
      name: '运动记录',
      icon: '🏃',
      description: '记录运动情况',
      content: '🏃 运动类型：\n⏱️ 时长：\n💪 强度：\n\n【运动感受】\n\n\n【身体状态】\n',
      category: TemplateCategory.special,
    ),
    // 节日模板
    DiaryTemplate(
      id: 'birthday',
      name: '生日回顾',
      icon: '🎂',
      description: '记录生日的特别日子',
      content: '🎂 今天的寿星：\n🎁 收到的礼物：\n\n【生日感想】\n',
      category: TemplateCategory.festival,
    ),
    DiaryTemplate(
      id: 'year_review',
      name: '年度总结',
      icon: '📅',
      description: '回顾这一年的得与失',
      content: '📅 年份：\n\n【今年的成就】\n\n\n【今年的遗憾】\n\n\n【明年的目标】\n',
      category: TemplateCategory.festival,
    ),
    DiaryTemplate(
      id: 'new_year_plan',
      name: '新年计划',
      icon: '🎯',
      description: '制定新一年的目标',
      content: '🎯 新年目标：\n\n【健康目标】\n\n\n【学习目标】\n\n\n【生活目标】\n',
      category: TemplateCategory.festival,
    ),
  ];
}
