import 'dart:io';
import 'zip_import_service.dart';
import 'json_import_service.dart';

class ImportHandler {
  ImportHandler._();

  /// 统一导入入口
  /// 根据文件扩展名自动选择 ZIP 或 JSON 导入
  static Future<ImportResult> importFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return ImportResult(0, 0, ['文件不存在：$filePath']);
    }

    final ext = filePath.toLowerCase().split('.').last;
    switch (ext) {
      case 'zip':
        return ZipImportService.importFromZip(filePath);
      case 'json':
        return JsonImportService.importFromJson(filePath);
      default:
        return ImportResult(0, 0, ['不支持的文件格式：.$ext']);
    }
  }
}
