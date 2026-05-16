import 'dart:math';
import 'pet.dart';
import 'skill_card.dart';

/// Team skill deck — dynamic card count
/// (team size × traits per pet × 2 copies).
///
/// Draw mechanics:
///   - Draw 3 cards per turn into a shared hand (max 10 cards).
///   - If the hand is full, newly drawn cards are discarded.
///   - When the draw pile empties, the discard pile is reshuffled into a new draw pile.
///   - Cards stay in hand until played or overflowed.
///
/// Card ownership:
///   - Every card is tagged to a specific pet via [ownerPetId].
///   - Only that pet can use the card — it's filtered in the UI via [handFor].
///
/// Seeded shuffle:
///   - Provide [seed] for deterministic replay (PvP validation, replays).
///   - Omit or set randomly for PvE.
class SkillDeck {
  final List<SkillCard> _draw    = [];
  final List<SkillCard> _hand    = [];
  final List<SkillCard> _discard = [];

  static const int kHandLimit   = 10; // Axie Classic hand cap
  static const int kDrawPerTurn = 3;  // per round after the initial deal

  SkillDeck.fromTeam(List<Pet> pets, {required int seed}) {
    for (final pet in pets) {
      for (var copy = 0; copy < 2; copy++) {
        for (final trait in pet.traits) {
          _draw.add(SkillCard(
            instanceId: '${pet.id}_${trait.id}_$copy',
            trait:      trait,
            ownerPetId: pet.id,
            copyIndex:  copy,
          ));
        }
      }
    }
    _draw.shuffle(Random(seed));
  }

  /// Draws [count] cards (default [kDrawPerTurn]).
  /// If hand is at [kHandLimit], drawn cards go straight to discard.
  List<SkillCard> drawTurn([int count = kDrawPerTurn]) {
    final drawn = <SkillCard>[];
    for (var i = 0; i < count; i++) {
      if (_draw.isEmpty) _recycleDeck();
      if (_draw.isEmpty) break;
      final card = _draw.removeAt(0);
      if (_hand.length < kHandLimit) {
        _hand.add(card);
        drawn.add(card);
      } else {
        _discard.add(card);
      }
    }
    return drawn;
  }

  /// Remove a card from hand to the discard pile (manual player discard).
  bool discardCard(String instanceId) => play(instanceId);

  /// Insert a pity card at the top of the draw pile so it is drawn next turn.
  void insertPityCard(SkillCard card) => _draw.insert(0, card);

  /// Mark a card as played — moves from hand to discard.
  /// Returns false if the card is not currently in hand.
  bool play(String instanceId) {
    final idx = _hand.indexWhere((c) => c.instanceId == instanceId);
    if (idx < 0) return false;
    _discard.add(_hand.removeAt(idx));
    return true;
  }

  void _recycleDeck() {
    _draw.addAll(_discard);
    _discard.clear();
    _draw.shuffle();
  }

  List<SkillCard> get hand     => List.unmodifiable(_hand);
  int get drawPileSize          => _draw.length;
  int get discardPileSize       => _discard.length;
  int get handSize              => _hand.length;

  /// Cards in hand that belong to [petId].
  List<SkillCard> handFor(String petId) =>
      _hand.where((c) => c.ownerPetId == petId).toList();
}
