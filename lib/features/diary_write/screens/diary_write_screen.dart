import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/toast.dart';
import '../services/draft_service.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../voice_recording/screens/audio_recorder_screen.dart';
import '../../../data/models/placed_audio.dart';
import '../../../data/repositories/diary_repository.dart';
import '../providers/diary_write_provider.dart';
import '../widgets/diary_paper.dart';
import '../../achievements/providers/achievement_provider.dart';
import '../../achievements/widgets/achievement_unlock_dialog.dart';
import '../../mood/widgets/mood_selector.dart';
import '../../templates/widgets/template_selector.dart';
import '../widgets/image_picker_bar.dart';
import '../services/image_service.dart';
import '../../stickers/widgets/sticker_picker.dart';
import '../../stickers/widgets/sticker_layer.dart';
import '../../stickers/models/sticker.dart';
import '../../../data/models/placed_image.dart';
import '../../diary_detail/screens/diary_detail_screen.dart';

/// 日记编写页（单页）。
///
/// 与旧版的关键差异：不再有 `PageView` / 页码 / 翻页提示。
/// 纸页高度随正文增长，整个书写区是一个 `SingleChildScrollView`。
class DiaryWriteScreen extends StatefulWidget {
  const DiaryWriteScreen({super.key});

  @override
  State<DiaryWriteScreen> createState() => _DiaryWriteScreenState();
}

