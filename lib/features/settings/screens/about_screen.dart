import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _readmeContent = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  String _cleanReadme(String raw) {
    // 移除 HTML 标签块（div, img, br 等）
    var cleaned = raw.replaceAll(RegExp(r'<[^>]*>'), '');
    // 移除徽章图片行 ![...](...)
    cleaned = cleaned.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');
    // 移除多余空行（连续3个以上换行合并为2个）
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      String readme = '';
      try {
        final raw = await rootBundle.loadString('assets/README.md');
        readme = _cleanReadme(raw);
      } catch (_) {
        readme = '# 手写日记\n\n无法加载 README.md 内容。';
      }
      if (!mounted) return;
      setState(() {
        _version = 'v${info.version}';
        _readmeContent = readme;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _version = '';
        _readmeContent = '# 手写日记\n\n加载失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkPageBackground : AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? AppColors.darkBodyText : AppColors.bodyText, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('关于', style: AppTextStyles.heading.copyWith(
          color: isDark ? AppColors.darkTitleText : AppColors.titleText,
        )),
        centerTitle: true,
      ),
      body: _readmeContent.isEmpty
          ? Center(child: CircularProgressIndicator(
              color: isDark ? AppColors.darkAccentPink : AppColors.accentPink,
            ))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/icon/app_icon_new.png',
                        width: 72,
                        height: 72,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '手写日记',
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 20,
                          color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _version,
                        style: AppTextStyles.label.copyWith(
                          color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: isDark ? AppColors.darkDividerLine : AppColors.dividerLine),
                Expanded(
                  child: Markdown(
                    data: _readmeContent,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    styleSheet: MarkdownStyleSheet(
                      h1: AppTextStyles.heading.copyWith(
                        fontSize: 22,
                        color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                      ),
                      h2: AppTextStyles.heading.copyWith(
                        fontSize: 18,
                        color: isDark ? AppColors.darkHeadingText : AppColors.headingText,
                      ),
                      h3: AppTextStyles.body.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkHeadingText : AppColors.headingText,
                      ),
                      p: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                        height: 1.6,
                      ),
                      listBullet: AppTextStyles.body.copyWith(
                        color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                      ),
                      code: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.cardBackgroundAlt,
                        color: isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardBackground : AppColors.cardBackgroundAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      blockquote: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: isDark ? AppColors.darkLabelText : AppColors.labelText,
                        fontStyle: FontStyle.italic,
                      ),
                      tableHead: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkHeadingText : AppColors.headingText,
                      ),
                      tableBody: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
                      ),
                      a: TextStyle(
                        color: isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
