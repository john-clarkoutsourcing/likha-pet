import 'trait.dart';

/// One card in a team's skill deck.
///
/// A card is a specific instance of a trait — the same trait can appear
/// as two separate cards (copyIndex 0 and 1). This lets players hold
/// two copies of a trait in hand and choose when to play each one.
///
/// [isPity] flags cards injected by PitySentinel to guarantee a pet
/// gets at least one card after 2 consecutive dry turns.
class SkillCard {
  final String instanceId;
  final Trait  trait;
  final String ownerPetId;
  final int    copyIndex; // 0 or 1; 99 = pity-injected
  final bool   isPity;

  const SkillCard({
    required this.instanceId,
    required this.trait,
    required this.ownerPetId,
    required this.copyIndex,
    this.isPity = false,
  });
}
