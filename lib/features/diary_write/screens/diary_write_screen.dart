import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/toast.dart';
import '../services/draft_service.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../voice_recording/screens/audio_recorder_screen.dart';
import '../../../data/models/placed_audio.dart';
import '../../../data/repositories/diary_repository.dart';
import '../providers/diary_write_provider.dart';
import '../widgets/diary_page.dart';
import '../../achievements/providers/achievement_provider.dart';
import '../../achievements/widgets/achievement_unlock_dialog.dart';
import '../../mood/widgets/mood_selector.dart';
import '../../templates/widgets/template_selector.dart';
import '../widgets/image_picker_bar.dart';
import '../services/image_service.dart';
import '../widgets/page_turn_hint.dart';
import '../../stickers/widgets/sticker_picker.dart';
import '../../stickers/widgets/sticker_layer.dart';
import '../../stickers/models/sticker.dart';
import '../../../data/models/placed_image.dart';
import '../../diary_detail/screens/diary_detail_screen.dart';

class DiaryWriteScreen extends StatefulWidget {
  const DiaryWriteScreen({super.key});

  @override
  State<DiaryWriteScreen> createState() => _DiaryWriteScreenState();
}

class _DiaryWriteScreenState extends State<DiaryWriteScreen> {
  late PageController _pageController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _checkedDraft = false;
  bool _showedTemplate = false;
  bool _isImageInteracting = false;
  Timer? _imageInteractionTimer;
  bool _hasDraft = false;
  bool _isLoadingPage = false; // 防止程序修改 controller 时触发 onContentChanged
  bool _isHandlingPageChange = false; // 防止 onPageChanged 重入

