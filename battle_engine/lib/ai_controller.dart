import 'pet.dart';
import 'trait.dart';

/// Rule-based AI that selects the best available [Trait] for a pet each round.
///
/// Priority order (highest → lowest):
///   1. Heal an ally at critical HP (< 40%)
///   2. Stun an enemy — powerful CC that wastes their turn
///   3. Shield self at critical HP (< 40%) with no current shield
///   4. Team buff when team is unbuffed
///   5. Team-wide buff when the team isn't already buffed
///   6. Highest-damage single-target offensive trait
///   7. Any affordable, ready trait (fallback)
///
/// Override this class for monster-specific behavior:
///   MonsterAiController extends AiController and overrides selectTrait()
///   with behavior types (aggressive, defensive, support-focused, balanced).
///
/// Flutter/PvE integration:
///   AiController is instantiated once per battle for the player's team
///   in PveBattleNotifier. MonsterAiController instances are assigned to
///   individual monsters by MonsterFactory based on their Firestore document.
class AiController {
  Trait selectTrait(Pet actor, List<Pet> allyTeam, List<Pet> enemyTeam) {
    // All traits the pet can legally use this round
    final available = actor.traits
        .where((t) => t.isReady && actor.canAfford(t.energyCost))
        .toList();

    // Cannot act — return first trait as an idle placeholder.
    // BattleEngine will skip the action if energy/CD checks fail at resolve time.
    if (available.isEmpty) return actor.traits.first;

    // ── Priority 1: Heal a critical ally ─────────────────────────────────────
    if (_anyAllyBelowThreshold(allyTeam, 0.40)) {
      final t = _findBestHeal(available);
      if (t != null) return t;
    }

    // ── Priority 2: Stun an unstunned enemy ──────────────────────────────────
    // Stun wastes an enemy's full turn — worth spending 3 energy for.
    if (_hasUnstunnedEnemy(enemyTeam)) {
      final t = _findStun(available);
      if (t != null) return t;
    }

    // ── Priority 3: Shield self at critical HP ────────────────────────────────
    final hpRatio = actor.hp / kBaseHp;
    if (hpRatio < 0.40 && actor.shield == 0) {
      final t = _findShield(available);
      if (t != null) return t;
    }

    // ── Priority 4: Team buff when team is unbuffed ───────────────────────────
    final teamBuff = _findTeamBuff(available);
    if (teamBuff != null && !_teamHasBuff(allyTeam, teamBuff)) {
      return teamBuff;
    }

    // ── Priority 5: Best single-target offensive trait ────────────────────────
    final offensive = _findBestOffensive(available);
    if (offensive != null) return offensive;

    // ── Priority 7: Fallback ──────────────────────────────────────────────────
    return available.first;
  }

  // ── Finders ───────────────────────────────────────────────────────────────

  Trait? _findBestHeal(List<Trait> traits) {
    // Prefer the highest-value heal; team heals outrank single-target on ties.
    Trait? best;
    for (final t in traits) {
      if (t.effect.type != EffectType.heal) continue;
      if (best == null || _healScore(t) > _healScore(best)) best = t;
    }
    return best;
  }

  int _healScore(Trait t) {
    // Team heal gets a bonus weight to prefer it over single-target when equal value
    final bonus = t.effect.target == 'all_allies' ? 10 : 0;
    return t.effect.value + bonus;
  }

  Trait? _findStun(List<Trait> traits) {
    final matches = traits.where(
      (t) =>
          t.effect.type == EffectType.debuff &&
          t.effect.debuffType == DebuffType.stunned,
    );
    return matches.isEmpty ? null : matches.first;
  }

  Trait? _findShield(List<Trait> traits) {
    // Only self-shields count for the self-preservation priority
    final matches = traits.where(
      (t) =>
          t.effect.type == EffectType.shield &&
          (t.effect.target == 'self' || t.effect.target == 'lowest_hp_ally'),
    );
    if (matches.isEmpty) return null;
    return matches.reduce((a, b) => a.effect.value >= b.effect.value ? a : b);
  }

  Trait? _findTeamBuff(List<Trait> traits) {
    final matches = traits.where(
      (t) =>
          t.effect.type == EffectType.buff && t.effect.target == 'all_allies',
    );
    return matches.isEmpty ? null : matches.first;
  }

  Trait? _findBestOffensive(List<Trait> traits) {
    final offensive = traits.where(
      (t) => t.effect.type == EffectType.damage,
    ).toList();
    if (offensive.isEmpty) return null;
    return offensive.reduce(
      (a, b) => a.effect.value >= b.effect.value ? a : b,
    );
  }

  // ── Condition checks ──────────────────────────────────────────────────────

  bool _anyAllyBelowThreshold(List<Pet> allies, double threshold) {
    return allies.any((p) => !p.isFainted && p.hp / kBaseHp < threshold);
  }

  bool _hasUnstunnedEnemy(List<Pet> enemies) {
    return enemies.any((p) => !p.isFainted && !p.isStunned);
  }

  bool _teamHasBuff(List<Pet> allies, Trait buffTrait) {
    if (buffTrait.effect.buffType == null) return false;
    // Consider the buff "already applied" if any ally carries it
    return allies.any(
      (p) => p.buffs.any((b) => b.type == buffTrait.effect.buffType),
    );
  }
}
