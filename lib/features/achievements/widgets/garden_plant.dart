import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/achievement.dart';

/// 花园里的一株植物
///
/// 对应一个成就。已解锁时显示彩色 emoji 并有轻微摇摆动画，
/// 未解锁时显示去色剪影 + 「?」。
///
/// [growth] 为 0.0~1.0 的生长进度，用于给同一行里的植物做大小梯度，
/// 让「越早解锁的越矮、越晚解锁的越高」这件事在视觉上成立。
class GardenPlant extends StatefulWidget {
  final Achievement achievement;

  /// 点击回调（用于弹出成就详情）
  final VoidCallback? onTap;

  /// 生长进度：0.0（刚解锁）→ 1.0（最早解锁，最成熟）
  final double growth;

  /// 摇摆动画的相位偏移（0.0~1.0），避免所有植物同步摇摆
  final double phaseOffset;

  const GardenPlant({
    super.key,
    required this.achievement,
    this.onTap,
    this.growth = 1.0,
    this.phaseOffset = 0.0,
  });

  @override
  State<GardenPlant> createState() => _GardenPlantState();
}

class _GardenPlantState extends State<GardenPlant>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 只给已解锁的植物开动画，未解锁的静止（省性能也更符合语义）
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    );
    if (widget.achievement.isUnlocked) {
      // 错峰启动：让每株植物从周期中的不同位置开始摇摆
      _controller.value = widget.phaseOffset;
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(GardenPlant oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = oldWidget.achievement.isUnlocked;
    final now = widget.achievement.isUnlocked;
    if (!was && now) {
      _controller.value = widget.phaseOffset;
      _controller.repeat();
    } else if (was && !now) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unlocked = widget.achievement.isUnlocked;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;

    // 生长梯度：0.85 ~ 1.0 的缩放，避免差距过大显得杂乱
    final scale = 0.85 + 0.15 * widget.growth;
    final emojiSize = 26.0 * scale;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            width: 34,
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  if (!unlocked || child == null) return child ?? const SizedBox.shrink();
                  // -1.4° ~ +1.4° 的轻微摇摆，像被风吹动
                  final angle =
                      math.sin(_controller.value * 2 * math.pi) * 0.024;
                  return Transform.rotate(angle: angle, child: child);
                },
                child: unlocked
                    ? Text(
                        widget.achievement.icon,
                        style: TextStyle(fontSize: emojiSize),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          // 未解锁：去色剪影，而不是换成灰 emoji
                          // （保留图标轮廓，让用户能猜，但不给答案）
                          ColorFiltered(
                            colorFilter: const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 0.28, 0,
                            ]),
                            child: Text(
                              widget.achievement.icon,
                              style: TextStyle(fontSize: emojiSize),
                            ),
                          ),
                          Text(
                            '?',
                            style: TextStyle(
                              fontSize: emojiSize * 0.62,
                              fontWeight: FontWeight.bold,
                              color: subtleColor.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          // 已解锁才显示名字；未解锁只留一个点，避免泄露条件
          // 名字可能较长（「长篇作家」4 字），用 maxLines+ellipsis 兜底，绝不溢出
          SizedBox(
            height: 12,
            child: unlocked
                ? Text(
                    widget.achievement.name,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark
                          ? AppColors.darkLabelText
                          : AppColors.labelText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  )
                : Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: goldColor.withValues(alpha: 0.25),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
