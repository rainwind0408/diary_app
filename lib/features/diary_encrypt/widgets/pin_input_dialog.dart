import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class PinInputDialog extends StatefulWidget {
  final String title;
  final bool isSetting; // true = 设置新 PIN，false = 验证已有 PIN

  const PinInputDialog({
    super.key,
    this.title = '输入密码',
    this.isSetting = false,
  });

  static Future<String?> show(
    BuildContext context, {
    String title = '输入密码',
    bool isSetting = false,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PinInputDialog(title: title, isSetting: isSetting),
    );
  }

  @override
  State<PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<PinInputDialog>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _shake = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitTap(String digit) {
    if (_isConfirming) {
      if (_confirmPin.length < 4) {
        setState(() => _confirmPin += digit);
        if (_confirmPin.length == 4) {
          _verifyConfirm();
        }
      }
    } else {
      if (_pin.length < 4) {
        setState(() => _pin += digit);
        if (_pin.length == 4) {
          _onPinComplete();
        }
      }
    }
  }

  void _onDelete() {
    setState(() {
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  void _onPinComplete() {
    if (widget.isSetting) {
      setState(() => _isConfirming = true);
    } else {
      Navigator.of(context).pop(_pin);
    }
  }

  void _verifyConfirm() {
    if (_pin == _confirmPin) {
      Navigator.of(context).pop(_pin);
    } else {
      _triggerShake();
      setState(() {
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }

  void _triggerShake() {
    setState(() => _shake = true);
    _shakeController.forward(from: 0).then((_) {
      if (mounted) setState(() => _shake = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final currentPin = _isConfirming ? _confirmPin : _pin;
    final subtitle = _isConfirming ? '请再次输入密码' : '输入 4 位数字密码';

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            Icon(Icons.lock_outline, size: 40, color: goldColor),
            const SizedBox(height: 12),
            Text(widget.title, style: AppTextStyles.cardTitle.copyWith(color: textColor)),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTextStyles.label.copyWith(
              color: isDark ? AppColors.darkLabelText : AppColors.labelText,
            )),
            const SizedBox(height: 24),

            // PIN dots
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                final offset = _shake
                    ? Offset(_shakeAnimation.value * 10 * (1 - _shakeAnimation.value), 0)
                    : Offset.zero;
                return Transform.translate(offset: offset, child: child);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < currentPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? goldColor : Colors.transparent,
                      border: Border.all(
                        color: filled ? goldColor : (isDark ? AppColors.darkLabelText : AppColors.labelText),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 32),

            // Number pad
            _buildNumberPad(goldColor, textColor, isDark),

            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('取消', style: AppTextStyles.label.copyWith(
                color: isDark ? AppColors.darkLabelText : AppColors.labelText,
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad(Color goldColor, Color textColor, bool isDark) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 64, height: 48);
              if (key == '⌫') {
                return SizedBox(
                  width: 64,
                  height: 48,
                  child: IconButton(
                    onPressed: _onDelete,
                    icon: Icon(Icons.backspace_outlined, color: textColor),
                  ),
                );
              }
              return SizedBox(
                width: 64,
                height: 48,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _onDigitTap(key),
                    child: Center(
                      child: Text(
                        key,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
