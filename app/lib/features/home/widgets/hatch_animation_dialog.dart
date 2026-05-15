import 'package:flutter/material.dart';
import '../models/pet_model.dart';
import '../../../core/theme/app_colors.dart';

/// Hatch Animation Dialog - displays hatching animation with countdown
class HatchAnimationDialog extends StatefulWidget {
  final PetModel egg;
  final VoidCallback onHatchComplete;

  const HatchAnimationDialog({
    super.key,
    required this.egg,
    required this.onHatchComplete,
  });

  @override
  State<HatchAnimationDialog> createState() => _HatchAnimationDialogState();
}

class _HatchAnimationDialogState extends State<HatchAnimationDialog>
    with TickerProviderStateMixin {
  late AnimationController _crackController;
  late AnimationController _hatchController;
  late AnimationController _eggShakeController;
  late Animation<double> _crackAnimation;
  late Animation<double> _hatchAnimation;
  late Animation<double> _shakeAnimation;

  int _countdown = 3;
  bool _isHatching = false;

  @override
  void initState() {
    super.initState();

    // Crack animation - egg shakes and cracks appear
    _crackController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _crackAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _crackController, curve: Curves.easeInOut),
    );

    // Egg shake animation - repetitive shake effect
    _eggShakeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _eggShakeController, curve: Curves.easeInOut),
    );

    // Hatch animation - egg breaks and pet appears
    _hatchController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _hatchAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _hatchController, curve: Curves.easeOut),
    );

    // Start shaking immediately
    _startShaking();
  }

  void _startShaking() {
    _eggShakeController.repeat(reverse: true);
    
    // Start crack animation after 500ms
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isHatching) {
        _crackController.forward();
      }
    });

    // Start hatching after 1.5 seconds total
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && !_isHatching) {
        _startHatching();
      }
    });
  }

  void _startHatching() {
    setState(() => _isHatching = true);
    _eggShakeController.stop();
    _hatchController.forward().then((_) {
      if (mounted) {
        // Show countdown before closing
        _showCountdown();
      }
    });
  }

  void _showCountdown() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _countdown > 0) {
        setState(() => _countdown--);
        _showCountdown();
      } else if (mounted && _countdown == 0) {
        widget.onHatchComplete();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _crackController.dispose();
    _hatchController.dispose();
    _eggShakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bg.withValues(alpha: 0.95),
              AppColors.bg,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.divider,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 40),

            // ── Title ──────────────────────────────────────────────────
            const Text(
              'Hatching...',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              widget.egg.name,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 40),

            // ── Egg Animation ──────────────────────────────────────────
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow effect
                  AnimatedBuilder(
                    animation: _hatchAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 150 + (_hatchAnimation.value * 50),
                        height: 150 + (_hatchAnimation.value * 50),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber.withValues(
                            alpha: 0.3 * (1 - _hatchAnimation.value),
                          ),
                        ),
                      );
                    },
                  ),

                  // Egg with shake and cracks
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _shakeAnimation,
                      _crackAnimation,
                      _hatchAnimation,
                    ]),
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: Opacity(
                          opacity: 1 - (_hatchAnimation.value * 0.3),
                          child: Transform.scale(
                            scale: 1 + (_hatchAnimation.value * 0.2),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Egg base
                                Text(
                                  '🥚',
                                  style: TextStyle(
                                    fontSize: 120,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),

                                // Crack overlay
                                if (_crackAnimation.value > 0)
                                  Opacity(
                                    opacity: _crackAnimation.value,
                                    child: Text(
                                      '💥',
                                      style: TextStyle(
                                        fontSize: 80,
                                        color: Colors.orange.withValues(
                                          alpha: _crackAnimation.value,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Hatched pet reveal
                  if (_isHatching)
                    AnimatedBuilder(
                      animation: _hatchAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _hatchAnimation.value,
                          child: Transform.scale(
                            scale: _hatchAnimation.value * 0.8 + 0.2,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '✨',
                                  style: TextStyle(
                                    fontSize: 60,
                                    shadows: [
                                      Shadow(
                                        color: Colors.yellow
                                            .withValues(alpha: 0.6),
                                        blurRadius: 16,
                                        offset: const Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.egg.attributes.element,
                                  style: TextStyle(
                                    fontSize: 48,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── Countdown or Status Text ──────────────────────────────
            if (_isHatching)
              Column(
                children: [
                  const Text(
                    'Success! 🎉',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _countdown > 0
                        ? 'Closing in $_countdown...'
                        : 'Loading pet details...',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            else
              const Text(
                'Watch your egg hatch! ⏱️',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),

            const SizedBox(height: 32),

            // ── Pet Info ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _InfoChip(
                        icon: '🎲',
                        label: 'Rarity',
                        value: widget.egg.attributes.rarity,
                      ),
                      _InfoChip(
                        icon: '⚡',
                        label: 'Element',
                        value: widget.egg.attributes.element,
                      ),
                      _InfoChip(
                        icon: '💪',
                        label: 'Power',
                        value: '${widget.egg.attributes.basePower}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
