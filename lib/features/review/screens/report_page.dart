import 'package:flutter/material.dart';
import '../../../core/constants/app_text_styles.dart';

/// 年报的一页
///
/// 每页只讲一件事：**一个大数字 + 一句人话 + 一个入场动效**。
/// 这是 Spotify Wrapped 那一类年度报告的基本单位 ——
/// 一页塞两个信息，读者的情绪就被打断了。
class ReportPage extends StatelessWidget {
  /// 顶部的小字标签（如「2026 · 你的这一年」）
  final String eyebrow;

  /// 页面主角：大数字 / 大字
  final String hero;

  /// 数字后面的单位或补充（如「篇日记」），显示在 hero 下方
  final String unit;

  /// 一句人话
  final String caption;

  /// 底部补充说明（可选）
  final String? footnote;

  /// 背景渐变的两个端点色
  final List<Color> gradient;

  /// 文字主色
  final Color foreground;

  /// 额外的装饰内容（如星座图、摘要卡片）
  final Widget? extra;

  /// 数字从 0 滚到目标值；传 null 则不做滚动（hero 不是纯数字时）
  final int? rollTo;

  const ReportPage({
    super.key,
    required this.eyebrow,
    required this.hero,
    this.unit = '',
    required this.caption,
    this.footnote,
    required this.gradient,
    required this.foreground,
    this.extra,
    this.rollTo,
  });

  /// hero 不是纯数字时的字号
  ///
  /// 数字（如 `6,234`）字宽窄，76 号刚好；但文案型 hero（如「晚上 20 点」）
  /// 有 7 个字符，76 号会宽到换行 —— 「晚上 20」/「点」这种断法很难看。
  /// 所以按字符数退让：**字符越多字号越小**，保证一行放得下。
  ///
  /// 用纯字符数而不是 `TextPainter` 量宽，是因为这里只需要「不会换行」，
  /// 不需要像素级贴合；换行与否由 `maxLines: 1` 兜底。
  static double _heroFontSize(String hero) {
    final n = hero.characters.length;
    if (n <= 4) return 76;
    if (n <= 5) return 64;
    if (n <= 6) return 54;
    if (n <= 8) return 44;
    return 36;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // 小字标签
              Text(
                eyebrow,
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(
                  color: foreground.withValues(alpha: 0.65),
                  fontSize: 13,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 28),

              // 主角数字
              if (rollTo != null)
                _RollingNumber(
                  target: rollTo!,
                  foreground: foreground,
                )
              else
                Text(
                  hero,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: _heroFontSize(hero),
                    height: 1.05,
                    fontFamily: 'MaShanZheng',
                    color: foreground,
                  ),
                ),

              if (unit.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 17,
                    color: foreground.withValues(alpha: 0.88),
                    letterSpacing: 1.0,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // 一句人话
              Text(
                caption,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.75,
                  color: foreground.withValues(alpha: 0.92),
                ),
              ),

              if (extra != null) ...[
                const SizedBox(height: 28),
                extra!,
              ],

              if (footnote != null) ...[
                const SizedBox(height: 22),
                Text(
                  footnote!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: foreground.withValues(alpha: 0.6),
                  ),
                ),
              ],

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 从 0 滚到目标值的数字
///
/// 用 [TweenAnimationBuilder] 而不是自己管 AnimationController ——
/// 年报是一次性的呈现，不需要暂停/重播控制，交给隐式动画最省事。
class _RollingNumber extends StatelessWidget {
  final int target;
  final Color foreground;

  const _RollingNumber({required this.target, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          _format(value.round()),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 76,
            height: 1.05,
            fontFamily: 'MaShanZheng',
            color: foreground,
          ),
        );
      },
    );
  }

  /// 千分位，让五位数不至于糊成一片
  static String _format(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
