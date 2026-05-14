import 'pet.dart';
import 'trait.dart';
import 'action.dart';

/// Determines the order in which Actions resolve each round.
///
/// Current rule: all pets share equal base speed (kBaseSpeed = 30).
/// Within a speed tier, Team A acts before Team B — this is the
/// deterministic tiebreaker used by both the Flutter client and the
/// Cloud Function to guarantee identical resolution order without
/// any coordination between the two.
///
/// Future extension:
///   When speed differentiation is added (e.g., speed buffs from traits),
///   _Slot.speedTier is the single place to update. Everything else adapts.
///   Higher effectiveSpeed → lower speedTier → acts first.
///
/// Firebase/PvP note:
///   The Cloud Function calls buildResolutionOrder() with the same inputs
///   as the client to produce the canonical action sequence. Both sides
///   must produce identical output — this class has no randomness.
class TurnManager {
  /// Merge and sort [actionsA] (Team A) and [actionsB] (Team B) into
  /// the order in which their effects will be applied this round.
  List<Action> buildResolutionOrder(
    List<Action> actionsA,
    List<Action> actionsB,
  ) {
    final slots = [
      for (final a in actionsA) _Slot(action: a, teamIndex: 0),
      for (final b in actionsB) _Slot(action: b, teamIndex: 1),
    ];

    // Primary sort: higher speed acts first (descending).
    // Secondary sort: Team A (index 0) before Team B (index 1) on ties.
    slots.sort((x, y) {
      final speedCmp = y.speed.compareTo(x.speed); // descending — faster first
      if (speedCmp != 0) return speedCmp;
      return x.teamIndex.compareTo(y.teamIndex);
    });

    return slots.map((s) => s.action).toList();
  }

  /// Build Action slots from a team's live Pet list.
  /// [traitSelector] picks each pet's trait for this round (AI or player).
  /// Fainted pets are excluded — BattleEngine skips them before ActionResolver.
  List<Action> buildSlots(
    List<Pet> team,
    Trait Function(Pet) traitSelector,
  ) {
    return [
      for (final pet in team)
        if (!pet.isFainted) Action(actor: pet, trait: traitSelector(pet)),
    ];
  }
}

// ── Internal sort key ─────────────────────────────────────────────────────────

class _Slot {
  final Action action;
  final int teamIndex; // 0 = Team A, 1 = Team B

  /// The pet's speed stat — used for descending sort (higher = acts first).
  int get speed => action.actor.speed;

  _Slot({required this.action, required this.teamIndex});
}
