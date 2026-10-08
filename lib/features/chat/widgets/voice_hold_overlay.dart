import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/voice_hold_view.dart';

/// 长按说话时浮在输入框上方的提示层。
///
/// 只负责画 [VoiceHoldView]，不持有任何采集逻辑。
/// 整层用 [IgnorePointer] 包住 —— 它只是「看得见的反馈」，绝不能把
/// 输入框按钮上正在进行的那个长按手势抢走。
class VoiceHoldOverlay extends StatelessWidget {
  final VoiceHoldView view;

  const VoiceHoldOverlay({super.key, required this.view});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = view.canceling
        ? AppColors.deleteRed
        : (isDark ? AppColors.darkPink : AppColors.pinkDark);

    return IgnorePointer(
      child: Stack(
        children: [
          // 取消态压一层淡红，给「松手就没了」一个明确信号
          if (view.canceling)
            const Positioned.fill(child: ColoredBox(color: Color(0x22E05050))),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 132),
              child: _card(isDark, accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(bool isDark, Color accent) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        // 白色卡面 + 更实的投影：它飘在聊天画布上方，靠「浮起来」表达层级，
        // 不再用一圈主色描边（描边和「取消态」的红色语义容易打架）
        color: isDark ? AppColors.darkChatBubble : AppColors.chatBubble,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 32, child: Center(child: _glyph(accent))),
          const SizedBox(height: 8),
          Text(
            view.recognizing ? '识别中' : '${view.seconds}s',
            style: AppTextStyles.heading.copyWith(color: accent, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            view.hint,
            textAlign: TextAlign.center,
            style: AppTextStyles.label.copyWith(
              color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glyph(Color accent) {
    if (view.recognizing) {
      return SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
      );
    }
    if (view.canceling) {
      return Icon(Icons.delete_outline_rounded, color: accent, size: 28);
    }
    return _waveBars(accent);
  }

  /// 静态「声波」——不带动画也能一眼看出在收音，还省掉一个 Ticker。
  Widget _waveBars(Color accent) {
    const heights = <double>[12, 22, 30, 20, 14];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final h in heights)
          Container(
            width: 4,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}
