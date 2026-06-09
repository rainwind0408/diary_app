import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/diary_entry.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../../core/utils/word_counter.dart';
import '../services/audio_service.dart';
import '../services/draft_service.dart';
import '../../../data/models/placed_image.dart';
import '../../../data/models/placed_audio.dart';
import '../../templates/models/template.dart';
import '../../stickers/models/placed_sticker.dart';

class DiaryWriteProvider extends ChangeNotifier {
  final DiaryRepository _repository = DiaryRepository();

  // === 3D 数组分页：页 → 行 ===
  List<List<String>> _diaryPages = [[]];
  int _currentPageIndex = 0;
  static const int maxLinesPerPage = 15;

  // === 编辑状态 ===
  DiaryEntry? _editingEntry;
  bool _isDirty = false;
  Timer? _draftTimer;
  String _mood = '';
  String _moodLabel = '';
  int _moodIntensity = 3;
  String _moodNote = '';
  List<String> _tags = [];
  List<PlacedSticker> _stickers = [];

  // === 图片/录音（按 pageIndex 存储） ===
  List<List<PlacedImage>> _pageImages = [[]];
  List<List<PlacedAudio>> _pageAudios = [[]];

  // === Getters ===
  int get currentPageIndex => _currentPageIndex;
  int get totalPages => _diaryPages.length;
  String get mood => _mood;
  String get moodLabel => _moodLabel;
  int get moodIntensity => _moodIntensity;
  String get moodNote => _moodNote;
  DiaryEntry? get editingEntry => _editingEntry;
  bool get isDirty => _isDirty;
  bool get isEditing => _editingEntry != null;
  List<String> get tags => _tags;
  List<PlacedSticker> get stickers => _stickers;

  /// 当前页文本（给 TextField）
  String get currentPageText =>
      _currentPageIndex < _diaryPages.length
          ? _diaryPages[_currentPageIndex].join('\n')
          : '';

