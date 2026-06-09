import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DraftData {
  final String title;
  final String content;
  final String mood;
  final DateTime timestamp;

  DraftData({
    required this.title,
    required this.content,
    required this.mood,
    required this.timestamp,
  });
}

class DraftService {
  DraftService._();

  static const _keyTitle = 'draft_title';
  static const _keyContent = 'draft_content';
  static const _keyPages = 'draft_pages'; // 兼容旧格式
  static const _keyMood = 'draft_mood';
  static const _keyTimestamp = 'draft_timestamp';

  static Future<void> saveDraft({
    required String title,
    required String content,
    required String mood,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTitle, title);
    await prefs.setString(_keyContent, content);
    await prefs.setString(_keyMood, mood);
    await prefs.setString(_keyTimestamp, DateTime.now().toIso8601String());
    // 清除旧格式
    await prefs.remove(_keyPages);
  }

  static Future<DraftData?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampStr = prefs.getString(_keyTimestamp);
    if (timestampStr == null) return null;

    final timestamp = DateTime.parse(timestampStr);
    // 24 小时内有效
    if (DateTime.now().difference(timestamp).inHours >= 24) {
      await clearDraft();
      return null;
    }

    final title = prefs.getString(_keyTitle) ?? '';
    final mood = prefs.getString(_keyMood) ?? '';

    // 优先读取新格式
    String? content = prefs.getString(_keyContent);

    // 兼容旧格式：从 pages 列表合并
    if (content == null) {
      final pagesStr = prefs.getString(_keyPages);
      if (pagesStr != null) {
        try {
          final pagesList = (jsonDecode(pagesStr) as List).cast<String>();
          content = pagesList.join();
        } catch (_) {
          await clearDraft();
          return null;
        }
      }
    }

    if (content == null) return null;

    return DraftData(
      title: title,
      content: content,
      mood: mood,
      timestamp: timestamp,
    );
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTitle);
    await prefs.remove(_keyContent);
    await prefs.remove(_keyPages);
    await prefs.remove(_keyMood);
    await prefs.remove(_keyTimestamp);
  }

  static Future<bool> hasDraft() async {
    final draft = await loadDraft();
    return draft != null;
  }
}
