import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static const List<String> _weekdays = ['日', '一', '二', '三', '四', '五', '六'];

  static String formatFull(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日 星期${_weekdays[date.weekday % 7]}';
  }

  static String formatDateTime(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.year}年$month月$day日 $hour:$minute';
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatMonth(DateTime date) {
    return '${date.year}年${date.month}月';
  }

  static String formatShort(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  static String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String formatGroupDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    String prefix;
    if (diff == 0) {
      prefix = '今天';
    } else if (diff == 1) {
      prefix = '昨天';
    } else if (diff == 2) {
      prefix = '前天';
    } else {
      prefix = '${date.month}月${date.day}日';
    }

    return '$prefix  星期${_weekdays[date.weekday % 7]}';
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
