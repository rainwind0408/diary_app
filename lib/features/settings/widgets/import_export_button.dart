import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
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

  Future<void> _export(String format) async {
    setState(() => _processing = true);
    try {
      String path;
      switch (format) {
        case 'markdown':
          path = await ExportService.exportToMarkdown();
          break;
        case 'txt':
          path = await ExportService.exportToTxt();
          break;
        case 'zip':
          await ZipExportService.exportAndShare();
          if (mounted) {
            Toast().show(context, 'ZIP 导出已启动', ToastType.success);
          }
          return;
        default:
          path = await ExportService.exportToJson();
      }
      if (mounted) {
        Toast().show(context, '导出成功：$path', ToastType.success);
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
