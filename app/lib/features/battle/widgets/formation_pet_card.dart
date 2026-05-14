import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/hp_bar.dart';
import '../providers/battle_view_model.dart';

/// Compact horizontal pet card used in the left/right formation layout.
/// Shows position label (FRONT/MID/BACK), HP bar, energy, and status icons.
class FormationPetCard extends StatelessWidget {
  final PetViewModel pet;
  final bool isPlayer;         // true = left side (player)
  final bool isSelected;       // player pet currently selected for skill
  final bool hasSkillAssigned;
  final VoidCallback? onTap;

  const FormationPetCard({
    super.key,
    required this.pet,
    required this.isPlayer,
    this.isSelected = false,
    this.hasSkillAssigned = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (isPlayer && !pet.isFainted) ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        opacity: pet.isFainted ? 0.28 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderColor(), width: isSelected ? 2 : 1),
            boxShadow: isSelected
                ? [BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 6, spreadRadius: 1,
                  )]
                : null,
          ),
          child: Row(
            children: isPlayer
                ? [_Avatar(pet: pet), const SizedBox(width: 8), Expanded(child: _Info(pet: pet)), _AssignIndicator(assigned: hasSkillAssigned)]
                : [_AssignIndicator(assigned: false, enemy: true), Expanded(child: _Info(pet: pet, mirror: true)), const SizedBox(width: 8), _Avatar(pet: pet)],
          ),
        ),
      ),
    );
  }

  Color _borderColor() {
    if (isSelected) return AppColors.accent;
    if (hasSkillAssigned) return AppColors.primary.withValues(alpha: 0.5);
    if (pet.isFainted) return AppColors.fainted;
    if (pet.isStunned) return AppColors.stunYellow;
    if (pet.isPoisoned) return AppColors.poisonPurple;
    return AppColors.divider;
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final PetViewModel pet;
  const _Avatar({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _petColor().withValues(alpha: pet.isFainted ? 0.18 : 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          pet.isFainted ? '✕' : pet.name[0],
          style: TextStyle(
            fontSize: pet.isFainted ? 16 : 18,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: pet.isFainted ? 0.3 : 1.0),
          ),
        ),
      ),
    );
  }

  Color _petColor() {
    const colors = [
      Color(0xFF6C3FA1), Color(0xFF3FCFA1), Color(0xFFE8A838),
      Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047),
    ];
    return colors[pet.name.codeUnits.first % colors.length];
  }
}

// ── Info block ────────────────────────────────────────────────────────────────

class _Info extends StatelessWidget {
  final PetViewModel pet;
  final bool mirror; // true = enemy side (right-aligned text)
  const _Info({required this.pet, this.mirror = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          mirror ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name + position badge
        Row(
          mainAxisAlignment:
              mirror ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: mirror
              ? [_PositionBadge(label: pet.positionLabel), const SizedBox(width: 4), _Name(pet: pet)]
              : [_Name(pet: pet), const SizedBox(width: 4), _PositionBadge(label: pet.positionLabel)],
        ),
        const SizedBox(height: 3),

        // HP bar
        HpBar(current: pet.hp, max: pet.maxHp, height: 5),
        const SizedBox(height: 2),

        // HP number + status icons + energy
        Row(
          mainAxisAlignment:
              mirror ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: mirror
              ? [_StatusIcons(pet: pet), const SizedBox(width: 4), _HpText(pet: pet)]
              : [_HpText(pet: pet), const SizedBox(width: 4), _StatusIcons(pet: pet)],
        ),
      ],
    );
  }
}

class _Name extends StatelessWidget {
  final PetViewModel pet;
  const _Name({required this.pet});

  @override
  Widget build(BuildContext context) => Text(
        pet.name,
        style: TextStyle(
          color: pet.isFainted ? AppColors.textMuted : AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}

class _PositionBadge extends StatelessWidget {
  final String label;
  const _PositionBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'FRONT' => AppColors.offensive,
      'MID'   => AppColors.utility,
      _       => AppColors.defensive,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}

class _HpText extends StatelessWidget {
  final PetViewModel pet;
  const _HpText({required this.pet});

  @override
  Widget build(BuildContext context) => Text(
        '${pet.hp}/${pet.maxHp}',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
      );
}

class _StatusIcons extends StatelessWidget {
  final PetViewModel pet;
  const _StatusIcons({required this.pet});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pet.shield > 0) _icon('🛡', AppColors.shieldGold),
          if (pet.isPoisoned) _icon('☠', AppColors.poisonPurple),
          if (pet.isStunned) _icon('⚡', AppColors.stunYellow),
          ...List.generate(
            pet.maxEnergy,
            (i) => Padding(
              padding: const EdgeInsets.only(left: 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < pet.energy ? AppColors.energyBlue : AppColors.surfaceLight,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _icon(String e, Color c) =>
      Padding(padding: const EdgeInsets.only(right: 2), child: Text(e, style: TextStyle(fontSize: 9, color: c)));
}

// ── Assignment indicator ──────────────────────────────────────────────────────

class _AssignIndicator extends StatelessWidget {
  final bool assigned;
  final bool enemy;
  const _AssignIndicator({required this.assigned, this.enemy = false});

  @override
  Widget build(BuildContext context) {
    if (enemy) return const SizedBox(width: 16);
    return SizedBox(
      width: 16,
      child: assigned
          ? const Icon(Icons.check_circle, size: 14, color: AppColors.accent)
          : const SizedBox.shrink(),
    );
  }
}
