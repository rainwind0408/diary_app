import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/word_counter.dart';
import '../../../data/models/diary_entry.dart';
import '../../../data/models/placed_audio.dart';
import '../../../data/models/placed_image.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../chat/models/diary_insight.dart';
import '../../stickers/models/placed_sticker.dart';
import '../../templates/models/template.dart';
import '../../weather/services/weather_service.dart';
import '../services/audio_service.dart';
import '../services/draft_service.dart';

/// 单页写作状态。
///
/// 与旧版（v3.x 多页分页）的关键差异：
/// 不再维护 `List<List<String>>` 分页数组，正文只有一个 [content] 字符串，
/// 纸页高度由内容自然增长 —— 因此"跨页整段丢字"这一整类问题不复存在。
///
/// `PlacedImage.pageIndex` / `PlacedAudio.pageIndex` 字段保留（数据库与
/// 导入导出格式兼容），但单页模型下恒为 0。
class DiaryWriteProvider extends ChangeNotifier {
  /// 允许注入 Repository，便于单元测试。
  /// 旧版在这里硬编码 `DiaryRepository()`，是"写不出测试"的直接原因。
  DiaryWriteProvider({DiaryRepository? repository})
      : _repository = repository ?? DiaryRepository();

  final DiaryRepository _repository;

  // ==================== 写日记时的现场快照 ====================

  /// 进入写日记页时**预热**好的天气 / 地点快照。
  ///
  /// ★ 为什么是预热而不是「点保存时现取」：定位 + 两个网络请求最坏要十几秒，
  /// 让用户点完保存干等是不能接受的。预热放在进页面那一刻，等用户写完
  /// （通常几分钟）早就就绪了；保存时零等待。
  DiarySnapshot? _snapshot;
  bool _snapshotLoading = false;

  /// 快照的代际号。清空后自增，用来作废旧的在途请求 ——
  /// 否则「上一轮写作」的请求回来时会污染「这一轮」的快照。
  int _snapshotGen = 0;

  /// 预热现场快照。幂等 —— 重复调用不会重复请求。
  ///
  /// 编辑已有日记时**不采集**：那是「当时」的现场，不该被改写成现在。
  Future<void> warmUpSnapshot() async {
    if (_editingEntry != null || _snapshot != null || _snapshotLoading) return;
    final gen = _snapshotGen;
    _snapshotLoading = true;
    try {
      final result = await WeatherService.captureForDiary();
      if (gen == _snapshotGen) _snapshot = result;
    } finally {
      if (gen == _snapshotGen) _snapshotLoading = false;
    }
  }

  // ==================== 单页正文 ====================

  String _content = '';

  /// 仅在「载入 / 清空 / 恢复草稿 / 应用模板」时自增。
  ///
  /// 编辑器监听它来决定是否把 provider 内容重新灌回 `TextEditingController`。
  /// **打字路径不自增、也不 `notifyListeners()`** —— 这正是消除
  /// 「光标跳文末 / 中文输入法丢字」的关键：输入法组字期间任何
  /// `controller.text = ...` 赋值都会清空组字缓冲。
  int _revision = 0;
  int get revision => _revision;

  /// 完整正文
  String get content => _content;

  /// 字数独立推送，避免打字时整页重建
  final ValueNotifier<int> wordCount = ValueNotifier<int>(0);

  int get totalWordCount => wordCount.value;

  // ==================== 编辑状态 ====================

  DiaryEntry? _editingEntry;
  bool _isDirty = false;
  Timer? _draftTimer;
  String _mood = '';
  String _moodLabel = '';
  int _moodIntensity = 3;
  String _moodNote = '';
  List<String> _tags = [];
  List<PlacedSticker> _stickers = [];

  // ==================== 媒体（单页坐标） ====================

  List<PlacedImage> _images = [];
  List<PlacedAudio> _audios = [];

  // ==================== Getters ====================

  String get mood => _mood;
  String get moodLabel => _moodLabel;
  int get moodIntensity => _moodIntensity;
  String get moodNote => _moodNote;
  DiaryEntry? get editingEntry => _editingEntry;
  bool get isDirty => _isDirty;
  bool get isEditing => _editingEntry != null;
  List<String> get tags => _tags;
  List<PlacedSticker> get stickers => _stickers;

  /// 当前纸页上的图片（自由拖放定位）
  List<PlacedImage> get images => _images;

