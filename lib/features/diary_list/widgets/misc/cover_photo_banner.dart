import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/widgets/full_image_viewer.dart';
import '../../../chat/models/chat_attachment.dart';
import '../../../chat/widgets/attachment_view.dart';
import '../../../diary_write/services/image_service.dart';
import '../../models/temp_cover.dart';

/// 首页顶部封面图卡片
///
/// 展示当前选中月份日记里的图片，横向轮播；默认第一张为「当前日期」的图片。
/// 高度约占屏幕的四分之一，并做上下限约束，避免小屏 / 横屏被压塌。
///
/// ## 两种图源
///
/// | 来源 | 传参 | 生命周期 |
/// |---|---|---|
/// | 日记里的正式图片 | [imagePaths] | 跟着日记走 |
/// | AI 刚生成的临时图 | [tempCovers] | 冷启动即消失 |
///
/// 有效列表 = `[...tempCovers, ...imagePaths]` —— **临时图永远排在最前**，
/// 因为「我刚生成的那张」是最想看到的，也绝不该和真实照片交错。
///
/// 预留 AI 生成图接口：[generatedImagePaths]（key 为原始图片相对路径，
/// value 为生成图的相对路径）语义是「**替换**某张真实照片」，
/// 与 [tempCovers] 的「**新增**一张独立图片」不是一回事，两者不通用。
class CoverPhotoBanner extends StatefulWidget {
  /// 待展示的图片相对路径（由 DiaryRepository.getMonthImagePaths 提供）
  final List<String> imagePaths;

  /// AI 生成图映射：原图相对路径 → 生成图相对路径。为空表示未接入 AI。
  final Map<String, String>? generatedImagePaths;

  /// 供无障碍与角标显示使用的月份标题，如「2026年9月」
  final String monthLabel;

  /// AI 刚生成、**重启后就会消失**的临时封面图（相对路径，新的在前）
  final List<TempCover> tempCovers;

  const CoverPhotoBanner({
    super.key,
    required this.imagePaths,
    this.generatedImagePaths,
    required this.monthLabel,
    this.tempCovers = const [],
  });

  @override
  State<CoverPhotoBanner> createState() => _CoverPhotoBannerState();
}

/// 轮播里的一格。临时图要额外画角标、且长按保存的语义不同，所以要区分来源。
class _CoverItem {
  final String relativePath;
  final TempCover? temp;

  const _CoverItem(this.relativePath, {this.temp});
}

class _CoverPhotoBannerState extends State<CoverPhotoBanner> {
  late PageController _pageController;
  int _currentPage = 0;
  int _lastItemCount = 0;
  int _lastTempCount = 0;

  @override
  void initState() {
    super.initState();
    _lastItemCount = _items.length;
    _lastTempCount = widget.tempCovers.length;
    _pageController = PageController(viewportFraction: 0.92);
  }

  /// 有效列表：临时图在前，正式图片在后
  List<_CoverItem> get _items => [
        for (final cover in widget.tempCovers)
          if (cover.isValid) _CoverItem(cover.relativePath, temp: cover),
        for (final path in widget.imagePaths)
          _CoverItem(_resolvePath(path)),
      ];

