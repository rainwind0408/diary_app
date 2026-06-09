import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_text_styles.dart';

enum ToastType { success, error, warning, info }

class Toast {
  static final Toast _instance = Toast._internal();
  factory Toast() => _instance;
  Toast._internal();

  OverlayEntry? _currentEntry;

  void show(BuildContext context, String message, ToastType type) {
    _currentEntry?.remove();
    _currentEntry = _createEntry(message, type);
    Overlay.of(context).insert(_currentEntry!);
    Future.delayed(const Duration(milliseconds: AppDimensions.toastDisplayDuration + AppDimensions.toastEnterDuration), () {
      _dismiss();
    });
  }

  void _dismiss() {
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
  }

  OverlayEntry _createEntry(String message, ToastType type) {
    return OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: _dismiss,
      ),
    );
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: AppDimensions.toastEnterDuration),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _bgColor() {
    switch (widget.type) {
      case ToastType.success:
        return AppColors.toastSuccessBg;
      case ToastType.error:
        return AppColors.toastErrorBg;
      case ToastType.warning:
        return AppColors.toastWarningBg;
      case ToastType.info:
        return AppColors.toastInfoBg;
    }
  }

  Color _textColor() {
    switch (widget.type) {
      case ToastType.success:
        return AppColors.toastSuccess;
      case ToastType.error:
        return AppColors.toastError;
      case ToastType.warning:
        return AppColors.toastWarning;
      case ToastType.info:
        return AppColors.toastInfo;
    }
  }

  Color _borderColor() {
    switch (widget.type) {
      case ToastType.success:
        return AppColors.toastSuccessBorder;
      case ToastType.error:
        return AppColors.toastErrorBorder;
      case ToastType.warning:
        return AppColors.toastWarningBorder;
      case ToastType.info:
        return AppColors.toastInfoBorder;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: AppDimensions.toastTopOffset + MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.toastPaddingH,
                  vertical: AppDimensions.toastPaddingV,
                ),
                decoration: BoxDecoration(
                  color: _bgColor(),
                  borderRadius: BorderRadius.circular(AppDimensions.toastRadius),
                  border: Border.all(color: _borderColor()),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.message,
                  style: AppTextStyles.toast.copyWith(color: _textColor()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
