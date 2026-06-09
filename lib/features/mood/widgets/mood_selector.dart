import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/mood_constants.dart';
import 'mood_intensity_bar.dart';

class MoodSelector extends StatelessWidget {
  final String selectedMood;
  final String selectedLabel;
  final int intensity;
  final String? note;
  final ValueChanged<String> onMoodSelected;
  final void Function(String emoji, String label, int intensity, String? note)?
      onMoodChanged;
  final bool compact;

  const MoodSelector({
    super.key,
    required this.selectedMood,
    this.selectedLabel = '',
    this.intensity = 3,
    this.note,
    required this.onMoodSelected,
    this.onMoodChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return GestureDetector(
      onTap: () => _showFullSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selectedMood.isNotEmpty
              ? goldColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selectedMood.isNotEmpty
                ? goldColor.withValues(alpha: 0.3)
                : subtleColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedMood.isNotEmpty) ...[
              Text(selectedMood, style: const TextStyle(fontSize: 16)),
              if (selectedLabel.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  selectedLabel,
                  style: TextStyle(fontSize: 11, color: goldColor),
                ),
              ],
            ] else ...[
              Icon(Icons.mood, size: 16, color: subtleColor),
              const SizedBox(width: 4),
              Text(
                '心情',
                style: TextStyle(fontSize: 11, color: subtleColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFullSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MoodSelectorSheet(
        selectedMood: selectedMood,
        selectedLabel: selectedLabel,
        intensity: intensity,
        note: note,
        isDark: isDark,
        onConfirm: (emoji, label, newIntensity, newNote) {
          onMoodSelected(emoji);
          onMoodChanged?.call(emoji, label, newIntensity, newNote);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    // Full inline version (not used in Phase 1, reserved for future)
    return _buildCompact(context);
  }
}

class _MoodSelectorSheet extends StatefulWidget {
  final String selectedMood;
  final String selectedLabel;
  final int intensity;
  final String? note;
  final bool isDark;
  final void Function(String emoji, String label, int intensity, String? note)
      onConfirm;

  const _MoodSelectorSheet({
    required this.selectedMood,
    required this.selectedLabel,
    required this.intensity,
    this.note,
    required this.isDark,
    required this.onConfirm,
  });

  @override
  State<_MoodSelectorSheet> createState() => _MoodSelectorSheetState();
}

class _MoodSelectorSheetState extends State<_MoodSelectorSheet> {
  late String _emoji;
  late String _label;
  late int _intensity;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _emoji = widget.selectedMood;
    _label = widget.selectedLabel;
    _intensity = widget.intensity;
    _noteController = TextEditingController(text: widget.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        widget.isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor =
        widget.isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor =
        widget.isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final goldColor =
        widget.isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: subtleColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  '今天心情如何？',
                  style: AppTextStyles.heading.copyWith(
                    color: textColor,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                if (_emoji.isNotEmpty)
                  Text(_emoji, style: const TextStyle(fontSize: 28)),
              ],
            ),
          ),
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategory('正面情绪', MoodConstants.positiveMoods,
                      goldColor, subtleColor),
                  const SizedBox(height: 12),
                  _buildCategory('中性情绪', MoodConstants.neutralMoods,
                      goldColor, subtleColor),
                  const SizedBox(height: 12),
                  _buildCategory('负面情绪', MoodConstants.negativeMoods,
                      goldColor, subtleColor),
                  const SizedBox(height: 12),
                  _buildCategory('特殊情绪', MoodConstants.specialMoods,
                      goldColor, subtleColor),
                  const SizedBox(height: 16),
                  // Intensity bar
                  Text(
                    '心情强度',
                    style: AppTextStyles.label.copyWith(color: subtleColor),
                  ),
                  const SizedBox(height: 8),
                  MoodIntensityBar(
                    intensity: _intensity,
                    onChanged: (v) => setState(() => _intensity = v),
                  ),
                  const SizedBox(height: 16),
                  // Note input
                  TextField(
                    controller: _noteController,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '简短描述此刻心情...',
                      hintStyle: TextStyle(
                        color: widget.isDark
                            ? AppColors.darkPlaceholderText
                            : AppColors.placeholderText,
                      ),
                      filled: true,
                      fillColor: (widget.isDark
                              ? AppColors.darkCardBackgroundAlt
                              : AppColors.cardBackgroundAlt)
                          .withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLength: 50,
                    buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            required maxLength}) =>
                        null,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Confirm button
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _emoji.isEmpty
                    ? null
                    : () => widget.onConfirm(
                          _emoji,
                          _label,
                          _intensity,
                          _noteController.text.isEmpty
                              ? null
                              : _noteController.text,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: goldColor.withValues(alpha: 0.3),
                ),
                child: const Text('确定', style: TextStyle(fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(
    String title,
    List<Map<String, String>> moods,
    Color goldColor,
    Color subtleColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '── $title ──',
          style: TextStyle(fontSize: 12, color: subtleColor),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: moods.map((mood) {
            final emoji = mood['emoji']!;
            final label = mood['label']!;
            final isSelected = _emoji == emoji;
            return GestureDetector(
              onTap: () => setState(() {
                _emoji = emoji;
                _label = label;
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? goldColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? goldColor
                        : (widget.isDark
                                ? AppColors.darkSubtleText
                                : AppColors.subtleText)
                            .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? goldColor
                            : (widget.isDark
                                ? AppColors.darkBodyText
                                : AppColors.bodyText),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
