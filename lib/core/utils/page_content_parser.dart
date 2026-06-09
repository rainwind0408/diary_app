import '../../data/models/placed_image.dart';
import '../../data/models/placed_audio.dart';

class PageContent {
  String content;
  List<PlacedImage> placedImages;
  // 使用 nullable 类型 + getter/setter，防止热重载时旧实例字段为 null
  List<PlacedAudio>? _placedAudios;

  PageContent({
    this.content = '',
    List<PlacedImage>? placedImages,
    List<PlacedAudio>? placedAudios,
  })  : placedImages = placedImages ?? [],
        _placedAudios = placedAudios;

  List<PlacedAudio> get placedAudios => _placedAudios ??= [];
  set placedAudios(List<PlacedAudio> value) => _placedAudios = value;

  bool get isEmpty =>
      content.trim().isEmpty &&
      placedImages.isEmpty &&
      placedAudios.isEmpty;
  bool get isNotEmpty =>
      content.trim().isNotEmpty ||
      placedImages.isNotEmpty ||
      placedAudios.isNotEmpty;
}

class PageContentParser {
  PageContentParser._();

  static const String _separatorPattern = r'--- 第 \d+ 页 ---';

  static String mergePages(List<PageContent> pages) {
    if (pages.length == 1) return pages[0].content;
    final buffer = StringBuffer();
    for (int i = 0; i < pages.length; i++) {
      if (i > 0) buffer.writeln('\n--- 第 ${i + 1} 页 ---\n');
      buffer.write(pages[i].content);
    }
    return buffer.toString();
  }

  static List<PageContent> parsePages(String content) {
    if (content.trim().isEmpty) return [PageContent()];
    final parts = content.split(RegExp(_separatorPattern));
    final pages = parts.map((part) => PageContent(content: part.trim())).toList();
    if (pages.every((p) => p.isEmpty)) return [PageContent()];
    return pages;
  }
}