  /// 当前纸页上的录音
  List<PlacedAudio> get audios => _audios;

  /// 兼容旧调用名
  List<PlacedImage> get allPlacedImages => _images;

  /// 媒体占据的最大纵向范围（相对纸页顶部）。
  ///
  /// 媒体用 `Positioned` 绝对定位，**不会撑开父级**；纸页需要据此设置
  /// `minHeight`，否则图片放在文字下方时会超出纸页边界、看起来"丢了"。
  double get mediaExtent {
    var maxBottom = 0.0;
    for (final img in _images) {
      maxBottom = math.max(maxBottom, img.dy + img.height * img.scale);
    }
    for (final audio in _audios) {
      maxBottom = math.max(maxBottom, audio.dy + audio.height);
    }
    return maxBottom;
  }

  // ==================== 正文写入 ====================

  /// 打字路径：**只写不通知**。
  ///
  /// 调用时机是 `TextField.onChanged`；此时控制器与 [_content] 已经一致，
  /// 回灌控制器反而会打断输入法组字。字数通过 [wordCount] 单独推送。
  void setContent(String text) {
    if (text == _content) return;
    _content = text;
    _isDirty = true;
    _startDraftTimer();
    wordCount.value = WordCounter.count(text);
  }

  /// 整体替换正文（载入 / 清空 / 恢复草稿 / 应用模板）。
  ///
  /// 自增 [revision]，编辑器据此把内容重新灌进控制器。
  void _replaceContent(String text) {
    _content = text;
    _revision++;
    wordCount.value = WordCounter.count(text);
    _isDirty = false;
  }

  // ==================== 心情 ====================

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

  // ==================== 保存 ====================

  Future<int> save(String title) async {
    final fullContent = _content;
    final count = WordCounter.count(fullContent);

    // 从正文里提取 #标签，与手动标签合并。
    // ⚠️ 规则统一走 [DiaryInsight.hashTagsIn] —— 以前这里写的是 `\B#\w+`，
    //    而 Dart 的 `\w` 不含中文，导致 `#跑步` 这种写法**一个标签都抽不出来**。
    //    两处规则必须一致，否则会出现「AI 推荐了但保存时不算」。
    final contentTags = DiaryInsight.hashTagsIn(fullContent).toSet();
    final allTags = {
      ..._tags.map((t) => t.toLowerCase()),
      ...contentTags,
    }.toList();

    // 单页化：媒体统一归属第 0 页
    final images = _images.map((img) => img..pageIndex = 0).toList();
    final audios = _audios.map((audio) => audio..pageIndex = 0).toList();

    int resultId;
    if (_editingEntry != null) {
      final updated = _editingEntry!.copyWith(
        title: title.isEmpty ? '无标题' : title,
        content: fullContent,
        mood: _mood,
        moodIntensity: _moodIntensity,
        moodNote: _moodNote,
        moodLabel: _moodLabel,
        wordCount: count,
        tags: allTags,
        images: images,
        audios: audios,
        stickers: _stickers,
        updatedAt: DateTime.now(),
      );
      await _repository.updateEntry(updated);
      resultId = updated.id!;
    } else {
      // 快照**只在这里（新建）写入** —— 编辑分支走 copyWith 且不带这两个参数，
      // 于是旧日记的天气 / 地点原样保留，不会被改写成「今天」。
      final entry = DiaryEntry(
        title: title.isEmpty ? '无标题' : title,
        content: fullContent,
        mood: _mood,
        moodIntensity: _moodIntensity,
        moodNote: _moodNote,
        moodLabel: _moodLabel,
        wordCount: count,
        tags: allTags,
        images: images,
        audios: audios,
        stickers: _stickers,
        weather: _snapshot?.weather ?? '',
        location: _snapshot?.location ?? '',
      );
      resultId = await _repository.insertEntry(entry);
    }

    await DraftService.clearDraft();
    _cancelDraftTimer();
    clear();
    return resultId;
  }

  // ==================== 加载 ====================

  void loadForEdit(DiaryEntry entry) {
    _editingEntry = entry;
    _mood = entry.mood;
    _moodLabel = entry.moodLabel;
    _moodIntensity = entry.moodIntensity;
    _moodNote = entry.moodNote;

    // 兼容旧格式：移除 "--- 第 N 页 ---" 分隔符
    _replaceContent(_migrateOldFormat(entry.content));

    _tags = List.from(entry.tags);
    _stickers = List.from(entry.stickers);
    _images = _flattenImages(entry.images);
    _audios = _flattenAudios(entry.audios);

    _cancelDraftTimer();
    notifyListeners();
  }

