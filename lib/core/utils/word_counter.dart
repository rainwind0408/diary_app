class WordCounter {
  WordCounter._();

  static int count(String text) {
    if (text.trim().isEmpty) return 0;
    final chineseChars = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final nonChinese = text.replaceAll(RegExp(r'[\u4e00-\u9fff]'), ' ');
    final words = nonChinese.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return chineseChars + words;
  }
}
