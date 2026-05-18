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
  ///
  /// CRITICAL: Both PvP clients must produce identical turn order even if
  /// called with different input order ([A, B] vs [B, A]).
  /// Solution: Normalize input order by sorting teams lexicographically
  /// before merging to ensure _Slot indices are always in same canonical order.
  List<Action> buildResolutionOrder(
    List<Action> actionsA,
    List<Action> actionsB,
  ) {
    // Normalize input order: always put the team with lexicographically smaller
    // first pet ID first. This ensures both clients produce identical slot indices
    // regardless of which side is "player" or "opponent".
    final firstA = actionsA.isNotEmpty ? actionsA.first.actor.id : '';
    final firstB = actionsB.isNotEmpty ? actionsB.first.actor.id : '';
    
    late final List<Action> orderedA;
    late final List<Action> orderedB;
    
    if (firstA.compareTo(firstB) <= 0) {
      orderedA = actionsA;
      orderedB = actionsB;
    } else {
      orderedA = actionsB;
      orderedB = actionsA;
    }

    final slots = [
      for (var i = 0; i < orderedA.length; i++)
        _Slot(action: orderedA[i], originalIndex: i),
      for (var i = 0; i < orderedB.length; i++)
        _Slot(action: orderedB[i], originalIndex: orderedA.length + i),
    ];
    final anyLastStand = slots.any((slot) => slot.action.actor.isInLastStand);

    // Classic-like priority:
    // 1) higher speed, 2) higher HP, 3) higher skill, 4) higher morale.
    // Final tiebreaker: pet ID string comparison (then index as ultimate tiebreaker).
    // This ensures 100% deterministic ordering regardless of platform/runtime.
    slots.sort((x, y) {
      final xBoost = x.action.trait.tags.contains('attack_first_if_last_stand') &&
              anyLastStand
          ? 1000
          : 0;
      final yBoost = y.action.trait.tags.contains('attack_first_if_last_stand') &&
              anyLastStand
          ? 1000
          : 0;
      final boostCmp = yBoost.compareTo(xBoost);
      if (boostCmp != 0) return boostCmp;
      final speedCmp = y.speed.compareTo(x.speed); // descending — faster first
      if (speedCmp != 0) return speedCmp;
      final hpCmp = y.hp.compareTo(x.hp);
      if (hpCmp != 0) return hpCmp;
      final skillCmp = y.skill.compareTo(x.skill);
      if (skillCmp != 0) return skillCmp;
      final moraleCmp = y.morale.compareTo(x.morale);
      if (moraleCmp != 0) return moraleCmp;
      final idCmp = x.action.actor.id.compareTo(y.action.actor.id);
      if (idCmp != 0) return idCmp;
      // Ultimate tiebreaker: original position in normalized input order
      return x.originalIndex.compareTo(y.originalIndex);
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
  final int originalIndex; // For deterministic tiebreaker across platforms

  int get speed => action.actor.effectiveSpeed;
  int get hp => action.actor.hp;
  int get skill => action.actor.skill;
  int get morale => action.actor.morale;

  _Slot({required this.action, required this.originalIndex});
}
