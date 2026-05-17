import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Toast widget showing validation progress
class ValidationToast extends StatelessWidget {
  final bool isVisible;
  final String message;
  final ValidationToastType type;
  final Duration duration;

  const ValidationToast({
    super.key,
    required this.isVisible,
    required this.message,
    this.type = ValidationToastType.validating,
    this.duration = const Duration(seconds: 3),
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              _buildIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (type) {
      case ValidationToastType.validating:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withOpacity(0.8),
            ),
          ),
        );
      case ValidationToastType.success:
        return Icon(
          Icons.check_circle,
          color: Colors.white,
          size: 20,
        );
      case ValidationToastType.error:
        return Icon(
          Icons.error,
          color: Colors.white,
          size: 20,
        );
      case ValidationToastType.warning:
        return Icon(
          Icons.warning,
          color: Colors.white,
          size: 20,
        );
    }
  }

  Color get _backgroundColor {
    switch (type) {
      case ValidationToastType.validating:
        return Colors.blue.shade600;
      case ValidationToastType.success:
        return const Color(0xFF4CAF50);
      case ValidationToastType.error:
        return Colors.redAccent;
      case ValidationToastType.warning:
        return Colors.orange.shade600;
    }
  }
}

enum ValidationToastType {
  validating,
  success,
  error,
  warning,
}

/// Helper to show validation toast
class ValidationToastManager {
  static OverlayEntry? _overlayEntry;

  static void show(
    BuildContext context, {
    required String message,
    ValidationToastType type = ValidationToastType.validating,
    Duration duration = const Duration(seconds: 3),
  }) {
    _overlayEntry?.remove();

    _overlayEntry = OverlayEntry(
      builder: (context) => ValidationToast(
        isVisible: true,
        message: message,
        type: type,
        duration: duration,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    if (type != ValidationToastType.validating) {
      Future.delayed(duration, () {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
    }
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
