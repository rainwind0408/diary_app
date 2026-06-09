import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/toast.dart';
import '../../../shared/services/export_service.dart';
import '../../../shared/services/zip_export_service.dart';

class ExportButton extends StatefulWidget {
  const ExportButton({super.key});

  @override
  State<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<ExportButton> {
  bool _exporting = false;

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
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
      if (mounted) setState(() => _exporting = false);
    }
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
              _ExportOption(
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
              _ExportOption(
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
              _ExportOption(
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
              _ExportOption(
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    return ListTile(
      leading: Icon(Icons.upload_file, color: goldColor),
      title: Text('导出日记', style: AppTextStyles.body.copyWith(
        color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
      )),
      subtitle: Text('导出为 JSON / Markdown / TXT / ZIP', style: AppTextStyles.label.copyWith(
        color: isDark ? AppColors.darkLabelText : AppColors.labelText,
      )),
      trailing: _exporting
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: goldColor),
            )
          : Icon(Icons.chevron_right,
              color: isDark ? AppColors.darkLabelText : AppColors.labelText),
      onTap: _exporting ? null : _showExportMenu,
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ExportOption({
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
