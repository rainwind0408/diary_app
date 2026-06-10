import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/template.dart';
import '../providers/template_provider.dart';
import 'template_card.dart';
import 'create_template_dialog.dart';

class TemplateSelector extends StatefulWidget {
  const TemplateSelector({super.key});

  static Future<DiaryTemplate?> show(BuildContext context) {
    return showModalBottomSheet<DiaryTemplate>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const TemplateSelector(),
    );
  }

  @override
  State<TemplateSelector> createState() => _TemplateSelectorState();
}

class _TemplateSelectorState extends State<TemplateSelector>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    Tab(text: '日常'),
    Tab(text: '特殊'),
    Tab(text: '节日'),
    Tab(text: '我的'),
  ];

  static const _categories = [
    TemplateCategory.daily,
    TemplateCategory.special,
    TemplateCategory.festival,
    TemplateCategory.custom,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final goldColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final provider = context.watch<TemplateProvider>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkSubtleText : AppColors.subtleText)
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            '选择模板',
            style: AppTextStyles.heading.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),

          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: _tabs,
            labelColor: goldColor,
            unselectedLabelColor:
                isDark ? AppColors.darkSubtleText : AppColors.subtleText,
            indicatorColor: goldColor,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTextStyles.label,
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) {
                final templates = category == TemplateCategory.custom
                    ? provider.customTemplates
                    : provider.getByCategory(category);

                if (templates.isEmpty) {
                  return GestureDetector(
                    onTap: category == TemplateCategory.custom
                        ? () => _createTemplate()
                        : null,
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category == TemplateCategory.custom
                                ? Icons.add_circle_outline
                                : Icons.note_outlined,
                            size: 48,
                            color: category == TemplateCategory.custom
                                ? goldColor
                                : (isDark
                                    ? AppColors.darkSubtleText
                                    : AppColors.subtleText),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            category == TemplateCategory.custom
                                ? '点击创建自定义模板'
                                : '暂无模板',
                            style: AppTextStyles.body.copyWith(
                              color: category == TemplateCategory.custom
                                  ? goldColor
                                  : (isDark
                                      ? AppColors.darkSubtleText
                                      : AppColors.subtleText),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final isCustom = category == TemplateCategory.custom;
                final gridCount = isCustom ? templates.length + 1 : templates.length;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: gridCount,
                  itemBuilder: (ctx, i) {
                    if (isCustom && i == 0) {
                      return GestureDetector(
                        onTap: () => _createTemplate(),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: goldColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: goldColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, size: 28, color: goldColor),
                              const SizedBox(height: 8),
                              Text(
                                '新建模板',
                                style: AppTextStyles.label.copyWith(
                                  color: goldColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final template = isCustom ? templates[i - 1] : templates[i];
                    return TemplateCard(
                      template: template,
                      onTap: () => Navigator.pop(context, template),
                      onLongPress: isCustom
                          ? () => _confirmDelete(template)
                          : null,
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTemplate() async {
    final template = await CreateTemplateDialog.show(context);
    if (template != null && mounted) {
      context.read<TemplateProvider>().addCustomTemplate(template);
    }
  }

  void _confirmDelete(DiaryTemplate template) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCardBackground : AppColors.cardBackground,
        title: Text(
          '删除模板',
          style: AppTextStyles.heading.copyWith(
            color: isDark ? AppColors.darkTitleText : AppColors.titleText,
          ),
        ),
        content: Text(
          '确定要删除「${template.name}」吗？',
          style: AppTextStyles.body.copyWith(
            color: isDark ? AppColors.darkBodyText : AppColors.bodyText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '取消',
              style: TextStyle(
                color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<TemplateProvider>().deleteCustomTemplate(template.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: AppColors.deleteRed)),
          ),
        ],
      ),
    );
  }
}
