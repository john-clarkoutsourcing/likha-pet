import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Animated HP bar that smoothly transitions between values.
/// Color shifts green → yellow → red as HP drops.
class HpBar extends StatelessWidget {
  final int current;
  final int max;
  final double height;

  const HpBar({
    super.key,
    required this.current,
    required this.max,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final target = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (_, value, __) {
        final color = value > 0.5
            ? AppColors.hpGreen
            : value > 0.25
                ? AppColors.hpYellow
                : AppColors.hpRed;

        return ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: value,
            minHeight: height,
            backgroundColor: AppColors.surfaceLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
      },
    );
  }
}
