import 'pet.dart';
import 'trait.dart';

/// A single queued combat action: one pet using one trait during a round.
///
/// Firebase/Flutter integration:
///   In PvP, an Action is reconstructed from ActionModel JSON received
///   from Firestore's pendingActions/{battleId} document.
///
///   In PvE, Actions are built in-memory by AiController without any
///   network round-trip — the BattleEngine runs fully client-side.
///
///   The Cloud Function's resolveTurn re-creates Action objects from the
///   same Firestore document to produce the authoritative resolution.
class Action {
  final Pet actor;
  final Trait trait;

  /// Explicit target override. When null, ActionResolver auto-selects
  /// the target based on trait.effect.target specification
  /// (e.g., 'lowest_hp_enemy', 'all_allies', 'self').
  ///
  /// Players may set this in a future manual-targeting UI.
  final Pet? primaryTarget;

  const Action({
    required this.actor,
    required this.trait,
    this.primaryTarget,
  });
}
