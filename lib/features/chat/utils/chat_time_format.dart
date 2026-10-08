/// 聊天时间分组与格式化（纯 Dart，不依赖 Flutter，便于独立测试）
library;

class ChatTimeFormat {
  ChatTimeFormat._();

  /// 相邻消息间隔超过这个时长就插一条时间分隔
  static const Duration gapThreshold = Duration(minutes: 5);

  /// 是否需要在这条消息上方显示时间
  static bool shouldShow(DateTime? previous, DateTime current) {
    if (previous == null) return true;
    return current.difference(previous).abs() > gapThreshold;
  }

  /// 微信式相对时间文案：
  /// 今天 → `HH:mm`；昨天 → `昨天 HH:mm`；一周内 → `星期X HH:mm`；
  /// 今年 → `M月d日 HH:mm`；更早 → `yyyy年M月d日 HH:mm`
  static String format(DateTime time, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final target = DateTime(time.year, time.month, time.day);
    final hm = '${_two(time.hour)}:${_two(time.minute)}';

    final dayDiff = today.difference(target).inDays;

    if (dayDiff == 0) return hm;
    if (dayDiff == 1) return '昨天 $hm';
    if (dayDiff > 1 && dayDiff < 7) {
      const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      return '星期${weekdays[time.weekday - 1]} $hm';
    }
    if (time.year == ref.year) return '${time.month}月${time.day}日 $hm';
    return '${time.year}年${time.month}月${time.day}日 $hm';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
