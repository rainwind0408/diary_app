import 'dart:convert';
import '../../features/stickers/models/placed_sticker.dart';
import 'placed_image.dart';
import 'placed_audio.dart';

class DiaryEntry {
  final int? id;
  final String title;
  final String content;
  final String mood;
  final int moodIntensity;
  final String moodNote;
  final String moodLabel;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isLocked;
  final String pinHash;
  final List<String> tags;
  final List<PlacedImage> images;
  final List<PlacedAudio> audios;
  final List<PlacedSticker> stickers;

  DiaryEntry({
    this.id,
    required this.title,
    required this.content,
    this.mood = '',
    this.moodIntensity = 3,
    this.moodNote = '',
    this.moodLabel = '',
    this.wordCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isLocked = false,
    this.pinHash = '',
    this.tags = const [],
    this.images = const [],
    this.audios = const [],
    this.stickers = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  DiaryEntry copyWith({
    int? id,
    String? title,
    String? content,
    String? mood,
    int? moodIntensity,
    String? moodNote,
    String? moodLabel,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isLocked,
    String? pinHash,
    List<String>? tags,
    List<PlacedImage>? images,
    List<PlacedAudio>? audios,
    List<PlacedSticker>? stickers,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mood: mood ?? this.mood,
      moodIntensity: moodIntensity ?? this.moodIntensity,
      moodNote: moodNote ?? this.moodNote,
      moodLabel: moodLabel ?? this.moodLabel,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLocked: isLocked ?? this.isLocked,
      pinHash: pinHash ?? this.pinHash,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      audios: audios ?? this.audios,
      stickers: stickers ?? this.stickers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'mood': mood,
      'mood_intensity': moodIntensity,
      'mood_note': moodNote,
      'mood_label': moodLabel,
      'word_count': wordCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_locked': isLocked ? 1 : 0,
      'pin_hash': pinHash,
      'tags': jsonEncode(tags),
      'images': jsonEncode(images.map((img) => img.toJson()).toList()),
      'audios': jsonEncode(audios.map((a) => a.toJson()).toList()),
      'stickers': jsonEncode(stickers.map((s) => s.toJson()).toList()),
    };
  }

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '无标题',
      content: map['content'] as String,
      mood: (map['mood'] as String?) ?? '',
      moodIntensity: (map['mood_intensity'] as int?) ?? 3,
      moodNote: (map['mood_note'] as String?) ?? '',
      moodLabel: (map['mood_label'] as String?) ?? '',
      wordCount: (map['word_count'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isLocked: (map['is_locked'] as int?) == 1,
      pinHash: (map['pin_hash'] as String?) ?? '',
      tags: _parseTags(map['tags']),
      images: PlacedImage.parseList(map['images']),
      audios: PlacedAudio.parseList(map['audios']),
      stickers: _parseStickers(map['stickers']),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory DiaryEntry.fromJson(Map<String, dynamic> json) =>
      DiaryEntry.fromMap(json);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          content == other.content &&
          mood == other.mood &&
          moodIntensity == other.moodIntensity &&
          moodNote == other.moodNote &&
          moodLabel == other.moodLabel &&
          wordCount == other.wordCount &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          isLocked == other.isLocked &&
          pinHash == other.pinHash &&
          _listEquals(tags, other.tags);

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      content.hashCode ^
      mood.hashCode ^
      moodIntensity.hashCode ^
      moodNote.hashCode ^
      moodLabel.hashCode ^
      wordCount.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      isLocked.hashCode ^
      pinHash.hashCode;

  @override
  String toString() {
    return 'DiaryEntry(id: $id, title: $title, content: ${content.length > 20 ? content.substring(0, 20) : content}..., mood: $mood, wordCount: $wordCount, isLocked: $isLocked, tags: $tags)';
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<String> _parseTags(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.cast<String>();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.cast<String>();
      } catch (_) {}
    }
    return [];
  }

  static List<PlacedSticker> _parseStickers(dynamic raw) {
    if (raw == null) return [];
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .map((e) => PlacedSticker.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }
}
