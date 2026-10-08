import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../chat/widgets/thinking_dots.dart';
import '../services/orb_reply.dart';

/// 悬浮球旁边那枚「AI 回复」气泡框。
///
/// 它**不是**聊天页的消息气泡（那个在 `features/chat/widgets/chat_bubble.dart`，
/// 是「去尾巴的 QQ 风圆角矩形」）。这枚是**锚定在悬浮球上的 callout**，
/// 所以刻意保留了尾巴 —— 没有尾巴就看不出「这句话是从这个球出来的」。
///
/// ## 三条硬约束
/// 1. **整枚套 `IgnorePointer`**：它飘在球旁边，绝不能抢走球上的拖动 / 长按手势；
/// 2. **不读 `reasoning`**：只渲染 [OrbReply.text]，所以天然「不显示思考」；
/// 3. **只做淡入、不做缩放**：「点气泡外关闭」要靠这枚气泡的矩形来排除自身，
///    缩放会改 RenderBox 尺寸，导致排除区在动画期间是错的。
class OrbReplyBubble extends StatelessWidget {
  final OrbReply reply;

  /// 尾巴是否在气泡的**左**侧（球吸在左半屏时为 true）
  final bool tailOnLeft;

  final double maxWidth;
  final double maxHeight;

  const OrbReplyBubble({
    super.key,
    required this.reply,
    required this.tailOnLeft,
    required this.maxWidth,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkChatBubble : AppColors.chatBubble;
    final body = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final subtle = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final failed = reply.phase == OrbReplyPhase.failed;

    final padLeft = (tailOnLeft ? OrbReplyPolicy.tailLength : 0) +
        OrbReplyPolicy.contentPadding;
    final padRight = (tailOnLeft ? 0 : OrbReplyPolicy.tailLength) +
        OrbReplyPolicy.contentPadding;

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            minHeight: OrbReplyPolicy.minHeight,
          ),
          child: PhysicalShape(
            clipper: SpeechBubbleClipper(
              tailOnLeft: tailOnLeft,
              radius: OrbReplyPolicy.radius,
              tailLength: OrbReplyPolicy.tailLength,
              tailY: OrbReplyPolicy.tailY,
              tailHalfHeight: OrbReplyPolicy.tailHalfHeight,
            ),
            color: bg,
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.22),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.only(
                left: padLeft,
                right: padRight,
                top: OrbReplyPolicy.verticalPadding,
                bottom: OrbReplyPolicy.verticalPadding,
              ),
              child: _content(subtle, body, failed),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(Color subtle, Color body, bool failed) {
    switch (reply.phase) {
      case OrbReplyPhase.hidden:
        return const SizedBox.shrink();

      case OrbReplyPhase.waiting:
        // 复用聊天页的三点指示器，两处观感一致
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: ThinkingDots(color: subtle, dotSize: 6),
        );

      case OrbReplyPhase.streaming:
      case OrbReplyPhase.done:
        return Text(
          reply.display,
          style: AppTextStyles.body.copyWith(
            color: body,
            fontSize: 14,
            height: 1.5,
          ),
        );

      case OrbReplyPhase.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1.5),
              child: Icon(
                Icons.error_outline_rounded,
                size: 15,
                color: AppColors.deleteRed,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                reply.display,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.deleteRed,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        );
    }
  }
}

/// 圆角矩形 + **圆弧小尾巴**的轮廓。
///
/// 用一条合并后的 [Path] 而不是「圆角 Container + 一个旋转方块」拼：
/// 后者在带投影时，接缝处会露出一道阴影线。
class SpeechBubbleClipper extends CustomClipper<Path> {
  final bool tailOnLeft;
  final double radius;
  final double tailLength;

  /// 尾巴中心线在气泡内的高度（相对气泡顶部）
  final double tailY;
  final double tailHalfHeight;

  const SpeechBubbleClipper({
    required this.tailOnLeft,
    required this.radius,
    required this.tailLength,
    required this.tailY,
    required this.tailHalfHeight,
  });

  @override
  Path getClip(Size size) {
    // 主体让出尾巴那一段宽度
    final bodyLeft = tailOnLeft ? tailLength : 0.0;
    final bodyRight = size.width - (tailOnLeft ? 0.0 : tailLength);

    final body = Path()
      ..addRRect(
        RRect.fromLTRBR(
          bodyLeft,
          0,
          bodyRight,
          size.height,
          Radius.circular(radius),
        ),
      );

    // 尾巴：从主体侧边探出去，用两段三次贝塞尔做出**弧形**轮廓
    // （而不是一条直线切出来的尖三角）
    final baseX = tailOnLeft ? bodyLeft : bodyRight;
    final dir = tailOnLeft ? -1.0 : 1.0; // 探出方向
    final tipX = baseX + dir * tailLength;

    final top = tailY - tailHalfHeight;
    final bottom = tailY + tailHalfHeight;
    // 控制点向尖端收拢，形成「外侧鼓、尖端圆」的弧
    final ctrl = baseX + dir * tailLength * 0.30;

    final tail = Path()
      ..moveTo(baseX, top)
      ..cubicTo(
        ctrl, top,
        tipX, tailY - tailHalfHeight * 0.45,
        tipX, tailY,
      )
      ..cubicTo(
        tipX, tailY + tailHalfHeight * 0.45,
        ctrl, bottom,
        baseX, bottom,
      )
      ..close();

    // 合并成一个轮廓，投影与裁剪才会把尾巴算进去
    return Path.combine(PathOperation.union, body, tail);
  }

  @override
  bool shouldReclip(SpeechBubbleClipper old) =>
      old.tailOnLeft != tailOnLeft ||
      old.radius != radius ||
      old.tailLength != tailLength ||
      old.tailY != tailY ||
      old.tailHalfHeight != tailHalfHeight;
}
