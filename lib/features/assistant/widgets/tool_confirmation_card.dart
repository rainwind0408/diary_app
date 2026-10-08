import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../chat/models/tool_confirmation.dart';
import '../../chat/services/tool_confirmation_gate.dart';

/// AI 写操作的「人工确认」卡片。
///
/// 与 `FloatingAssistantOrb` **同层**挂在 `MaterialApp.builder` 的 Stack 里。
/// 不能挂进某个页面：AI 可以在任何地方调写工具（聊天页、日记列表页、
/// 悬浮球的语音直通），挂进页面就一定会漏掉一部分入口。
///
/// ## 两种确认方式（由 [ToolRisk] 决定）
///
/// | 风险 | 交互 |
/// |---|---|
/// | `write` | 点一下「确认」 |
/// | `destructive` | **按住不放 1 秒**（带进度环），中途松手即取消 |
///
/// 删除必须长按 —— 让「手滑」在物理上不可能造成不可逆的数据丢失。
/// 点卡片外的空白处一律视为取消（取消是安全方向，允许误触）。
class ToolConfirmationCard extends StatelessWidget {
  const ToolConfirmationCard({super.key});

  /// 删除类操作要按住多久才算数
  static const Duration holdDuration = Duration(seconds: 1);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ToolConfirmationRequest?>(
      valueListenable: ToolConfirmationGate.pending,
      builder: (context, request, _) {
        if (request == null) return const SizedBox.shrink();
        // 用 request 本身当 key：来了新请求就重建 State，
        // 入场动画重播、`_decided` 也会重置
        return _ConfirmationOverlay(key: ValueKey(request), request: request);
      },
    );
  }
}

class _ConfirmationOverlay extends StatefulWidget {
  final ToolConfirmationRequest request;

  const _ConfirmationOverlay({super.key, required this.request});

  @override
  State<_ConfirmationOverlay> createState() => _ConfirmationOverlayState();
}

class _ConfirmationOverlayState extends State<_ConfirmationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  /// 用户已经做出选择，正在等工具那边把活干完
  bool _decided = false;

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  void _decide(bool approved) {
    if (_decided) return;
    setState(() => _decided = true);
    // 只负责放行；真正的写操作在 DiaryMcpServer 那边继续
    ToolConfirmationGate.resolve(approved);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final req = widget.request;

    final cardBg =
        isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final titleColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final bodyColor = isDark ? AppColors.darkBodyText : AppColors.bodyText;
    final labelColor = isDark ? AppColors.darkLabelText : AppColors.labelText;
    final accent = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final danger = AppColors.deleteRed;

    return Positioned.fill(
      child: Material(
        // 卡片是浮在 Navigator 之上的，这里必须自带 Material，
        // 否则 Text 会掉进 WidgetsApp 的「报错文本样式」（黄底双下划线）
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // 遮罩：既挡住下面的页面（防误触），又是「点空白 = 取消」的落点
            FadeTransition(
              opacity: _enter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _decided ? null : () => _decide(false),
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _enter,
                  curve: Curves.easeOutCubic,
                )),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    14 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 22,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(req, titleColor, accent, danger),
                      const SizedBox(height: 4),
                      for (final line in req.lines)
                        _line(line, labelColor, bodyColor, titleColor),
                      if (req.warning != null) _warning(req.warning!, danger),
                      const SizedBox(height: 16),
                      _buttons(req, accent, titleColor, isDark),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(
    ToolConfirmationRequest req,
    Color titleColor,
    Color accent,
    Color danger,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            req.needsHold ? Icons.delete_outline : Icons.auto_fix_high,
            size: 20,
            color: req.needsHold ? danger : accent,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            req.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              height: 1.3,
              color: titleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          'AI 想改动你的日记',
          style: TextStyle(
            fontSize: 11,
            color: titleColor.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  Widget _line(
    ConfirmationLine line,
    Color labelColor,
    Color bodyColor,
    Color titleColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              line.label,
              style: TextStyle(fontSize: 13, color: labelColor, height: 1.45),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              line.value,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: line.emphasize ? titleColor : bodyColor,
                fontWeight:
                    line.emphasize ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warning(String text, Color danger) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.deleteRedLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded, size: 16, color: danger),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons(
    ToolConfirmationRequest req,
    Color accent,
    Color titleColor,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: _FlatButton(
            label: '取消',
            background: Colors.transparent,
            borderColor: titleColor.withValues(alpha: 0.18),
            textColor: titleColor.withValues(alpha: 0.7),
            onTap: _decided ? null : () => _decide(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: req.needsHold
              ? _HoldToConfirmButton(
                  enabled: !_decided,
                  onCompleted: () => _decide(true),
                )
              : _FlatButton(
                  label: req.confirmLabel,
                  background: accent,
                  textColor: isDark
                      ? AppColors.darkPageBackground
                      : AppColors.titleText,
                  onTap: _decided ? null : () => _decide(true),
                ),
        ),
      ],
    );
  }
}

/// 普通按钮。点一下触发。
class _FlatButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const _FlatButton({
    required this.label,
    required this.background,
    required this.textColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(23),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// 删除专用：**按住不放 1 秒**才确认，中途松手即取消。
///
/// 用 [Listener] 而不是 `GestureDetector` 的长按回调 —— 长按回调只在
/// 500ms 阈值处触发一次，没法给出「按了多久」的连续进度。
/// 这里需要的是「按下的每一帧都在推进」，松手立刻回退。
class _HoldToConfirmButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onCompleted;

  const _HoldToConfirmButton({
    required this.enabled,
    required this.onCompleted,
  });

  @override
  State<_HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<_HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: ToolConfirmationCard.holdDuration,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        widget.onCompleted();
      }
    });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _press() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    _hold.forward();
  }

  /// 松手 / 手势被打断 —— 进度条退回，不确认
  void _release() {
    if (_hold.status == AnimationStatus.forward) _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;

    return Listener(
      onPointerDown: enabled ? (_) => _press() : null,
      onPointerUp: enabled ? (_) => _release() : null,
      onPointerCancel: enabled ? (_) => _release() : null,
      child: AnimatedBuilder(
        animation: _hold,
        builder: (context, _) {
          final progress = _hold.value;
          final holding = progress > 0.01;

          return Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // 底色随进度加深：不用看环也知道「按到哪儿了」
                color: Color.lerp(
                  AppColors.deleteRedLight,
                  AppColors.deleteRed,
                  progress,
                ),
                borderRadius: BorderRadius.circular(23),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: holding
                        ? CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.2,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.35),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          )
                        : const Icon(
                            Icons.touch_app_outlined,
                            size: 17,
                            color: AppColors.deleteRed,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    holding ? '按住不放…' : '长按删除',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: holding ? Colors.white : AppColors.deleteRed,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
