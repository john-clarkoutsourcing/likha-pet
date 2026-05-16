import 'package:flutter/material.dart';
import 'package:likha_pet_battle_engine/trait_system.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/battle_view_model.dart';

class TraitCard extends StatelessWidget {
  final TraitViewModel trait;
  final bool isSelected;
  final VoidCallback? onTap;

  const TraitCard({
    super.key,
    required this.trait,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final usable = trait.isUsable;
    final classKey = _classKeyFromTraitId(trait.id);
    final typeColor = _typeColor(trait.typeName);
    final frameColor = _classColor(classKey) ?? typeColor;
    final cardArtPath = TraitSystem().cardTemplatePathForId(trait.id);

    return GestureDetector(
      onTap: usable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isSelected
              ? frameColor.withValues(alpha: 0.22)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? frameColor
                : usable
                    ? frameColor.withValues(alpha: 0.45)
                    : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Opacity(
          opacity: usable ? 1.0 : 0.38,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cardArtPath != null)
                  Image.asset(
                    cardArtPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) =>
                        Container(color: _cardBgColor(frameColor)),
                  )
                else
                  Container(color: _cardBgColor(frameColor)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.70),
                          Colors.black.withValues(alpha: 0.90),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _TypeBadge(
                              typeName: trait.typeName, color: frameColor),
                          const SizedBox(width: 4),
                          _PartBadge(partName: trait.partName),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        trait.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        trait.effectSummary,
                        style: TextStyle(
                          color: frameColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _TargetingBadge(
                            mode: trait.targetingMode,
                            label: trait.targetSummary,
                          ),
                          const Spacer(),
                          _EnergyCost(
                              cost: trait.energyCost,
                              canAfford: trait.canAfford),
                        ],
                      ),
                      if (!trait.isReady) ...[
                        const SizedBox(height: 4),
                        _CooldownRow(
                          remaining: trait.cooldownRemaining,
                          max: trait.cooldownMax,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _classKeyFromTraitId(String id) {
    final i = id.indexOf('_');
    if (i <= 0) return null;
    final cls = id.substring(0, i);
    return switch (cls) {
      'beast' || 'bug' || 'bird' || 'plant' || 'aquatic' || 'reptile' => cls,
      _ => null,
    };
  }

  static Color? _classColor(String? cls) => switch (cls) {
        'beast' => const Color(0xFFF39A32),
        'aquatic' => const Color(0xFF2F9BFF),
        'plant' => const Color(0xFF7AC943),
        'bird' => const Color(0xFFFF8CC8),
        'bug' => const Color(0xFFB06BFF),
        'reptile' => const Color(0xFF4AB48B),
        _ => null,
      };

  static Color _cardBgColor(Color c) => Color.alphaBlend(
        c.withValues(alpha: 0.35),
        const Color(0xFF101623),
      );

  static Color _typeColor(String t) => switch (t) {
        'offensive' => AppColors.offensive,
        'defensive' => AppColors.defensive,
        'support' => AppColors.support,
        'utility' => AppColors.utility,
        _ => AppColors.primary,
      };
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String typeName;
  final Color color;
  const _TypeBadge({required this.typeName, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = switch (typeName) {
      'offensive' => '⚔',
      'defensive' => '🛡',
      'support' => '💚',
      'utility' => '⚡',
      _ => '✦',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(icon, style: const TextStyle(fontSize: 9)),
    );
  }
}

class _PartBadge extends StatelessWidget {
  final String partName;
  const _PartBadge({required this.partName});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (partName) {
      'horn' => ('🦏', 'HORN'),
      'back' => ('🎒', 'BACK'),
      'tail' => ('🦚', 'TAIL'),
      'mouth' => ('👄', 'MOUTH'),
      _ => ('🧬', 'BODY'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$icon $label',
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Shows how a skill targets: front-only, piercing, AoE, or ally.
class _TargetingBadge extends StatelessWidget {
  final String mode; // 'front' | 'pierce' | 'aoe' | 'ally'
  final String label;
  const _TargetingBadge({required this.mode, required this.label});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (mode) {
      'pierce' => ('🎯', AppColors.offensive),
      'aoe' => ('💥', AppColors.utility),
      'ally' => ('🤝', AppColors.support),
      _ => ('▶', AppColors.textMuted), // front
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 9)),
        const SizedBox(width: 2),
        Text(
          label,
          style:
              TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EnergyCost extends StatelessWidget {
  final int cost;
  final bool canAfford;
  const _EnergyCost({required this.cost, required this.canAfford});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        cost,
        (i) => Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Icon(
            Icons.circle,
            size: 7,
            color: canAfford ? AppColors.energyBlue : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CooldownRow extends StatelessWidget {
  final int remaining;
  final int max;
  const _CooldownRow({required this.remaining, required this.max});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 9, color: AppColors.utility),
        const SizedBox(width: 2),
        Text('CD $remaining',
            style: const TextStyle(color: AppColors.utility, fontSize: 9)),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: max > 0 ? remaining / max : 0,
              minHeight: 3,
              backgroundColor: AppColors.surfaceLight,
              valueColor: const AlwaysStoppedAnimation(AppColors.utility),
            ),
          ),
        ),
      ],
    );
  }
}
