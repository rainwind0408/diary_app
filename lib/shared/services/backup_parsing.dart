import 'dart:convert';

import '../../data/models/diary_entry.dart';
import '../../data/models/placed_audio.dart';
import '../../data/models/placed_image.dart';
import '../../features/stickers/models/placed_sticker.dart';

/// 备份文件的**唯一解析入口**。
///
/// JSON 备份与 ZIP 备份的日记字段用的是同一套键名，只有两点不同：
/// 1. **字段形态**：JSON 备份由 `DiaryEntry.toMap()` 生成，`tags` / `images` /
///    `audios` / `stickers` 都先经过 `jsonEncode`，读回来是 **String**；
///    ZIP 备份由 `ZipExportService._entryToExportMap()` 生成，是**原生 List**。
/// 2. **媒体**：JSON 备份不含图片 / 录音的二进制，所以只能传空列表；
///    ZIP 备份由调用方解包后传入 [PlacedImage] / [PlacedAudio]。
///
/// ⚠️ 历史坑：JSON 导入侧曾直接写 `map['tags'] as List?`，而导出侧写进去的是
/// `jsonEncode` 后的字符串 —— 于是**每条日记都抛
/// `_TypeError: type 'String' is not a subtype of type 'List<dynamic>?'`**，
/// 被 `catch` 吞成「跳过」，用户看到的是「导入完成：0 条成功，N 条失败」。
/// 所以任何从备份读出来的集合 / 布尔字段，都必须走这里，不要再手写 `as List`。
class BackupParsing {
  BackupParsing._();

  /// 把一份备份里的日记 map 还原成 [DiaryEntry]。
  ///
  /// JSON 导入与 ZIP 导入共用这一份，避免两边各写一套、改一边漏一边。
  static DiaryEntry entryFromMap(
    Map<String, dynamic> map, {
    List<PlacedImage> images = const [],
    List<PlacedAudio> audios = const [],
  }) {
    return DiaryEntry(
      title: string(map['title'], fallback: '无标题'),
      content: string(map['content']),
      mood: string(map['mood']),
      moodIntensity: intValue(map['mood_intensity'], fallback: 3),
      moodNote: string(map['mood_note']),
      moodLabel: string(map['mood_label']),
      wordCount: intValue(map['word_count']),
      // 加锁状态 + PIN 哈希必须**一起**还原。
      //
      // ⚠️ 只还原 is_locked 而漏掉 pin_hash 会造成「假锁」：
      // `DiaryAccess.verify` 在 storedHash 为空时**直接放行**
      // （见 diary_access.dart:46），于是日记显示着锁图标、点开却不需要密码，
      // 用户以为私密内容被保护着，实际没有。
      // pinHash 是自包含的 `salt:sha256(salt+pin)`，跨设备可校验。
      isLocked: boolValue(map['is_locked']),
      pinHash: string(map['pin_hash']),
      tags: stringList(map['tags']),
      images: images,
      audios: audios,
      stickers: stickers(map['stickers']),
      createdAt: dateTime(map['created_at']),
      updatedAt: dateTime(map['updated_at']),
      weather: string(map['weather']),
      location: string(map['location']),
    );
  }

  /// 解析字符串列表：兼容 `["a","b"]`（原生 List）与 `'["a","b"]'`（jsonEncode 后的 String）。
  static List<String> stringList(dynamic raw) {
    final decoded = _decodeIfJsonString(raw);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
    }
    return const [];
  }

  /// 解析布尔：兼容 `true` / `1` / `"1"` / `"true"`。
  ///
  /// 数据库里存的是 `0/1`，JSON 里也是 `0/1`，但手工改过的备份可能是 `true`。
  static bool boolValue(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final v = raw.trim().toLowerCase();
      return v == '1' || v == 'true';
    }
    return false;
  }

  /// 解析字符串：非字符串一律回落到 [fallback]，避免 `as String` 抛异常。
  static String string(dynamic raw, {String fallback = ''}) =>
      raw is String ? raw : fallback;

  /// 解析整数：兼容 int / double / 数字字符串。
  static int intValue(dynamic raw, {int fallback = 0}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }

  /// 解析浮点：兼容 int / double / 数字字符串。
  static double doubleValue(dynamic raw, {double fallback = 0}) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? fallback;
    return fallback;
  }

  /// 解析时间：解析不出来就用当前时间，绝不抛异常打断整条导入。
  static DateTime dateTime(dynamic raw) {
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  /// 解析贴纸列表，同样兼容 String / List 两种形态。
  ///
  /// 逐条 try：`PlacedSticker.fromJson` 对 `dx` / `dy` / `rotation` 是硬断言，
  /// 一条脏数据不该让**整篇日记**导入失败。非 Map 的脏数据也直接丢弃
  /// （之前 JSON 导入会给它造一个 `PlacedSticker(stickerId: '', emoji: '')`
  /// 的空壳贴纸，反而更糟）。
  static List<PlacedSticker> stickers(dynamic raw) {
    final decoded = _decodeIfJsonString(raw);
    if (decoded is! List) return const [];
    final result = <PlacedSticker>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      try {
        result.add(PlacedSticker.fromJson(item));
      } catch (_) {
        // 跳过这一条，继续解析其余的
      }
    }
    return result;
  }

  /// 若 [raw] 是「JSON 字符串」就解一层，否则原样返回。
  static dynamic _decodeIfJsonString(dynamic raw) {
    if (raw is! String) return raw;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }
}
