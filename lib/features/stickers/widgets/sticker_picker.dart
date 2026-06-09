import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/sticker.dart';
import '../providers/sticker_provider.dart';

class StickerPicker extends StatefulWidget {
  final ValueChanged<Sticker> onStickerSelected;

  const StickerPicker({super.key, required this.onStickerSelected});

  static Future<void> show(BuildContext context, ValueChanged<Sticker> onSelected) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StickerPicker(onStickerSelected: onSelected),
    );
  }

  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    final provider = context.read<StickerProvider>();
    _categories = provider.categories;
    _tabController = TabController(length: _categories.length, vsync: this);
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
    final provider = context.watch<StickerProvider>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
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
          Text(
            '选择贴纸',
            style: AppTextStyles.heading.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: _categories.map((c) => Tab(text: c)).toList(),
            labelColor: goldColor,
            unselectedLabelColor:
                isDark ? AppColors.darkSubtleText : AppColors.subtleText,
            indicatorColor: goldColor,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle:
                AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppTextStyles.label,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) {
                final stickers = provider.getByCategory(category);
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: stickers.length,
                  itemBuilder: (ctx, i) {
                    return GestureDetector(
                      onTap: () {
                        widget.onStickerSelected(stickers[i]);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: goldColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            stickers[i].emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
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
}
