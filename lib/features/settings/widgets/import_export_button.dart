import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/toast.dart';
import '../../../shared/services/export_service.dart';
import '../../../shared/services/zip_export_service.dart';
import '../../../shared/services/import_handler.dart';
import '../../../shared/services/sharing_intent_service.dart';

class ImportExportButton extends StatefulWidget {
  const ImportExportButton({super.key});

  @override
  State<ImportExportButton> createState() => _ImportExportButtonState();
}

class _ImportExportButtonState extends State<ImportExportButton> {
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SharingIntentService.setContext(context);
      SharingIntentService.handleInitialShare();
    });
  }

  /// 四种格式全部走「导出 → 唤起系统分享面板」。
  ///
  /// ⚠️ 不要再退回「只写文件 + Toast 一个路径」的写法：导出目录在应用私有 /
  /// 缓存目录里，用户根本访问不到，那种实现等于没导出。
  Future<void> _export(String format) async {
    setState(() => _processing = true);
    try {
      final ShareResult result;
      final String label;
      switch (format) {
        case 'zip':
          label = '完整备份';
          result = await ZipExportService.exportAndShare();
        case 'markdown':
          label = 'Markdown';
          result = await ExportService.exportAndShare(DiaryExportFormat.markdown);
        case 'txt':
          label = 'TXT';
          result = await ExportService.exportAndShare(DiaryExportFormat.txt);
        default:
          label = 'JSON';
          result = await ExportService.exportAndShare(DiaryExportFormat.json);
      }
      if (!mounted) return;
      // 用户关掉分享面板没选任何目标时，文件其实没落到用户手里，别报「成功」。
      if (result.status == ShareResultStatus.dismissed) {
        Toast().show(context, '已取消分享，$label 未保存', ToastType.warning);
      } else {
        Toast().show(context, '$label 导出完成', ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        Toast().show(context, '导出失败：$e', ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _import(String format) async {
    setState(() => _processing = true);
    try {
      final typeGroup = XTypeGroup(
        label: format == 'zip' ? 'ZIP 文件' : 'JSON 文件',
        extensions: [format],
      );

      final file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) {
        if (mounted) setState(() => _processing = false);
        return;
      }

      final result = await ImportHandler.importFile(file.path);

      if (mounted) {
        if (result.success) {
          Toast().show(
            context,
            '成功导入 ${result.importedCount} 条日记',
            ToastType.success,
          );
        } else {
          Toast().show(
            context,
            '导入完成：${result.importedCount} 条成功，${result.skippedCount} 条失败',
            ToastType.warning,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Toast().show(context, '导入失败：$e', ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showMainMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('导入与导出', style: AppTextStyles.cardTitle.copyWith(color: textColor)),
              const SizedBox(height: 16),
              _MenuOption(
                icon: Icons.upload_file,
                label: '导出日记',
                description: '将日记导出为文件',
                color: goldColor,
                textColor: textColor,
                onTap: () {
                  Navigator.pop(context);
                  _showExportMenu();
                },
              ),
              _MenuOption(
                icon: Icons.download,
                label: '导入日记',
                description: '从文件恢复日记',
                color: Colors.blue,
                textColor: textColor,
                onTap: () {
                  Navigator.pop(context);
                  _showImportMenu();
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('取消', style: AppTextStyles.label.copyWith(
                  color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExportMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('选择导出格式', style: AppTextStyles.cardTitle.copyWith(color: textColor)),
              const SizedBox(height: 6),
              Text(
                '导出后会弹出系统分享面板，可保存到文件或发送给其他应用',
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(
                  color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                ),
              ),
              const SizedBox(height: 16),
              _MenuOption(
                icon: Icons.code,
                label: 'JSON 文件',
                description: '结构化数据，适合备份恢复',
                color: goldColor,
                textColor: textColor,
                onTap: () {
                  Navigator.pop(context);
                  _export('json');
                },
              ),
              _MenuOption(
                icon: Icons.description,
                label: 'Markdown 文件',
                description: '可读性强，适合笔记软件导入',
                color: goldColor,
                textColor: textColor,
                onTap: () {
                  Navigator.pop(context);
                  _export('markdown');
                },
              ),
              _MenuOption(
                icon: Icons.text_snippet,
                label: 'TXT 文件',
                description: '纯文本，通用格式',
                color: goldColor,
                textColor: textColor,
                onTap: () {
                  Navigator.pop(context);
                  _export('txt');
                },
              ),
              const Divider(),
              _MenuOption(
                icon: Icons.archive,
                label: '完整备份 (ZIP)',
                description: '包含图片和录音，数据完整',
                color: Colors.blue,
                textColor: textColor,
                onTap: () {
                  Navigator.pop(context);
                  _export('zip');
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('取消', style: AppTextStyles.label.copyWith(
                  color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImportMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('选择导入格式', style: AppTextStyles.cardTitle.copyWith(color: textColor)),
              const SizedBox(height: 16),
              _MenuOption(
                icon: Icons.archive,
                label: '从 ZIP 导入',
                description: '完整恢复（含图片和录音）',
                color: Colors.blue,
                textColor: textColor,
                onTap: () {
                  Navigator.pop(context);
                  _import('zip');
                },
              ),
              _MenuOption(
                icon: Icons.code,
                label: '从 JSON 导入',
                description: '恢复文本内容',
                color: goldColor,
                textColor: textColor,
                onTap: () {
                  Navigator.pop(context);
                  _import('json');
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('取消', style: AppTextStyles.label.copyWith(
                  color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    return ListTile(
      leading: Icon(Icons.swap_vert, color: goldColor),
      title: Text('导入与导出', style: AppTextStyles.body.copyWith(
        color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
      )),
      subtitle: Text('备份与恢复日记数据', style: AppTextStyles.label.copyWith(
        color: isDark ? AppColors.darkLabelText : AppColors.labelText,
      )),
      trailing: _processing
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: goldColor),
            )
          : Icon(Icons.chevron_right,
              color: isDark ? AppColors.darkLabelText : AppColors.labelText),
      onTap: _processing ? null : _showMainMenu,
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: AppTextStyles.body.copyWith(color: textColor)),
      subtitle: Text(description, style: AppTextStyles.cardDate),
      onTap: onTap,
    );
  }
}