  /// 获取指定页文本
  String getPageText(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _diaryPages.length) return '';
    return _diaryPages[pageIndex].join('\n');
  }

  /// 完整内容（给保存）
  String get content => _diaryPages
      .where((p) => p.isNotEmpty)
      .map((p) => p.join('\n'))
      .join('\n');

  /// 当前页的录音列表
  List<PlacedAudio> get currentPageAudios =>
      _currentPageIndex < _pageAudios.length
          ? _pageAudios[_currentPageIndex]
          : [];

  /// 当前页的图片列表
  List<PlacedImage> get currentPageImages =>
      _currentPageIndex < _pageImages.length
          ? _pageImages[_currentPageIndex]
          : [];

  List<PlacedImage> get allPlacedImages =>
      _pageImages.expand((p) => p).toList();

  /// 收集所有图片并标记所属页码
  List<PlacedImage> _collectImagesWithPageIndex() {
    final result = <PlacedImage>[];
    for (int i = 0; i < _pageImages.length; i++) {
      for (final img in _pageImages[i]) {
        img.pageIndex = i;
        result.add(img);
      }
    }
    return result;
  }

  /// 收集所有录音并标记所属页码
  List<PlacedAudio> _collectAudiosWithPageIndex() {
    final result = <PlacedAudio>[];
    for (int i = 0; i < _pageAudios.length; i++) {
      for (final audio in _pageAudios[i]) {
        audio.pageIndex = i;
        result.add(audio);
      }
    }
    return result;
  }

  int get totalWordCount => WordCounter.count(content);

  // === 核心内容操作 ===

  /// 更新当前页内容（由 onChanged 调用），全局回流所有页
  /// [cursorOffset]：当前页内的光标偏移量
  /// 返回 Map：{'text': 当前页文本, 'pageIndex': 光标所在页码, 'cursorOffset': 页内偏移}
  Map<String, dynamic> updateCurrentPageText(String text, int cursorOffset) {
    // 1. 计算光标的全局偏移量（在所有页合并后的字符串中的位置）
    int globalOffset = 0;
    for (int i = 0; i < _currentPageIndex && i < _diaryPages.length; i++) {
      globalOffset += _diaryPages[i].join('\n').length + 1; // +1 是 '\n' 分隔符
    }
    globalOffset += cursorOffset;

    // 2. 将当前页替换为新文本
    while (_diaryPages.length <= _currentPageIndex) {
      _diaryPages.add([]);
    }
    _diaryPages[_currentPageIndex] = text.split('\n');

    // 3. 合并所有页为单一字符串
    final allLines = <String>[];
    for (final page in _diaryPages) {
      allLines.addAll(page);
    }

    // 4. 重新按 maxLinesPerPage 分页
    _diaryPages = [];
    for (var i = 0; i < allLines.length; i += maxLinesPerPage) {
      final end = (i + maxLinesPerPage).clamp(0, allLines.length);
      _diaryPages.add(allLines.sublist(i, end));
    }
    if (_diaryPages.isEmpty) _diaryPages = [[]];

    // 5. 根据全局偏移量计算新的页码和页内偏移
    int newPageIndex = 0;
    int newCursorOffset = 0;
    int accumulated = 0;
    for (int i = 0; i < _diaryPages.length; i++) {
      final pageText = _diaryPages[i].join('\n');
      final pageEnd = accumulated + pageText.length;
      if (globalOffset <= pageEnd || i == _diaryPages.length - 1) {
        newPageIndex = i;
        newCursorOffset = (globalOffset - accumulated).clamp(0, pageText.length);
        break;
      }
      accumulated = pageEnd + 1; // +1 是 '\n' 分隔符
    }

    _currentPageIndex = newPageIndex;
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();

    return {
      'text': _diaryPages[newPageIndex].join('\n'),
      'pageIndex': newPageIndex,
      'cursorOffset': newCursorOffset,
    };
  }

  /// 直接保存指定文本到当前页数组（不触发重建，用于切页前同步）
  void saveCurrentPageText(String text) {
    while (_diaryPages.length <= _currentPageIndex) {
      _diaryPages.add([]);
    }
    _diaryPages[_currentPageIndex] = text.split('\n');
  }

  /// 切换页面（由 onPageChanged 调用）
  void switchToPage(int newIndex) {
    if (newIndex == _currentPageIndex) return;
    while (_diaryPages.length <= newIndex) {
      _diaryPages.add([]);
    }
    _currentPageIndex = newIndex;
    notifyListeners();
  }

  /// 设置当前页码（不处理溢出，用于初始化）
  void setCurrentPage(int index) {
    _currentPageIndex = index;
    notifyListeners();
  }

  /// 直接设置页码（不触发重建，用于原子切页）
  void setCurrentPageDirect(int index) {
    while (_diaryPages.length <= index) {
      _diaryPages.add([]);
    }
    _currentPageIndex = index;
  }

  /// 通知页码变化（触发重建，用于原子切页完成后）
  void notifyPageChanged() {
    notifyListeners();
  }

  /// 加载内容到页面数组
  void loadContent(String content) {
    if (content.isEmpty) {
      _diaryPages = [[]];
      return;
    }
    final allLines = content.split('\n');
    _diaryPages = [];
    for (var i = 0; i < allLines.length; i += maxLinesPerPage) {
      final end = (i + maxLinesPerPage).clamp(0, allLines.length);
      _diaryPages.add(allLines.sublist(i, end));
    }
    if (_diaryPages.isEmpty) _diaryPages = [[]];
  }

  // === 心情 ===

  void setMood(String emoji) {
    _mood = emoji;
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  void setMoodData(String emoji, String label, int intensity, String? note) {
    _mood = emoji;
    _moodLabel = label;
    _moodIntensity = intensity;
    _moodNote = note ?? '';
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  // === 保存 ===

  Future<int> save(String title) async {
    final fullContent = content;
    final wordCount = WordCounter.count(fullContent);

    // Extract #tags from content and merge with manual tags
    final contentTags = RegExp(r'\B#\w+')
        .allMatches(fullContent)
        .map((m) => m.group(0)!.substring(1).toLowerCase())
        .toSet();
    final allTags = {
      ..._tags.map((t) => t.toLowerCase()),
      ...contentTags,
    }.toList();

    int resultId;
    final imagesWithPage = _collectImagesWithPageIndex();
    final audiosWithPage = _collectAudiosWithPageIndex();

    if (_editingEntry != null) {
      final updated = _editingEntry!.copyWith(
        title: title.isEmpty ? '无标题' : title,
        content: fullContent,
        mood: _mood,
        moodIntensity: _moodIntensity,
        moodNote: _moodNote,
        moodLabel: _moodLabel,
        wordCount: wordCount,
        tags: allTags,
        images: imagesWithPage,
        audios: audiosWithPage,
        stickers: _stickers,
        updatedAt: DateTime.now(),
      );
      await _repository.updateEntry(updated);
      resultId = updated.id!;
    } else {
      final entry = DiaryEntry(
        title: title.isEmpty ? '无标题' : title,
        content: fullContent,
        mood: _mood,
        moodIntensity: _moodIntensity,
        moodNote: _moodNote,
        moodLabel: _moodLabel,
        wordCount: wordCount,
        tags: allTags,
        images: imagesWithPage,
        audios: audiosWithPage,
        stickers: _stickers,
      );
      resultId = await _repository.insertEntry(entry);
    }

    await DraftService.clearDraft();
    _cancelDraftTimer();
    clear();
    return resultId;
  }

  // === 加载 ===

  void loadForEdit(DiaryEntry entry) {
    _editingEntry = entry;
    _mood = entry.mood;
    _moodLabel = entry.moodLabel;
    _moodIntensity = entry.moodIntensity;
    _moodNote = entry.moodNote;

    // 兼容旧格式：移除 "--- 第 N 页 ---" 分隔符
    loadContent(_migrateOldFormat(entry.content));

    _tags = List.from(entry.tags);
    _stickers = List.from(entry.stickers);

    // 按 pageIndex 将图片分配到对应页面
    _pageImages = [[]];
    if (entry.images.isNotEmpty) {
      for (final img in entry.images) {
        final idx = img.pageIndex;
        while (_pageImages.length <= idx) {
          _pageImages.add([]);
        }
        _pageImages[idx].add(img);
      }
    }

    // 按 pageIndex 将录音分配到对应页面
    _pageAudios = [[]];
    if (entry.audios.isNotEmpty) {
      for (final audio in entry.audios) {
        final idx = audio.pageIndex;
        while (_pageAudios.length <= idx) {
          _pageAudios.add([]);
        }
        _pageAudios[idx].add(audio);
      }
    }

    _currentPageIndex = 0;
    _isDirty = false;
    _cancelDraftTimer();
    notifyListeners();
  }

  /// 兼容旧格式：移除 "--- 第 N 页 ---" 分隔符
  String _migrateOldFormat(String content) {
    return content.replaceAll(RegExp(r'\n*--- 第 \d+ 页 ---\n*'), '\n');
  }

  // === 清空 ===

  void clear() {
    _diaryPages = [[]];
    _currentPageIndex = 0;
    _mood = '';
    _moodLabel = '';
    _moodIntensity = 3;
    _moodNote = '';
    _editingEntry = null;
    _isDirty = false;
    _tags = [];
    _stickers = [];
    _pageImages = [[]];
    _pageAudios = [[]];
    _cancelDraftTimer();
    notifyListeners();
  }

  // === 脏标记 ===

  void markDirty() {
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  // === 草稿 ===

  void _startDraftTimer() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(seconds: 30), _autoSaveDraft);
  }

  void _cancelDraftTimer() {
    _draftTimer?.cancel();
    _draftTimer = null;
  }

  Future<void> _autoSaveDraft() async {
    if (!_isDirty || isEditing) return;
    if (content.trim().isEmpty) return;
    await DraftService.saveDraft(
      title: '',
      content: content,
      mood: _mood,
    );
  }

  Future<DraftData?> loadDraft() async {
    return DraftService.loadDraft();
  }

  void restoreDraft(DraftData draft) {
    loadContent(draft.content);
    _mood = draft.mood;
    _currentPageIndex = 0;
    _isDirty = false;
    _editingEntry = null;
    _startDraftTimer();
    notifyListeners();
  }

  Future<void> discardDraft() async {
    await DraftService.clearDraft();
  }

  // === 模板 ===

  void applyTemplate(DiaryTemplate template) {
    loadContent(template.content);
    _currentPageIndex = 0;
    _isDirty = false;
    _startDraftTimer();
    notifyListeners();
  }

  // === Tags ===

  void addTag(String tag) {
    final normalized = tag.trim().toLowerCase();
    if (normalized.isEmpty || _tags.contains(normalized) || _tags.length >= 10) {
      return;
    }
    _tags.add(normalized);
    _isDirty = true;
    notifyListeners();
  }

  void removeTag(String tag) {
    _tags.remove(tag);
    _isDirty = true;
    notifyListeners();
  }

  void setTags(List<String> tags) {
    _tags = tags;
    notifyListeners();
  }

  // === Images ===

  void addPlacedImage(String path, double centerX, double centerY) {
    final placed = PlacedImage(
      path: path,
      dx: centerX - 100,
      dy: centerY - 75,
    );
    _ensurePageListsLength(totalPages);
    if (_currentPageIndex < _pageImages.length) {
      _pageImages[_currentPageIndex].add(placed);
    }
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  /// 更新当前页的图片列表（移动、删除等操作）
  void updateCurrentPageImages(List<PlacedImage> images) {
    _ensurePageListsLength(totalPages);
    if (_currentPageIndex < _pageImages.length) {
      _pageImages[_currentPageIndex] = images;
    }
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  // === Audios ===

  void addPlacedAudio(PlacedAudio audio) {
    _ensurePageListsLength(totalPages);
    if (_currentPageIndex < _pageAudios.length) {
      _pageAudios[_currentPageIndex].add(audio);
    }
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  void removePlacedAudio(int pageIndex, int audioIndex) {
    if (pageIndex < _pageAudios.length) {
      final audios = _pageAudios[pageIndex];
      if (audioIndex < audios.length) {
        final audio = audios[audioIndex];
        audios.removeAt(audioIndex);
        _isDirty = true;
        DiaryAudioService.deleteAudio(audio.path).catchError((_) {});
        notifyListeners();
      }
    }
  }

  void updatePlacedAudio(int pageIndex, int audioIndex, PlacedAudio audio) {
    if (pageIndex < _pageAudios.length) {
      final audios = _pageAudios[pageIndex];
      if (audioIndex < audios.length) {
        audios[audioIndex] = audio;
        _isDirty = true;
        notifyListeners();
      }
    }
  }

  /// 更新当前页的录音列表（移动、删除等操作）
  void updateCurrentPageAudios(List<PlacedAudio> audios) {
    _ensurePageListsLength(totalPages);
    if (_currentPageIndex < _pageAudios.length) {
      _pageAudios[_currentPageIndex] = audios;
    }
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  // === Stickers ===

  void addSticker(PlacedSticker sticker) {
    _stickers.add(sticker);
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  void removeSticker(int index) {
    if (index >= 0 && index < _stickers.length) {
      _stickers.removeAt(index);
      _isDirty = true;
      notifyListeners();
    }
  }

  void updateSticker(int index, PlacedSticker sticker) {
    if (index >= 0 && index < _stickers.length) {
      _stickers[index] = sticker;
      _isDirty = true;
      notifyListeners();
    }
  }

  // === 工具方法 ===

  /// 确保图片/录音列表长度与页数匹配
  void _ensurePageListsLength(int pageCount) {
    while (_pageImages.length < pageCount) {
      _pageImages.add([]);
    }
    while (_pageAudios.length < pageCount) {
      _pageAudios.add([]);
    }
  }

  @override
  void dispose() {
    _cancelDraftTimer();
    super.dispose();
  }
}
