import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/widgets/full_image_viewer.dart';
import '../../../diary_write/services/image_service.dart';

/// 首页顶部封面图卡片
///
/// 展示当前选中月份日记里的图片，横向轮播；默认第一张为「当前日期」的图片。
/// 高度约占屏幕的四分之一，并做上下限约束，避免小屏 / 横屏被压塌。
///
/// 预留 AI 生成图接口：传入 [generatedImagePaths]（key 为原始图片相对路径，
/// value 为生成图的相对路径）时优先展示生成图；未传入或未命中则展示原图。
class CoverPhotoBanner extends StatefulWidget {
  /// 待展示的图片相对路径（由 DiaryRepository.getMonthImagePaths 提供）
  final List<String> imagePaths;

  /// AI 生成图映射：原图相对路径 → 生成图相对路径。为空表示未接入 AI。
  final Map<String, String>? generatedImagePaths;

  /// 供无障碍与角标显示使用的月份标题，如「2026年9月」
  final String monthLabel;

  const CoverPhotoBanner({
    super.key,
    required this.imagePaths,
    this.generatedImagePaths,
    required this.monthLabel,
  });

  @override
  State<CoverPhotoBanner> createState() => _CoverPhotoBannerState();
}

class _CoverPhotoBannerState extends State<CoverPhotoBanner> {
  late PageController _pageController;
  int _currentPage = 0;
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    _lastLength = widget.imagePaths.length;
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void didUpdateWidget(CoverPhotoBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 月份切换后图片数量变化，若当前页越界则回到首张
    if (widget.imagePaths.length != _lastLength) {
      _lastLength = widget.imagePaths.length;
      if (_currentPage > 0 && _currentPage >= widget.imagePaths.length) {
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

    if (widget.imagePaths.isEmpty) {
      return _buildEmptyState(isDark, bannerHeight);
    }

    final paths = widget.imagePaths;
    final showIndicator = paths.length > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: SizedBox(
        height: bannerHeight,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: paths.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _CoverTile(
                    relativePath: _resolvePath(paths[index]),
                    isDark: isDark,
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
                    '${_currentPage + 1}/${paths.length}',
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

  const _CoverTile({
    required this.relativePath,
    required this.isDark,
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

  @override
  Widget build(BuildContext context) {
    final accentColor =
        widget.isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final cardBg =
        widget.isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    return GestureDetector(
      onTap: () async {
        final file = await _fileFuture;
        // build 参数遮蔽了 State.context，必须用 context.mounted 才能被识别为有效守卫
        if (file == null || !context.mounted) return;
        await FullImageViewer.show(
          context,
          file,
          heroTag: 'cover_${widget.relativePath}',
        );
      },
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
              // 不在图片上叠加文字：月份信息由下方日历头条承载，
              // 且图片内容不可预测（曾出现文字与图内文字混在一起读不出的情况）
            ],
          ),
        ),
      ),
    );
  }
}