  /// 兼容旧格式：移除 "--- 第 N 页 ---" 分隔符
  String _migrateOldFormat(String content) {
    return content.replaceAll(RegExp(r'\n*--- 第 \d+ 页 ---\n*'), '\n');
  }

  /// 旧多页数据的「页高」估算：标题区 + 15 行正文。
  ///
  /// 只用于把多页媒体的 `dy` 补偿到单页坐标系。允许十几像素的偏差 ——
  /// 媒体本就是自由摆放的贴图，位置不需要像素级复原。
  static const double _kLegacyPageStride = 28.0 * 15 + 96.0; // 516

  /// 把旧多页图片压平到单页坐标系
  List<PlacedImage> _flattenImages(List<PlacedImage> source) {
    return [
      for (final img in source)
        PlacedImage(
          path: img.path,
          dx: img.dx,
          dy: img.dy + img.pageIndex * _kLegacyPageStride,
          width: img.width,
          height: img.height,
          rotation: img.rotation,
          scale: img.scale,
          pageIndex: 0,
        ),
    ];
  }

  /// 把旧多页录音压平到单页坐标系
  List<PlacedAudio> _flattenAudios(List<PlacedAudio> source) {
    return [
      for (final audio in source)
        PlacedAudio(
          path: audio.path,
          durationMs: audio.durationMs,
          createdAt: audio.createdAt,
          dx: audio.dx,
          dy: audio.dy + audio.pageIndex * _kLegacyPageStride,
          width: audio.width,
          height: audio.height,
          pageIndex: 0,
        ),
    ];
  }

  // ==================== 清空 ====================

  void clear() {
    _mood = '';
    _moodLabel = '';
    _moodIntensity = 3;
    _moodNote = '';
    _editingEntry = null;
    _tags = [];
    _stickers = [];
    _images = [];
    _audios = [];
    _replaceContent('');
    _cancelDraftTimer();
    // 快照属于「这一次写作」：作废旧的在途请求，下次进页面重新预热
    _snapshotGen++;
    _snapshot = null;
    _snapshotLoading = false;
    notifyListeners();
  }

  // ==================== 脏标记 ====================

  void markDirty() {
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  // ==================== 草稿 ====================

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
    if (_content.trim().isEmpty) return;
    await DraftService.saveDraft(
      title: '',
      content: _content,
      mood: _mood,
    );
  }

  Future<DraftData?> loadDraft() async {
    return DraftService.loadDraft();
  }

  void restoreDraft(DraftData draft) {
    _mood = draft.mood;
    _editingEntry = null;
    _images = [];
    _audios = [];
    _replaceContent(draft.content);
    _startDraftTimer();
    notifyListeners();
  }

  Future<void> discardDraft() async {
    await DraftService.clearDraft();
  }

  // ==================== 模板 ====================

  void applyTemplate(DiaryTemplate template) {
    _replaceContent(template.content);
    _startDraftTimer();
    notifyListeners();
  }

  // ==================== 标签 ====================

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

  // ==================== 图片 ====================

  void addPlacedImage(String path, double centerX, double centerY) {
    _images.add(PlacedImage(
      path: path,
      dx: centerX - 100,
      dy: centerY - 75,
    ));
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  /// 整表替换图片（拖拽、缩放、删除后由图层回报）
  void updateImages(List<PlacedImage> images) {
    _images = images;
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  // ==================== 录音 ====================

  void addPlacedAudio(PlacedAudio audio) {
    _audios.add(audio);
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  /// 整表替换录音（拖拽、删除后由图层回报）
  void updateAudios(List<PlacedAudio> audios) {
    _audios = audios;
    _isDirty = true;
    _startDraftTimer();
    notifyListeners();
  }

  void removePlacedAudio(int index) {
    if (index < 0 || index >= _audios.length) return;
    final audio = _audios.removeAt(index);
    _isDirty = true;
    DiaryAudioService.deleteAudio(audio.path).catchError((_) {});
    notifyListeners();
  }

  // ==================== 贴纸 ====================

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

  // ==================== 生命周期 ====================

  @override
  void dispose() {
    _cancelDraftTimer();
    wordCount.dispose();
    super.dispose();
  }
}
