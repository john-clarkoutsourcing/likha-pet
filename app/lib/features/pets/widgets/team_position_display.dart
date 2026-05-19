import 'package:flutter/material.dart';
import '../models/owned_pet.dart';
import '../models/team_composition.dart';
import '../../battle/data/creature_registry.dart';

/// Displays a team composition as 3 columns: FRONT | MID | BACK
/// Shows pet names, class icons, and positions clearly.
class TeamPositionDisplay extends StatelessWidget {
  final TeamComposition? team;
  final List<OwnedPet> roster;
  final Function(int slot)? onSelectSlot; // Called when a position is tapped
  final bool isSelectable;

  const TeamPositionDisplay({
    super.key,
    required this.team,
    required this.roster,
    this.onSelectSlot,
    this.isSelectable = false,
  });

  OwnedPet? _getPetAt(int slot) {
    if (team == null || slot >= team!.petUids.length) return null;
    final uid = team!.petUids[slot];
    return roster.cast<OwnedPet?>().firstWhere(
      (p) => p?.uid == uid,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (slot) {
        final pet = _getPetAt(slot);
        final label = BattleRow.fromIndex(slot).label;
        return Expanded(
          child: _PositionSlot(
            label: label,
            pet: pet,
            slot: slot,
            onTap: isSelectable ? () => onSelectSlot?.call(slot) : null,
          ),
        );
      }),
    );
  }
}

/// Single position slot (FRONT, MID, or BACK)
class _PositionSlot extends StatelessWidget {
  final String label;
  final OwnedPet? pet;
  final int slot;
  final VoidCallback? onTap;

  const _PositionSlot({
    required this.label,
    required this.pet,
    required this.slot,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = pet == null;
    final body = isEmpty ? null : kBodyCatalogue[pet!.bodyId];
    final cls = body?.className ?? '';
    final color = _positionColor(slot);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
            width: 2,
          ),
          color: color.withValues(alpha: 0.05),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with position label
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Pet display or empty placeholder
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline,
                              size: 32,
                              color: color.withValues(alpha: 0.3)),
                          const SizedBox(height: 8),
                          Text(
                            'No Pet',
                            style: TextStyle(
                              color: color.withValues(alpha: 0.4),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Class icon
                          Image.asset(
                            'assets/images/icons/$cls.png',
                            width: 48,
                            height: 48,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.pets,
                              size: 40,
                              color: color.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Pet name
                          Text(
                            pet!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              overflow: TextOverflow.ellipsis,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),

                          // Pet class
                          Text(
                            pet!.classLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _positionColor(int slot) {
    return switch (slot) {
      0 => const Color(0xFFFF5252), // Red for Front
      1 => const Color(0xFFFFD700), // Gold for Mid
      2 => const Color(0xFF4CAF50), // Green for Back
      _ => const Color(0xFF9C27B0),
    };
  }
}
