import 'pet.dart';
import 'skill_card.dart';
import 'skill_deck.dart';

/// Tracks how many consecutive turns each pet has gone without any card in hand.
/// After [kPityThreshold] dry turns, injects one copy of the pet's cheapest trait
/// directly to the top of the draw pile — guaranteeing it is drawn next turn.
///
/// This prevents a pet from being completely locked out of action by bad RNG
/// for more than 2 turns in a row.
class PitySentinel {
  final Map<String, int> _dryStreak = {};
  static const int kPityThreshold = 2;

  /// Call after each [drawTurn()] to update which pets are represented in hand.
  void update(List<SkillCard> hand, List<String> allPetIds) {
    final represented = hand.map((c) => c.ownerPetId).toSet();
    for (final id in allPetIds) {
      if (represented.contains(id)) {
        _dryStreak[id] = 0;
      } else {
        _dryStreak[id] = (_dryStreak[id] ?? 0) + 1;
      }
    }
  }

  /// Injects a guaranteed card to the top of [deck] for any pet that has
  /// been without a hand card for [kPityThreshold]+ consecutive turns.
  /// Resets the dry streak counter for each injected pet.
  void injectIfNeeded(SkillDeck deck, List<Pet> pets) {
    for (final entry in _dryStreak.entries) {
      if (entry.value < kPityThreshold) continue;
      final petId = entry.key;
      final pet = pets.where((p) => p.id == petId && !p.isFainted).firstOrNull;
      if (pet == null) continue;

      final cheapest = pet.traits.reduce(
        (a, b) => a.energyCost <= b.energyCost ? a : b,
      );
      deck.insertPityCard(SkillCard(
        instanceId: '${petId}_${cheapest.id}_pity',
        trait:      cheapest,
        ownerPetId: petId,
        copyIndex:  99,
        isPity:     true,
      ));
      _dryStreak[petId] = 0;
    }
  }

  /// Dry streak count for a specific pet (0 = had a card last turn).
  int dryStreakFor(String petId) => _dryStreak[petId] ?? 0;
}
