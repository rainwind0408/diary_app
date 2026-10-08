import 'package:flutter/services.dart';

/// 把图片写进系统相册。
///
/// 没有引第三方插件 —— Android 10+ 的分区存储下写相册必须走 MediaStore，
/// 而 MediaStore 插入「应用自己创建的媒体」自带权限豁免。原生实现见
/// `android/app/src/main/kotlin/com/example/diary_app/MediaStorePlugin.kt`。
class GallerySaver {
  GallerySaver._();

  static const MethodChannel _channel =
      MethodChannel('com.example.diary_app/media_store');

  /// 保存成功返回相册里的 uri（`content://…`）；失败抛异常。
  ///
  /// 图片会落在「相册 → Pictures/折花日记」下。
  static Future<String> saveImage(
    String path, {
    required String name,
    String mimeType = 'image/png',
  }) async {
    final uri = await _channel.invokeMethod<String>('saveImage', {
      'path': path,
      'name': name,
      'mimeType': mimeType,
    });
    if (uri == null || uri.isEmpty) {
      throw Exception('保存失败：相册没有返回地址');
    }
    return uri;
  }

  /// 给保存的图片起个像样的名字。
  ///
  /// 私有目录里的文件名是一串随机戳（`1759…ab.png`），存进相册后用户根本认不出，
  /// 所以统一改成「折花日记_20261004_014251.png」这种。
  static String suggestedName({String extension = '.png', DateTime? now}) {
    final t = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}'
        '_${two(t.hour)}${two(t.minute)}${two(t.second)}';
    return '折花日记_$stamp$extension';
  }

  /// 从路径里取扩展名，取不到按 .png
  static String extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.png';
    final ext = path.substring(dot);
    // 路径里可能带 query（生图厂商返回的 url 不会走到这里，但保险起见）
    return ext.contains('/') ? '.png' : ext;
  }
}
