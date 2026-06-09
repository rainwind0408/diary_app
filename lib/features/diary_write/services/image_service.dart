import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageService {
  ImageService._();

  static Future<String> get _imageDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/diary_images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  static Future<String> saveImage(File source) async {
    final dir = await _imageDir;
    final ext = p.extension(source.path);
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File('$dir/$name');
    await source.copy(dest.path);
    return 'diary_images/$name';
  }

  static Future<void> deleteImage(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$relativePath');
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<File> getImageFile(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/$relativePath');
  }
}