class _DiaryWriteScreenState extends State<DiaryWriteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late DiaryWriteProvider _provider;

  /// 已同步进控制器的 provider 版本号
  int _syncedRevision = 0;

  bool _checkedDraft = false;
  bool _showedTemplate = false;
  bool _isImageInteracting = false;
  Timer? _imageInteractionTimer;
  bool _hasDraft = false;
  DraftData? _pendingDraft;

  @override
  void initState() {
    super.initState();
    _provider = context.read<DiaryWriteProvider>();

    // 编辑态下，正文在进入本页之前已由详情页 `loadForEdit()` 装好
    _syncedRevision = _provider.revision;
    _contentController.text = _provider.content;
    _provider.addListener(_onProviderChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDraft();
    });
  }

  /// provider 只在「载入 / 清空 / 恢复草稿 / 应用模板」时自增 revision。
  ///
  /// 打字路径不会走到这里 —— 这正是避免打断输入法组字、进而丢字的关键。
  void _onProviderChanged() {
    final revision = _provider.revision;
    if (revision == _syncedRevision) return;
    _syncedRevision = revision;

    final text = _provider.content;
    if (_contentController.text != text) {
      _contentController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    // 标题同样跟着换页源走：编辑态取日记标题，清空/保存后归零
    final entry = _provider.editingEntry;
    if (entry != null) {
      final title = entry.title == '无标题' ? '' : entry.title;
      if (_titleController.text != title) {
        _titleController.text = title;
      }
    } else if (text.isEmpty && _titleController.text.isNotEmpty) {
      _titleController.clear();
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    _scrollController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _imageInteractionTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDraft() async {
    if (_checkedDraft) return;
    _checkedDraft = true;

    if (_provider.isEditing) {
      final title = _provider.editingEntry?.title ?? '';
      if (title != '无标题') {
        _titleController.text = title;
      }
      return;
    }

    final draft = await _provider.loadDraft();
    if (!mounted) return;
    if (draft == null) {
      _showTemplateIfNeeded();
      return;
    }

    setState(() => _hasDraft = true);
    _pendingDraft = draft;
  }

  void _restoreDraft() {
    if (_pendingDraft != null) {
      _provider.restoreDraft(_pendingDraft!);
      _titleController.text = _pendingDraft!.title;
      _showedTemplate = true;
    }
    setState(() {
      _hasDraft = false;
      _pendingDraft = null;
    });
  }

  Future<void> _dismissDraft() async {
    await _provider.discardDraft();
    setState(() {
      _hasDraft = false;
      _pendingDraft = null;
    });
    _showTemplateIfNeeded();
  }

  Future<void> _showTemplateIfNeeded() async {
    if (_showedTemplate) return;
    _showedTemplate = true;

    if (_provider.isEditing) return;
    if (_provider.content.trim().isNotEmpty) return;

    final template = await TemplateSelector.show(context);
    if (template != null && mounted) {
      _provider.applyTemplate(template);
    }
  }

  Future<void> _save() async {
    // 打字路径已实时同步，这里再兜一次底
    _provider.setContent(_contentController.text);

    if (_provider.content.trim().isEmpty) {
      Toast().show(context, '日记内容不能为空', ToastType.warning);
      return;
    }

    try {
      final hasMood = _provider.mood.isNotEmpty;
      final wordCount = _provider.totalWordCount;
      final hasImages = _provider.images.isNotEmpty;
      final hasAudios = _provider.audios.isNotEmpty;
      final hasTags = _provider.tags.isNotEmpty;

      final entryId = await _provider.save(_titleController.text);
      if (!mounted) return;
      _titleController.clear();
      _contentController.clear();
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      _showedTemplate = false;
      _hasDraft = false;

      Toast().show(context, '日记已保存', ToastType.success);

      _navigateToDetail(entryId, Navigator.of(context));

      _checkAchievements(
        hasMood: hasMood,
        wordCount: wordCount,
        hasImages: hasImages,
        hasAudios: hasAudios,
        hasTags: hasTags,
      );
    } catch (e) {
      if (mounted) {
        Toast().show(context, '保存失败，请重试', ToastType.error);
      }
    }
  }

  void _clear() {
    _provider.clear();
    _titleController.clear();
    _contentController.clear();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _checkAchievements({
    required bool hasMood,
    required int wordCount,
    required bool hasImages,
    required bool hasAudios,
    required bool hasTags,
  }) async {
    if (!mounted) return;
    final repo = DiaryRepository();
    final allEntries = await repo.getAllEntries();
    final streakDays = await repo.getStreakDays();
    if (!mounted) return;

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final entryDatesThisMonth = allEntries
        .where(
            (e) => e.createdAt.year == now.year && e.createdAt.month == now.month)
        .map((e) => e.createdAt.day)
        .toSet();
    final monthPerfect = entryDatesThisMonth.length >= daysInMonth;

    final featureUsage = <String, int>{
      'photo':
          (hasImages || allEntries.any((e) => e.images.isNotEmpty)) ? 1 : 0,
      'audio':
          (hasAudios || allEntries.any((e) => e.audios.isNotEmpty)) ? 1 : 0,
      'tag': (hasTags || allEntries.any((e) => e.tags.isNotEmpty)) ? 1 : 0,
      'lock': allEntries.any((e) => e.isLocked) ? 1 : 0,
      'total_words': allEntries.fold(0, (sum, e) => sum + e.wordCount),
      'month_perfect': monthPerfect ? 1 : 0,
    };

    final achievementProvider = context.read<AchievementProvider>();
    final newAchievements = await achievementProvider.checkAndUnlock(
      totalEntries: allEntries.length,
      streakDays: streakDays,
      featureUsage: featureUsage,
      newEntryWordCount: wordCount,
      newEntryHour: DateTime.now().hour,
      newEntryHasMood: hasMood,
    );

    if (mounted && newAchievements.isNotEmpty) {
      for (final achievement in newAchievements) {
        if (!mounted) return;
        await AchievementUnlockDialog.show(context, achievement);
        await achievementProvider.markAsRead(achievement.id);
      }
    }
  }

  Future<void> _navigateToDetail(int entryId, NavigatorState navigator) async {
    final repo = DiaryRepository();
    final entry = await repo.getEntryById(entryId);
    if (entry == null) return;
    final allEntries = await repo.getEntriesByDate(entry.createdAt);
    final index = allEntries.indexWhere((e) => e.id == entry.id);
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => DiaryDetailScreen(
          allEntries: allEntries,
          initialIndex: index >= 0 ? index : 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiaryWriteProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: isDark
              ? null
              : BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.pinkLight,
                      AppColors.blueLight,
                    ],
                  ),
                ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: 20, color: subtleColor),
              onPressed: () async {
                if (provider.isDirty) {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: '未保存的日记',
                    message: '有未保存的内容，确定要离开吗？',
                    confirmText: '离开',
                  );
                  if (!context.mounted) return;
                  if (!confirmed) return;
                  provider.clear();
                  Navigator.of(context).pop();
                  return;
                }
                provider.clear();
                Navigator.of(context).pop();
              },
            ),
            title: Text(
              DateFormatter.formatFull(DateTime.now()),
              style: AppTextStyles.handwritingTitle.copyWith(
                color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                fontSize: 16,
              ),
            ),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: _save,
                child: Text(
                  '保存',
                  style: AppTextStyles.body.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // 草稿恢复条
          if (_hasDraft)
            MaterialBanner(
              content: Text(
                '发现未完成的草稿',
                style: AppTextStyles.body.copyWith(
                  color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                ),
              ),
              backgroundColor:
                  isDark ? AppColors.darkCardBackgroundAlt : AppColors.cardBackgroundAlt,
              leading: Icon(Icons.description_outlined, color: accentColor),
              actions: [
                TextButton(
                  onPressed: _restoreDraft,
                  child: Text('恢复', style: TextStyle(color: accentColor)),
                ),
                IconButton(
                  onPressed: _dismissDraft,
                  icon: Icon(Icons.close, size: 18, color: subtleColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),

          // 书写区：整页滚动，纸页高度随内容增长
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: _scrollController,
                  physics: _isImageInteracting
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                    vertical: AppDimensions.md,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DiaryPaper(
                        minHeight: constraints.maxHeight - AppDimensions.md * 2,
                        titleController: _titleController,
                        contentController: _contentController,
                        wordCount: provider.wordCount,
                        mediaExtent: provider.mediaExtent,
                        onTitleChanged: (_) => provider.markDirty(),
                        onContentChanged: provider.setContent,
                        images: provider.images,
                        audios: provider.audios,
                        onImagesChanged: provider.updateImages,
                        onAudiosChanged: provider.updateAudios,
                        onInteractionStart: () {
                          _isImageInteracting = true;
                          _imageInteractionTimer?.cancel();
                          _imageInteractionTimer = Timer(
                            const Duration(seconds: 5),
                            () {
                              if (_isImageInteracting) {
                                setState(() => _isImageInteracting = false);
                              }
                            },
                          );
                        },
                        onInteractionEnd: () {
                          _isImageInteracting = false;
                          _imageInteractionTimer?.cancel();
                        },
                        onImageView: _showImageViewer,
                      ),
                      // 贴纸图层：与纸页同坐标系，随纸页一起滚动
                      Positioned.fill(
                        child: StickerLayer(
                          stickers: provider.stickers,
                          onStickerUpdated: (index, sticker) =>
                              provider.updateSticker(index, sticker),
                          onStickerDeleted: (index) =>
                              provider.removeSticker(index),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 底部工具栏
          _buildBottomToolbar(provider, isDark, accentColor, subtleColor),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(
    DiaryWriteProvider provider,
    bool isDark,
    Color accentColor,
    Color subtleColor,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.darkCardBackgroundAlt : AppColors.cardBackgroundAlt,
        border: Border(
          top: BorderSide(
            color: subtleColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Mood + Tags
          Row(
            children: [
              MoodSelector(
                selectedMood: provider.mood,
                selectedLabel: provider.moodLabel,
                intensity: provider.moodIntensity,
                note: provider.moodNote,
                onMoodSelected: (emoji) => provider.setMood(emoji),
                onMoodChanged: (emoji, label, intensity, note) {
                  provider.setMoodData(emoji, label, intensity, note);
                },
                compact: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...provider.tags.map((tag) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onLongPress: () => provider.removeTag(tag),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: accentColor.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                    fontSize: 11, color: accentColor),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (provider.tags.length < 10)
                        GestureDetector(
                          onTap: () => _showAddTagDialog(provider),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: subtleColor.withValues(alpha: 0.3),
                                  style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add,
                                    size: 12, color: subtleColor),
                                const SizedBox(width: 2),
                                Text('标签',
                                    style: TextStyle(
                                        fontSize: 11, color: subtleColor)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Media buttons + Template + Clear + Word count
          Row(
            children: [
              _ToolIcon(
                icon: Icons.camera_alt_outlined,
                onTap: () async {
                  final path = await ImagePickerBar.pickFromCamera();
                  if (path != null && mounted) {
                    final size = MediaQuery.of(context).size;
                    final offset = provider.images.length * 30.0;
                    provider.addPlacedImage(
                        path, size.width / 2 + offset, size.height / 3 + offset);
                  }
                },
                color: accentColor,
              ),
              const SizedBox(width: 4),
              _ToolIcon(
                icon: Icons.image_outlined,
                onTap: () async {
                  final path = await ImagePickerBar.pickFromGallery();
                  if (path != null && mounted) {
                    final size = MediaQuery.of(context).size;
                    final offset = provider.images.length * 30.0;
                    provider.addPlacedImage(
                        path, size.width / 2 + offset, size.height / 3 + offset);
                  }
                },
                color: accentColor,
              ),
              const SizedBox(width: 4),
              _ToolIcon(
                icon: Icons.mic_outlined,
                onTap: () async {
                  final record = await AudioRecorderScreen.show(context);
                  if (record != null && mounted) {
                    final size = MediaQuery.of(context).size;
                    final offset = provider.audios.length * 30.0;
                    final placed = PlacedAudio(
                      path: record.path,
                      durationMs: record.durationMs,
                      createdAt: record.createdAt,
                      dx: size.width / 2 - 110 + offset,
                      dy: size.height / 3 + offset,
                    );
                    provider.addPlacedAudio(placed);
                  }
                },
                color: accentColor,
              ),
              const SizedBox(width: 4),
              _ToolIcon(
                icon: Icons.emoji_emotions_outlined,
                onTap: () async {
                  await StickerPicker.show(context, (Sticker sticker) {
                    final size = MediaQuery.of(context).size;
                    provider.addSticker(sticker.toPlacedSticker(
                      dx: size.width / 2 - 24,
                      dy: size.height / 3 - 24,
                    ));
                  });
                },
                color: accentColor,
              ),
              const SizedBox(width: 4),
              _ToolIcon(
                icon: Icons.auto_awesome,
                onTap: () async {
                  final template = await TemplateSelector.show(context);
                  if (template != null && mounted) {
                    provider.applyTemplate(template);
                  }
                },
                color: accentColor,
              ),
              const SizedBox(width: 4),
              _ToolIcon(
                icon: Icons.delete_outline,
                onTap: _clear,
                color: subtleColor,
              ),
              const Spacer(),
              ValueListenableBuilder<int>(
                valueListenable: provider.wordCount,
                builder: (_, count, __) => Text(
                  '$count字',
                  style: TextStyle(
                    fontSize: 12,
                    color: subtleColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog(DiaryWriteProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
          title: Text('添加标签', style: AppTextStyles.cardTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '输入标签名',
              prefixText: '# ',
              hintStyle: AppTextStyles.body.copyWith(
                color: isDark
                    ? AppColors.darkPlaceholderText
                    : AppColors.placeholderText,
              ),
            ),
            onSubmitted: (value) {
              final tag = value.trim().replaceAll(RegExp(r'^#+'), '');
              if (tag.isNotEmpty) provider.addTag(tag);
              Navigator.pop(ctx);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkSubtleText
                          : AppColors.subtleText)),
            ),
            TextButton(
              onPressed: () {
                final tag =
                    controller.text.trim().replaceAll(RegExp(r'^#+'), '');
                if (tag.isNotEmpty) provider.addTag(tag);
                Navigator.pop(ctx);
              },
              child: Text('添加',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.darkGoldAccent
                          : AppColors.goldAccent)),
            ),
          ],
        );
      },
    );
  }

  /// 全屏查看图片
  void _showImageViewer(PlacedImage img) async {
    final file = await ImageService.getImageFile(img.path);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ToolIcon({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