  @override
  void didUpdateWidget(CoverPhotoBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final items = _items;

    // ★ 新来了一张临时图 → 跳回第一页。
    //   用户刚生成的就是想看到它，停在原来的页上等于「什么都没发生」。
    //   注意：插入会让长度**变大**，原来那段「越界才跳回 0」的逻辑不会触发。
    if (widget.tempCovers.length > _lastTempCount) {
      _lastTempCount = widget.tempCovers.length;
      _lastItemCount = items.length;
      _currentPage = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
      return;
    }
    _lastTempCount = widget.tempCovers.length;

    // 月份切换后图片数量变化，若当前页越界则回到首张
    if (items.length != _lastItemCount) {
      _lastItemCount = items.length;
      if (_currentPage > 0 && _currentPage >= items.length) {
        _currentPage = 0;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 命中 AI 生成图则用生成图，否则回退原图
  String _resolvePath(String original) {
    final generated = widget.generatedImagePaths?[original];
    if (generated != null && generated.isNotEmpty) return generated;
    return original;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.sizeOf(context).height;
    // 约屏幕四分之一，但限制在 160~280 之间
    final bannerHeight = (screenHeight * 0.25).clamp(160.0, 280.0);

    final items = _items;
    if (items.isEmpty) {
      return _buildEmptyState(isDark, bannerHeight);
    }

    final showIndicator = items.length > 1;

    // 点开大图时要能看到**整组**图并左右滑，所以把完整路径列表一次算好传给每格。
    // 在 itemBuilder 里现算会是 O(n²)，而且每格各持一份容易不同步。
    final allPaths = [for (final item in items) item.relativePath];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: SizedBox(
        height: bannerHeight,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: items.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _CoverTile(
                    relativePath: item.relativePath,
                    isDark: isDark,
                    temp: item.temp,
                    allPaths: allPaths,
                    index: index,
                  ),
                );
              },
            ),
            // 页码角标：仅多张时显示。
            // 用不透明的深色底 + 细白边，避免叠在浅色图片上看不清
            if (showIndicator)
              Positioned(
                right: 20,
                bottom: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${items.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 空态：没有任何图片时，用配色渐变 + 装饰图形占位，避免留出视觉空洞
  Widget _buildEmptyState(bool isDark, double bannerHeight) {
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final cardBg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Container(
        height: bannerHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: cardBg,
          border: Border.all(color: accentColor.withValues(alpha: 0.15)),
          boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
        ),
        child: Stack(
          children: [
            // 右上角柔光装饰（纯代码绘制，不加载大图素材）
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.pinkLight.withValues(alpha: isDark ? 0.08 : 0.5),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.blueLight.withValues(alpha: isDark ? 0.06 : 0.45),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 32,
                    color: accentColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.monthLabel} 还没有图片',
                    style: AppTextStyles.label.copyWith(color: subtleColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '写日记时添加图片，会出现在这里',
                    style: TextStyle(
                      fontSize: 11,
                      color: subtleColor.withValues(alpha: 0.7),
                    ),
                  ),
                  // 「AI 生图会自动落在这里」是新能力，没有这一句用户不会知道
                  const SizedBox(height: 6),
                  Text(
                    '也可以长按右下角的助手，说「生成一张…」',
                    style: TextStyle(
                      fontSize: 11,
                      color: accentColor.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单张封面图
class _CoverTile extends StatefulWidget {
  final String relativePath;
  final bool isDark;

  /// 非 null 表示这是一张 AI 生成的临时图（要画角标）
  final TempCover? temp;

  /// 当前轮播里的**全部**图片相对路径（顺序与 [index] 一致）。
  /// 点开大图时整组传进去，才能左右滑动看其他图。
  final List<String> allPaths;

  /// 本格在 [allPaths] 里的下标
  final int index;

  const _CoverTile({
    required this.relativePath,
    required this.isDark,
    this.temp,
    this.allPaths = const [],
    this.index = 0,
  });

  @override
  State<_CoverTile> createState() => _CoverTileState();
}

class _CoverTileState extends State<_CoverTile> {
  Future<File>? _fileFuture;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void didUpdateWidget(_CoverTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relativePath != widget.relativePath) {
      _loadFile();
    }
  }

  void _loadFile() {
    _fileFuture = ImageService.getImageFile(widget.relativePath);
  }

  /// 长按 → 复用聊天页那套「保存到相册 / 分享」菜单。
  ///
  /// `showImageActions` 只吃一个 [ChatAttachment]，与图片来源无关 ——
  /// 所以这里零新代码，只要把相对路径还原成绝对路径即可。
  Future<void> _onLongPress() async {
    final file = await _fileFuture;
    if (file == null || !mounted) return;
    final name = file.path.split('/').last;
    await showImageActions(
      context,
      ChatAttachment(
        path: file.path,
        name: name,
        mimeType: ChatAttachment.mimeOf(name),
        size: 0,
        kind: AttachmentKind.image,
      ),
    );
  }

  /// 点开全屏大图：**把整组图一起传进去**，这样放大后能左右滑看其他张。
  ///
  /// 路径 → File 的换算只是拼字符串（`getImageFile` 不读盘），
  /// 所以在这里一次性解析整组不会有可感知的延迟。
  Future<void> _openViewer() async {
    final paths = widget.allPaths.isEmpty
        ? <String>[widget.relativePath]
        : widget.allPaths;
    final files = <File>[];
    final tags = <String?>[];
    for (final path in paths) {
      files.add(await ImageService.getImageFile(path));
      tags.add('cover_$path');
    }
    if (!mounted) return;
    await FullImageViewer.show(
      context,
      files,
      initialIndex: widget.index,
      heroTags: tags,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor =
        widget.isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final cardBg =
        widget.isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final isTemp = widget.temp != null;

    return GestureDetector(
      onTap: _openViewer,
      onLongPress: _onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: cardBg,
          boxShadow:
              widget.isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<File>(
                future: _fileFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 32,
                        color: accentColor.withValues(alpha: 0.3),
                      ),
                    );
                  }
                  return Hero(
                    tag: 'cover_${widget.relativePath}',
                    child: Image.file(
                      snapshot.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 32,
                          color: accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // ★ 临时图必须打角标。不打的话用户会以为它被存下来了，
              //   然后某次重开应用发现「图丢了」，却不知道是设计如此。
              if (isTemp)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'AI 生成 · 重启后消失',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // 不在真实图片上叠加文字：月份信息由下方日历头条承载，
              // 且图片内容不可预测（曾出现文字与图内文字混在一起读不出的情况）
            ],
          ),
        ),
      ),
    );
  }
}