  final ValueNotifier<double> _pageNotifier = ValueNotifier(0);
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDraft();
    });
  }

  void _onPageScroll() {
    if (!_pageController.hasClients ||
        !_pageController.position.haveDimensions) return;

    final page = _pageController.page ?? 0;
    _pageNotifier.value = page;

    final isNearInteger = (page - page.round()).abs() < 0.01;
    if (_isAnimating && isNearInteger) {
      _isAnimating = false;
    } else if (!_isAnimating && !isNearInteger) {
      _isAnimating = true;
    }
  }

  Future<void> _checkDraft() async {
    if (_checkedDraft) return;
    _checkedDraft = true;

    final provider = context.read<DiaryWriteProvider>();
    if (provider.isEditing) {
      final title = provider.editingEntry?.title ?? '';
      if (title != '无标题') {
        _titleController.text = title;
      }
      // 加载当前页内容到控制器
      _loadPageContent(0);
      return;
    }

    final draft = await provider.loadDraft();
    if (!mounted) return;
    if (draft == null) {
      _showTemplateIfNeeded();
      return;
    }

    setState(() => _hasDraft = true);
    _pendingDraft = draft;
  }

  DraftData? _pendingDraft;

  void _restoreDraft() {
    final provider = context.read<DiaryWriteProvider>();
    if (_pendingDraft != null) {
      provider.restoreDraft(_pendingDraft!);
      _titleController.text = _pendingDraft!.title;
      _loadPageContent(0);
      _showedTemplate = true;
    }
    setState(() {
      _hasDraft = false;
      _pendingDraft = null;
    });
  }

  Future<void> _dismissDraft() async {
    final provider = context.read<DiaryWriteProvider>();
    await provider.discardDraft();
    setState(() {
      _hasDraft = false;
      _pendingDraft = null;
    });
    _showTemplateIfNeeded();
  }

  Future<void> _showTemplateIfNeeded() async {
    if (_showedTemplate) return;
    _showedTemplate = true;

    final provider = context.read<DiaryWriteProvider>();
    if (provider.isEditing) return;
    if (provider.content.trim().isNotEmpty) return;

    final template = await TemplateSelector.show(context);
    if (template != null && mounted) {
      provider.applyTemplate(template);
      _loadPageContent(0);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _pageNotifier.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _imageInteractionTimer?.cancel();
    super.dispose();
  }

  /// 加载指定页内容到控制器
  void _loadPageContent(int pageIndex) {
    _isLoadingPage = true;
    final provider = context.read<DiaryWriteProvider>();
    final pageText = provider.getPageText(pageIndex);
    _contentController.text = pageText;
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: pageText.length),
    );
    _isLoadingPage = false;
  }

  /// 原子化切页：保存旧页 → 更新页码 → 加载新页 → 一次性重建
  void _syncAndSwitchPage(int newIndex) {
    if (_isHandlingPageChange) return;
    _isHandlingPageChange = true;

    final provider = context.read<DiaryWriteProvider>();
    final oldIndex = provider.currentPageIndex;

    if (newIndex == oldIndex) {
      _isHandlingPageChange = false;
      return;
    }

    // 1. 保存旧页内容到数组（不触发重建）
    provider.saveCurrentPageText(_contentController.text);

    // 2. 更新页码 + 确保数组长度（不触发重建）
    provider.setCurrentPageDirect(newIndex);

    // 3. 加载新页内容到 controller
    _isLoadingPage = true;
    final pageText = provider.getPageText(newIndex);
    _contentController.text = pageText;
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: pageText.length),
    );
    _isLoadingPage = false;

    // 4. 同步 PageView 滚动位置（会触发 onPageChanged，被 _isHandlingPageChange 挡住）
    _pageController.jumpToPage(newIndex);

    // 5. 一次性触发重建（此时 controller 已是新页内容）
    provider.notifyPageChanged();

    _isHandlingPageChange = false;
  }

  Future<void> _save() async {
    final provider = context.read<DiaryWriteProvider>();

    // 同步当前页 controller 内容到数组
    provider.saveCurrentPageText(_contentController.text);

    if (provider.content.trim().isEmpty) {
      Toast().show(context, '日记内容不能为空', ToastType.warning);
      return;
    }

    try {
      final hasMood = provider.mood.isNotEmpty;
      final wordCount = provider.totalWordCount;
      final hasImages = provider.allPlacedImages.isNotEmpty;
      final hasAudios = provider.currentPageAudios.isNotEmpty;
      final hasTags = provider.tags.isNotEmpty;

      final entryId = await provider.save(_titleController.text);
      if (!mounted) return;
      _titleController.clear();
      _contentController.clear();
      _pageController.jumpToPage(0);
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
    final provider = context.read<DiaryWriteProvider>();
    provider.clear();
    _titleController.clear();
    _contentController.clear();
    _pageController.jumpToPage(0);
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
                  if (confirmed && mounted) {
                    provider.clear();
                    Navigator.of(context).pop();
                  }
                } else if (mounted) {
                  provider.clear();
                  Navigator.of(context).pop();
                }
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
          // Draft recovery banner
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
          // Page content area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      physics: _isImageInteracting
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      onPageChanged: (index) {
                        _syncAndSwitchPage(index);
                      },
                      itemCount: provider.totalPages + 1, // +1 为空白占位页
                      itemBuilder: (context, index) {
                        return ValueListenableBuilder<double>(
                          valueListenable: _pageNotifier,
                          builder: (context, page, child) {
                            final refPage =
                                _isAnimating ? page : page.roundToDouble();
                            final delta = index - refPage;
                            final opacity =
                                (1 - delta.abs() * 0.3).clamp(0.0, 1.0);
                            final angle = delta * 0.12;

                            return Transform(
                              alignment: delta > 0
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(angle),
                              child: Opacity(
                                opacity: opacity,
                                child: child,
                              ),
                            );
                          },
                          child: DiaryPage(
                            pageIndex: index,
                            pageContent: index < provider.totalPages
                                ? provider.getPageText(index)
                                : '',
                            isEditable: index == provider.currentPageIndex,
                            controller: index == provider.currentPageIndex
                                ? _contentController
                                : null,
                            initialTitle:
                                index == 0 ? _titleController.text : null,
                            onTitleChanged: (value) {
                              _titleController.text = value;
                              provider.markDirty();
                            },
                            onContentChanged: (value, width) {
                              if (_isLoadingPage) return;
                              final oldPageIndex = provider.currentPageIndex;
                              final cursorOffset = _contentController.selection.start;
                              final result = provider.updateCurrentPageText(value, cursorOffset);
                              final newPageIndex = result['pageIndex'] as int;
                              final newCursorOffset = result['cursorOffset'] as int;
                              final newText = result['text'] as String;

                              _isLoadingPage = true;
                              if (newPageIndex != oldPageIndex) {
                                // 光标跨页：跳转到新页
                                _contentController.text = newText;
                                _contentController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: newCursorOffset),
                                );
                                _pageController.jumpToPage(newPageIndex);
                              } else {
                                // 同页：更新光标位置
                                _contentController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: newCursorOffset),
                                );
                              }
                              _isLoadingPage = false;
                            },
                            onImagesChanged: (images) {
                              provider.updateCurrentPageImages(images);
                            },
                            onAudiosChanged: (audios) {
                              provider.updateCurrentPageAudios(audios);
                            },
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
                            images: provider.currentPageImages,
                            audios: provider.currentPageAudios,
                          ),
                        );
                      },
                    ),

                    // Sticker layer
                    Positioned.fill(
                      child: StickerLayer(
                        stickers: provider.stickers,
                        onStickerUpdated: (index, sticker) =>
                            provider.updateSticker(index, sticker),
                        onStickerDeleted: (index) =>
                            provider.removeSticker(index),
                      ),
                    ),

                    // Page turn hint
                    Positioned(
                      bottom: 8,
                      right: 16,
                      child: PageTurnHint(
                          visible: provider.totalPages > 1 &&
                              provider.currentPageIndex == provider.totalPages - 1),
                    ),

                    // Page indicator
                    if (provider.totalPages > 1)
                      Positioned(
                        bottom: 8,
                        left: 16,
                        child: Text(
                          '${(provider.currentPageIndex + 1).clamp(1, provider.totalPages)} / ${provider.totalPages}',
                          style: TextStyle(
                            fontSize: 12,
                            color: subtleColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Bottom toolbar
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
                    final offset =
                        provider.currentPageImages.length * 30.0;
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
                    final offset =
                        provider.currentPageImages.length * 30.0;
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
                    final existingCount = provider.currentPageAudios.length;
                    final offset = existingCount * 30.0;
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
                    _loadPageContent(0);
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
              Text(
                '${provider.totalWordCount}字',
                style: TextStyle(
                  fontSize: 12,
                  color: subtleColor.withValues(alpha: 0.6),
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
