import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// 段式选择器（Segmented Button）。
///
/// 全项目原有两套私有实现（`review_screen.dart` 的 `_SegmentedToggle` 与
/// `_TrendDaysSelector`），强调色互不一致（goldAccent vs accentPink）。
/// 本组件是它们的合并替代：一套实现、一种强调色（默认金色系，
/// 可通过 [activeColor] 覆盖）。
///
/// 用法：
/// ```dart
/// SegmentedToggle(
///   labels: const ['年盘', '月历'],
///   index: _showConstellation ? 0 : 1,
///   onChanged: (i) => setState(() => _showConstellation = i == 0),
/// )
/// ```
class SegmentedToggle extends StatelessWidget {
  /// 选项文案，至少 2 项。
  final List<String> labels;

  /// 当前选中下标。
  final int index;

  /// 选中项变化回调（传入下标）。
  final ValueChanged<int> onChanged;

  /// 选中态填充色；缺省按亮暗模式取 goldAccent / darkGoldAccent。
  final Color? activeColor;

  const SegmentedToggle({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = activeColor ??
        (isDark ? AppColors.darkGoldAccent : AppColors.goldAccent);
    final subtle = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (i != index) onChanged(i);
                // 触感反馈：选中态切换的轻触感。
                HapticFeedback.selectionClick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                // 命中区下限：比旧实现（padding v4、fontSize 11）更易点准。
                constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
                decoration: BoxDecoration(
                  color: i == index ? gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: i == index ? Colors.white : subtle,
                    fontWeight: i == index ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
