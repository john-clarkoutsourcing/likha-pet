import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/hp_bar.dart';
import '../providers/battle_view_model.dart';

class PetStatusCard extends StatelessWidget {
  final PetViewModel pet;
  final bool isEnemy;

  // Player-side interaction state
  final bool isSelected;
  final bool hasSkillAssigned;
  final VoidCallback? onTap;

  const PetStatusCard({
    super.key,
    required this.pet,
    this.isEnemy = false,
    this.isSelected = false,
    this.hasSkillAssigned = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (!isEnemy && !pet.isFainted) ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: pet.isFainted ? 0.3 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 100,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _borderColor(),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Avatar with assignment badge ──────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _PetAvatar(pet: pet),
                  if (!isEnemy && hasSkillAssigned && !pet.isFainted)
                    const Positioned(
                      top: -4,
                      right: -4,
                      child: _AssignedBadge(),
                    ),
                  if (!isEnemy && isSelected && !pet.isFainted)
                    Positioned(
                      bottom: -4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Name ──────────────────────────────────────────────────────
              Text(
                pet.name,
                style: TextStyle(
                  color: pet.isFainted
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              // ── Animated HP bar ───────────────────────────────────────────
              HpBar(current: pet.hp, max: pet.maxHp),
              const SizedBox(height: 2),
              Text(
                '${pet.hp}/${pet.maxHp}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                ),
              ),
              const SizedBox(height: 4),

              // ── Status + energy ───────────────────────────────────────────
              _StatusRow(pet: pet),
            ],
          ),
        ),
      ),
    );
  }

  Color _borderColor() {
    if (isSelected) return AppColors.accent;
    if (hasSkillAssigned) return AppColors.primary.withValues(alpha: 0.6);
    if (pet.isFainted) return AppColors.fainted;
    if (pet.isStunned) return AppColors.stunYellow;
    if (pet.isPoisoned) return AppColors.poisonPurple;
    return AppColors.divider;
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _PetAvatar extends StatelessWidget {
  final PetViewModel pet;
  const _PetAvatar({required this.pet});

  @override
  Widget build(BuildContext context) {
    // Phase 1: colored letter placeholder.
    // Phase 2: replace with Image.asset('assets/sprites/${pet.id}.png')
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: _petColor().withValues(alpha: pet.isFainted ? 0.2 : 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          pet.isFainted ? '✕' : pet.name[0],
          style: TextStyle(
            fontSize: pet.isFainted ? 22 : 26,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: pet.isFainted ? 0.3 : 0.95),
          ),
        ),
      ),
    );
  }

  Color _petColor() {
    const colors = [
      Color(0xFF6C3FA1),
      Color(0xFF3FCFA1),
      Color(0xFFE8A838),
      Color(0xFFE53935),
      Color(0xFF1E88E5),
      Color(0xFF43A047),
    ];
    return colors[pet.name.codeUnits.first % colors.length];
  }
}

// ── Assigned badge ────────────────────────────────────────────────────────────

class _AssignedBadge extends StatelessWidget {
  const _AssignedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 10, color: Colors.white),
    );
  }
}

// ── Status + energy row ───────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final PetViewModel pet;
  const _StatusRow({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (pet.shield > 0) _icon('🛡', AppColors.shieldGold),
        if (pet.isPoisoned) _icon('☠', AppColors.poisonPurple),
        if (pet.isStunned) _icon('⚡', AppColors.stunYellow),
        const SizedBox(width: 2),
        ...List.generate(pet.maxEnergy, (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < pet.energy
                  ? AppColors.energyBlue
                  : AppColors.surfaceLight,
            ),
          ),
        )),
      ],
    );
  }

  Widget _icon(String emoji, Color color) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Text(emoji, style: TextStyle(fontSize: 9, color: color)),
      );
}
