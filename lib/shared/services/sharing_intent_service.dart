import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'import_handler.dart';
import '../../core/widgets/toast.dart';

class SharingIntentService {
  SharingIntentService._();

  static const _channel = MethodChannel('com.example.diary_app/sharing');
  static bool _initialized = false;
  static String? _pendingPath;
  static BuildContext? _context;

  /// 初始化分享监听
  static void init() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFile') {
        final path = call.arguments as String;
        _pendingPath = path;
        _tryHandle();
      }
    });
  }

  /// 设置上下文（页面就绪后调用）
  static void setContext(BuildContext context) {
    _context = context;
    _tryHandle();
  }

  /// 处理冷启动时的分享（应用通过分享启动）
  static Future<void> handleInitialShare() async {
    try {
      final path = await _channel.invokeMethod<String>('getSharedFile');
      if (path != null) {
        _pendingPath = path;
        _channel.invokeMethod('clearSharedFile');
        _tryHandle();
      }
    } catch (_) {}
  }

  static void _tryHandle() {
    if (_pendingPath == null || _context == null) return;
    final path = _pendingPath!;
    _pendingPath = null;

    final ext = path.toLowerCase().split('.').last;
    if (ext != 'zip' && ext != 'json') {
      if (_context!.mounted) {
        Toast().show(_context!, '不支持的文件格式：.$ext', ToastType.warning);
      }
      return;
    }

    _showImportConfirm(_context!, path, ext);
  }

  static void _showImportConfirm(BuildContext context, String path, String format) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgColor,
        title: Text('导入日记', style: TextStyle(color: textColor)),
        content: Text(
          '检测到备份文件，是否导入？\n格式：${format.toUpperCase()}',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _doImport(context, path);
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  static Future<void> _doImport(BuildContext context, String path) async {
    try {
      final result = await ImportHandler.importFile(path);
      if (context.mounted) {
        if (result.success) {
          Toast().show(context, '成功导入 ${result.importedCount} 条日记', ToastType.success);
        } else {
          Toast().show(
            context,
            '导入完成：${result.importedCount} 条成功，${result.skippedCount} 条失败',
            ToastType.warning,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Toast().show(context, '导入失败：$e', ToastType.error);
      }
    }
  }
}
