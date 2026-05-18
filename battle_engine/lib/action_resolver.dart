import 'dart:math' as math;
import 'pet.dart';
import 'trait.dart';
import 'action.dart';
import 'battle_logger.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION RESOLVER — DEVELOPER GUIDE
// ═══════════════════════════════════════════════════════════════════════════════
//
// This file is the single place where every card effect is applied to live Pet
// objects. The pipeline runs once per card played, in this strict order:
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  STAGE 1 — Pre-action guards  (top of resolve(), before energy spend)   │
// │                                                                          │
// │  Check whether the actor CAN act this turn.                             │
// │  Return early (no energy spent, no cooldown) if blocked.                │
// │                                                                          │
// │  WHERE TO ADD:                                                           │
// │  • A new debuff that PREVENTS an action entirely (like stun, fear, or   │
// │    isolate) → add an `if (actor.isXxx) { ... return; }` block HERE.    │
// │  • After the isFainted check, before spendEnergy().                     │
// │                                                                          │
// │  Current guards (in order):                                             │
// │    isFainted      → skip silently                                        │
// │    isIsolated     → skip ally-targeting cards only, consume the debuff  │
// │    isStunned      → skip + consume stun                                 │
// │    isFeared       → skip + consume fear                                 │
// │    isDisabled     → skip + consume disabled                             │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  STAGE 2 — Energy spend + cooldown + cleanse tag                        │
// │                                                                          │
// │  actor.spendEnergy / trait.triggerCooldown run here. Do NOT move them. │
// │  'cleanse' tag also runs here (before primary effect, so debuffs are    │
// │  cleared even if the card itself applies new ones).                     │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  STAGE 3 — Primary effect  (the switch statement)                       │
// │                                                                          │
// │  Driven by TraitEffect.type set in classic_card_specs + _classicOverride│
// │                                                                          │
// │  EffectType.damage    → single-target hit. Target resolved by           │
// │                         effect.target string. See TARGET STRINGS below. │

// │  EffectType.heal      → restores HP. Capped by kMaxFlatHealing (50).    │
// │  EffectType.shield    → grants shield. Cleared at round end.            │
// │  EffectType.buff      → applies a BuffType for N rounds.                │
// │  EffectType.debuff    → applies a DebuffType for N rounds.              │
// │  EffectType.shieldBreak → removes enemy shield + optionally shields     │
// │                           self (effect.value).                          │
// │                                                                          │
// │  WHERE TO ADD:                                                           │
// │  • A card whose ENTIRE behavior is one of the above → set effect.type   │
// │    correctly in _classicOverride or the static TraitLibrary getter.     │
// │  • A new primary effect category (rare) → add a new EffectType enum    │
// │    value in trait.dart AND a new case here.                             │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  STAGE 4 — Post-damage tag effects  (inside EffectType.damage case)     │
// │                                                                          │
// │  Run AFTER the damage loop, so 'actual' and 'shieldBroke' are known.   │
// │  Also run _applyShieldBreakReactions and _applyOnHitReactions here      │
// │  (those check the DEFENDER's back/tail trait, not the attacker's).      │
// │                                                                          │
// │  WHERE TO ADD a tag that:                                               │
// │  • Redirects the target BEFORE damage → add in the redirect block just  │
// │    before ignoreShield (target_aquatic_if_low_hp pattern)               │
// │  • Only makes sense after damage lands (need actual / shieldBroke)      │
// │  • Targets the ENEMY (target variable is available)                     │
// │  • Fires unconditionally on any hit → add after _applyOnHitReactions    │
// │  • Fires only if hit dealt HP damage → condition on `actual > 0`        │
// │  • Fires only if shield broke → condition on `shieldBroke`              │
// │  • Fires only when comboed → condition on `comboIndex >= N`             │
// │                                                                          │
// │  Current tags handled here (in order after damage loop):                │
// │    draw_if_attack_first          comboIndex == 0 → draw card            │
// │    draw_if_attack_idle_target    shieldBefore==0 → draw card            │
// │    draw_if_attack_aqua_bird_dawn target class → draw card               │
// │    attacker_energy_on_shield_break  shieldBroke → actor gains energy    │
// │    draw_if_shield_not_break      !shieldBroke → draw card               │
// │    end_last_stand                kills last-stand target                 │
// │    lifeSteal                     heal actor by actual HP dealt           │
// │    energy_on_crit                isCrit → actor gains energy            │
// │    self_atk_up_vs_plant_reptile  AttackUp self vs Plant or Reptile      │
// │    self_atk_up_vs_beast_bug      AttackUp self vs Beast or Bug          │
// │    self_speed_up_on_hit          SpeedUp self when hit lands            │
// │    target_aroma                  actual>0 → Aroma on target             │
// │    isolated_on_combo_3           comboIndex>=2 → Isolate on target      │
// │    transfer_debuffs              move actor's debuffs to target          │
// │    reflect                       target reflects % damage back           │
// │    energySteal / energyDrain     drain enemy energy                     │
// │    energy_gain_on_combo          comboIndex>=1 → actor gains energy     │
// │    energy_steal_on_combo         comboIndex>=1 → steal enemy energy     │
// │    energy_gain_vs_buffed         target has buffs → actor gains energy  │
// │    lifesteal_vs_plant            heal actor vs Plant targets             │
// │    lifesteal_vs_aquatic          heal actor vs Aquatic targets           │
// │    shield_equal_to_damage        actor shield += actual damage dealt     │
// │    apply_lethal_if_low_hp        target HP≤50% → apply Lethal           │
// │    apply_fear_if_shielded        shieldBefore>0 → apply Fear on target  │
// │    energy_if_target_faster       target faster → actor gains 1 energy   │
// │    stun_on_combo_3_total         actorComboSize>=3 → stun target        │
// │    self_damage_30pct_max_hp      deal 30% maxHP self-damage (no shield) │
// └─────────────────────────────────────────────────────────────────────────┘
//
// REDIRECT TAGS (fire before damage, override the resolved target):
//   target_aquatic_if_low_hp   actor HP≤50% → prefer Aquatic enemy
//   target_bug_if_low_hp       actor HP≤50% → prefer Bug enemy
//   target_injured_if_low_hp   actor HP≤50% → prefer lowest-HP enemy
//   target_bird_on_combo       comboIndex>=1 → prefer Bird enemy
//
// DAMAGE BOOST TAGS (in damageBoost block, before the hit loop):
//   bonus_if_acts_last         isLastActor → +20% damage (Prickly Trap)
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  STAGE 5 — Post-switch shared effects  (after the switch, any type)     │
// │                                                                          │
// │  Runs regardless of which EffectType the card used.                     │
// │                                                                          │
// │  WHERE TO ADD a tag that:                                               │
// │  • Must fire even for buff/heal/shield/debuff cards (not just damage)   │
// │  • Does NOT need the damage-case variables (actual, target, shieldBroke)│
// │  • Applies an effect TO THE ACTOR (self effects)                        │
// │                                                                          │
// │  Current items here:                                                     │
// │    consumeAttackModifiers   clears attackUp/attackDown after offense    │
// │    _tickPoison              all poisoned pets lose HP per action        │
// │    self_aroma               actor gets Aroma (any card type)            │
// │    self_speed_up_on_combo   comboIndex>=1 → SpeedUp self               │
// │    selfShield               actor gets shield from effect.selfShield    │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  STAGE 6 — Reaction hooks  (private methods, called from Stage 3/4)     │
// │                                                                          │
// │  _applyShieldBreakReactions  — fires when the DEFENDER's shield breaks. │
// │    Reads traitsByPetId[target.id] (the card the DEFENDER played).       │
// │    WHERE TO ADD: tags that reward a pet for having their shield broken.  │
// │      on_shield_break_attack_up  → self attack up                        │
// │      on_shield_break_energy     → self gains energy                     │
// │      on_shield_break_stun_attacker → stun the attacker                  │
// │      counter_stun_aqua_bird / counter_stun_plant_reptile by class       │
// │      draw_if_shield_break       → draw a card                           │
// │                                                                          │
// │  _applyOnHitReactions — fires when the DEFENDER takes any damage.       │
// │    Reads same defender trait. Receives shieldBroke bool.                │
// │    WHERE TO ADD: tags that trigger when a pet is struck.                │
// │      on_hit_energy_vs_aquatic   → gain energy if hit by aquatic         │
// │      draw_if_hit_by_beast_bug_mech → draw card by attacker class        │
// │      draw_if_hit_shield_held    → draw if shield absorbed but held      │
// │      counter_stun_aqua_bird / counter_stun_plant_reptile (non-break)    │
// │      shield_when_hit            → gain a small shield on any hit        │
// │      disable_*                  → disable attacker's next card          │
// │      reflect_ranged / reflect_melee → apply reflect status              │
// └─────────────────────────────────────────────────────────────────────────┘
//
// TARGET STRINGS (effect.target)
// ─────────────────────────────
//  'enemy'           Front-most alive enemy (respects Aroma / Stench)
//  'back_enemy'      Back-row enemy (pierces formation)
//  'furthest_enemy'  Same as back_enemy
//  'lowest_hp_enemy' Enemy with least remaining HP
//  'fastest_enemy'   Fastest enemy (highest effectiveSpeed)

//  'self'            The card user themselves
//  'lowest_hp_ally'  Teammate with least HP
//  'front_ally'      First alive teammate (index 0)
//  'all_allies'      Every alive teammate (heals/buffs)
//
// DEBUFF TYPES  (DebuffType enum in trait.dart)
// ─────────────────────────────────────────────
//  stunned      Skip next action. Consumed immediately on skip.
//  fear         Skip next action (same as stun, different flavour). Consumed.
//  disabled     Skip next action (ability-specific block). Consumed.
//  isolate      Cannot use ally-targeting cards this round. Consumed on skip.
//  poisoned     Take N HP per action (stacks up to 13). Ticks in resolver.
//  burned       Take N HP per round. Ticks in processStatusEffects().
//  sleep        Next hit ignores shield. Removed when hit.
//  aroma        Forced target for enemies (they must attack you).
//  stench       Enemies skip targeting you (opposite of aroma).
//  chill        Cannot enter Last Stand.
//  jinx         Cannot deal critical hits.
//  reflect      Reflect X% of incoming melee/ranged damage back.
//  healBlocked  Cannot receive healing (regen, lifesteal, heal cards).
//  critBlocked  Cannot be critically hit this round.
//  moraleDown   Reduce crit chance (lowers effective morale).
//  fragile      Take 25% more defense reduction (flat −25% defense).
//  lethal       Next lethal hit bypasses Last Stand (pet dies outright).
//  attackDown   Reduce attack by X% for N rounds.
//  defenseDown  Reduce defense by X% for N rounds.
//  speedDown    Reduce speed for N rounds.
//
//  Duration meanings:
//    duration = 1 → expires at end of current round (tickRoundDurations)
//    duration = 2 → active current round + next round
//    duration = 4 → active for 4 full rounds
//    duration = 999 → effectively permanent (poison stacks use this)
//
// BUFF TYPES  (BuffType enum in trait.dart)
// ─────────────────────────────────────────
//  attackUp   +X% attack for N rounds. Consumed when pet attacks (!)
//  defenseUp  +X% defense for N rounds.
//  speedUp    +X% speed for N rounds. Affects turn order.
//  moraleUp   Increase crit chance (raises effective morale).
//  energized  Gain +X bonus energy per round.
//  regen      Restore X HP per round (ticks in processStatusEffects).
//
// ── Hard balance caps ──────────────────────────────────────────────────────────
//
// These caps prevent any single action from one-shotting a pet or trivialising
// the healing loop. They are compile-time constants — never adjusted at runtime.
// No level scaling exists; every pet has identical base stats (kBaseHp = 150).
//
// Firebase note: the Cloud Function imports these same constants and applies
// them server-side during resolveTurn to ensure client and server produce
// identical results.

const int kMaxSingleHitDamage = 90; // Single-target damage ceiling (no AoE in Axie)
const int kMaxFlatHealing = 50; // Largest single heal
const int kMaxShield = 999; // Classic-style accumulated shield per round

// ── ActionResolver ─────────────────────────────────────────────────────────────

/// Applies one [Action]'s trait effect to the live battle state.
///
/// Design rule: the resolver applies ALL effects to live [Pet] objects.
/// It never reads from or writes to Firebase — that is BattleEngine's job.
///
/// Damage formula:
///   net = clamp(attacker.effectiveAttack + traitBaseValue
///               - defender.effectiveDefense, 1, 999)
///   actual = clamp(net, 1, cap)   ← cap is kMaxSingleHitDamage
///
/// Defense is subtracted HERE (not inside Pet.takeDamage) so that balance caps
/// are applied to the post-defense value the HP pool actually sees.
/// Pet.takeDamage only handles shield absorption.
///
/// Flutter integration:
///   ActionResolver writes to [BattleLogger]. The logger's [events] stream
///   drives animations in the BattleScreen widget tree.
///
/// Combo target lock (Axie rule):
///   All cards played by one pet in a round attack the same target.
///   BattleEngine calls [precomputeComboTargets] before the resolution loop,
///   then passes the result as [comboTarget] per card. See [resolve].
class ActionResolver {
  /// Target specs that can lock the combo target for an actor's full round.
  /// Excludes the default 'enemy' (front-targeting) — only non-default enemy
  /// specs qualify as combo-lock triggers.
  static const _kComboLockSpecs = {
    'furthest_enemy',
    'back_enemy',
    'lowest_hp_enemy',
    'fastest_enemy',
  };

  /// All enemy-facing single-target specs. When a pre-computed [comboTarget]
  /// is available, it is used for cards whose spec is one of these — so that
  /// "normal" cards attack the same target as the special one in the combo.
  static const _kEnemySingleTargetSpecs = {
    'enemy',
    'furthest_enemy',
    'back_enemy',
    'lowest_hp_enemy',
    'fastest_enemy',
  };
  final BattleLogger log;
  final math.Random _rng;
  final Map<String, Trait> _roundTraitsByPetId;
  final void Function(String petId)? onDrawCard;
  final void Function(String petId)? onDiscardCard;

  ActionResolver(
    this.log, {
    required math.Random rng,
    Map<String, Trait>? roundTraitsByPetId,
    this.onDrawCard,
    this.onDiscardCard,
  })  : _rng = rng,
        _roundTraitsByPetId = roundTraitsByPetId ?? const {};

  // ── Combo target pre-computation ───────────────────────────────────────────

  /// Pre-compute the locked combo target for every actor in [ordered].
  ///
  /// Axie rule: all cards played by one pet in a single round attack the same
  /// target. If any card in the combo has a non-default enemy target spec
  /// (furthest, lowest HP, fastest), that spec sets the target for ALL of
  /// that actor's enemy-facing damage cards this round. The first special spec
  /// encountered (in card order) wins.
  ///
  /// Returns petId → locked combo target. An absent entry means no special spec
  /// was found; [resolve] falls back to per-card [_resolveTarget] for those.
  Map<String, Pet?> precomputeComboTargets(
    List<Action> ordered,
    List<Pet> teamA,
    List<Pet> teamB,
  ) {
    final teamAIds = {for (final p in teamA) p.id};

    // Group actions by actor, preserving card (resolution) order.
    final actionsByActor = <String, List<Action>>{};
    for (final a in ordered) {
      (actionsByActor[a.actor.id] ??= []).add(a);
    }

    final result = <String, Pet?>{};
    for (final entry in actionsByActor.entries) {
      final actorId = entry.key;
      final actions = entry.value;
      final actor   = actions.first.actor;
      if (actor.isFainted) continue;

      final isOnTeamA = teamAIds.contains(actorId);
      final actorTeam = isOnTeamA ? teamA : teamB;
      final enemyTeam = isOnTeamA ? teamB : teamA;

      // Scan cards in order; first special enemy-target spec wins.
      for (final a in actions) {
        final spec = a.trait.effect.target;
        if (_kComboLockSpecs.contains(spec)) {
          result[actorId] = _resolveTarget(spec, actor, actorTeam, enemyTeam);
          break;
        }
      }
      // No special spec → actor absent from result → per-card fallback in resolve().
    }
    return result;
  }

  void resolve(
    Action action,
    List<Pet> actorTeam,
    List<Pet> enemyTeam, {
    int comboIndex = 0,
    Map<String, Trait>? roundTraitsByPetId,
    Pet? comboTarget,
    /// Total number of cards this actor plays in this round.
    /// Used for "comboed with N+ cards" conditions (e.g. Chomp stun on 3+ combo).
    int actorComboSize = 1,
    /// True when this actor is the last to fire in the round (lowest speed).
    /// Used for 'bonus_if_acts_last' (Prickly Trap).
    bool isLastActor = false,
  }) {
    final traitsByPetId = roundTraitsByPetId ?? _roundTraitsByPetId;
    final actor = action.actor;
    final trait = action.trait;
    final effect = trait.effect;

    if (actor.isFainted) return;
    const _kAllyTargets = {'all_allies', 'lowest_hp_ally', 'front_ally', 'self'};
    if (actor.isIsolated && _kAllyTargets.contains(effect.target)) {
      log.debuff(actor.name, 'isolate', 0, 0); // log the forced skip
      actor.removeDebuff(DebuffType.isolate);
      return;
    }
    if (actor.isStunned || actor.isFeared || actor.isDisabled) {
      if (actor.isStunned) {
        log.stunSkip(actor.name);
        actor.removeDebuff(DebuffType.stunned);
      } else if (actor.isFeared) {
        log.debuff(actor.name, 'fear', 0, 1);
        actor.removeDebuff(DebuffType.fear);
      } else {
        log.debuff(actor.name, 'disabled', 0, 1);
        actor.removeDebuff(DebuffType.disabled);
      }
      return;
    }

    // Spend energy and start cooldown before resolving effects so that a pet
    // cannot re-use the same trait if it somehow acts twice in one round.
    actor.spendEnergy(trait.energyCost);
    trait.triggerCooldown();

    // If actor is in Last Stand, consume 1 tick per action
    if (actor.isInLastStand) {
      actor.lastStandTicks = (actor.lastStandTicks - 1).clamp(0, 999);
      if (actor.lastStandTicks <= 0) {
        actor.hp = 0;
        actor.isFainted = true;
        log.action(actor.name, '${trait.name} (Last Stand ended)');
        return; // Skip rest of resolution, pet fainted
      }
    }

    log.action(actor.name, trait.name);

    if (trait.tags.contains('cleanse') && actor.debuffs.isNotEmpty) {
      actor.debuffs.clear();
      log.debuff(actor.name, 'cleanse', 0, 0);
    }

    switch (effect.type) {
      // ── Single-target damage ──────────────────────────────────────────────
      case EffectType.damage:
        // Target resolution priority (Axie combo-lock model):
        //  1. Explicit primaryTarget — if alive AND not Stench.
        //     (Stench = skip this pet; fall through to re-resolve.)
        //  2. Pre-computed comboTarget — if alive, not Stench, and enemy spec.
        //  3. Per-card _resolveTarget fallback → _preferredTarget respects
        //     Stench and Aroma correctly.
        var target = action.primaryTarget != null &&
                    !action.primaryTarget!.isFainted &&
                    !action.primaryTarget!.isStenched
            ? action.primaryTarget
            : comboTarget != null &&
                      !comboTarget.isFainted &&
                      !comboTarget.isStenched &&
                      _kEnemySingleTargetSpecs.contains(effect.target)
                  ? comboTarget
                  : _resolveTarget(
                      effect.target,
                      actor,
                      actorTeam,
                      enemyTeam,
                    );
        // No valid target found — skip this card silently.
        if (target == null || target.isFainted) {
          log.noTarget();
          return;
        }
        // If the trait has skip_targets_in_last_stand and the target is in last stand, try to find an alive non-last-stand target.
        if (trait.tags.contains('skip_targets_in_last_stand') &&
            target.isInLastStand) {
          final altTarget = _preferredTarget(
            _aliveCandidates(enemyTeam).where((p) => !p.isInLastStand).toList(),
          );
          if (altTarget != null) {
            target = altTarget;
          }
        }
        // ── Target redirects (override target based on conditions) ──────────
        // Must fire before ignoreShield / damage calc so the final target is used.
        if (trait.tags.contains('target_aquatic_if_low_hp') &&
            actor.hp <= actor.maxHp ~/ 2) {
          final alt = _preferredTarget(_aliveCandidates(enemyTeam)
              .where((p) => p.creatureClass == CreatureClass.aquatic)
              .toList());
          if (alt != null) target = alt;
        }
        if (trait.tags.contains('target_bug_if_low_hp') &&
            actor.hp <= actor.maxHp ~/ 2) {
          final alt = _preferredTarget(_aliveCandidates(enemyTeam)
              .where((p) => p.creatureClass == CreatureClass.bug)
              .toList());
          if (alt != null) target = alt;
        }
        if (trait.tags.contains('target_injured_if_low_hp') &&
            actor.hp <= actor.maxHp ~/ 2) {
          final alt = _lowestHp(enemyTeam);
          if (alt != null) target = alt;
        }
        // Turnip Rocket: redirect to a Bird enemy when in a 2+ card combo.
        if (trait.tags.contains('target_bird_on_combo') && comboIndex >= 1) {
          final alt = _preferredTarget(_aliveCandidates(enemyTeam)
              .where((p) => p.creatureClass == CreatureClass.bird)
              .toList());
          if (alt != null) target = alt;
        }

        final ignoreShield = effect.target == 'enemy' && target.isAsleep;
        final ignoreLastStand = trait.tags.contains('prevent_last_stand');
        final hitCount = trait.tags.contains('multi_hit_3') ? 3 : 1;
        // Declare shieldBefore and targetTrait here so damageBoost can reference them.
        final targetTrait = traitsByPetId[target.id];
        final shieldBefore = target.shield;
        final net = _computeDamage(actor, target, effect.value, trait,
            comboIndex: comboIndex);
        // ── Crit determination ───────────────────────────────────────────
        // Tags can force a crit; otherwise roll probabilistically.
        final bool isCrit;
        if (trait.tags.contains('crit_if_first') && comboIndex == 0) {
          isCrit = true; // Branch Charge: guaranteed crit when acting first
        } else if (trait.tags.contains('crit_on_combo_3') && comboIndex >= 2) {
          isCrit = true; // Single Combat: guaranteed crit on 3rd+ combo card
        } else {
          isCrit = _rollCrit(actor, target);
        }
        final critMultiplier = trait.tags.contains('double_crit_damage') ? 3 : 2;

        // ── Damage multipliers ───────────────────────────────────────────
        // Multiple multipliers may match; we take the highest (they don't
        // stack additively — each is a standalone condition bonus).
        // Add new bonuses here following the same pattern.
        double damageBoost = 1.0;

        // Allergic Reaction / Blackmail II: +30% vs debuffed target
        if (trait.tags.contains('bonus_damage_if_debuffed') &&
            target.debuffs.isNotEmpty)
          damageBoost = math.max(damageBoost, 1.3);

        // Bug Splat: +50% vs Bug class
        if (trait.tags.contains('bonus_damage_vs_bug') &&
            target.creatureClass == CreatureClass.bug)
          damageBoost = math.max(damageBoost, 1.5);

        // Angry Lam: +20% when actor HP ≤ 50%
        if (trait.tags.contains('bonus_if_low_hp') &&
            actor.hp <= actor.maxHp ~/ 2)
          damageBoost = math.max(damageBoost, 1.2);

        // Surprise Invasion: +30% when target is faster than actor
        if (trait.tags.contains('bonus_if_target_faster') &&
            target.effectiveSpeed > actor.effectiveSpeed)
          damageBoost = math.max(damageBoost, 1.3);

        // Dull Grip: +15% when target has shield
        if (trait.tags.contains('bonus_vs_shielded') && shieldBefore > 0)
          damageBoost = math.max(damageBoost, 1.15);

        // Shell Jab / Early Bird: +50% vs idle target (no shield)
        if (trait.tags.contains('bonus_vs_idle') && shieldBefore == 0)
          damageBoost = math.max(damageBoost, 1.5);

        // Revenge Arrow / similar: ×2 when actor is in Last Stand
        if (trait.tags.contains('double_damage_last_stand') && actor.isInLastStand)
          damageBoost = math.max(damageBoost, 2.0);

        // Prickly Trap: +20% when this Axie acts last in the round.
        if (trait.tags.contains('bonus_if_acts_last') && isLastActor)
          damageBoost = math.max(damageBoost, 1.2);

        var actual = 0;
        for (var hit = 0; hit < hitCount; hit++) {
          final dmg = _clamp(
            ((isCrit ? net * critMultiplier : net) * damageBoost).round(),
            kMaxSingleHitDamage,
          );
          final applied = target.takeDamage(
            dmg,
            ignoreShield: ignoreShield,
            ignoreLastStand: ignoreLastStand,
            forceLastStand: trait.tags.contains('force_last_stand_if_killed'),
          );
          actual += applied;
          log.damage(target.name, applied, target.hp, isCrit: isCrit);
          if (target.isAsleep) {
            target.removeDebuff(DebuffType.sleep);
          }
          if (target.isFainted) {
            log.fainted(target.name);
            break;
          }
        }
        final shieldBroke = shieldBefore > 0 && target.shield <= 0;
        if (shieldBroke && targetTrait != null) {
          _applyShieldBreakReactions(
            target: target,
            attacker: actor,
            trait: targetTrait,
          );
        }
        if (actual > 0 && targetTrait != null) {
          _applyOnHitReactions(
            target:     target,
            attacker:   actor,
            trait:      targetTrait,
            shieldBroke: shieldBroke,
          );
        }
        if (trait.tags.contains('draw_if_attack_first') && comboIndex == 0) {
          onDrawCard?.call(actor.id);
          log.drawCard(actor.name, 1);
        }
        if (trait.tags.contains('draw_if_attack_idle_target') &&
            shieldBefore == 0) {
          onDrawCard?.call(actor.id);
          log.drawCard(actor.name, 1);
        }
        if (trait.tags.contains('draw_if_attack_aqua_bird_dawn') &&
            (target.creatureClass == CreatureClass.aquatic ||
                target.creatureClass == CreatureClass.bird)) {
          onDrawCard?.call(actor.id);
          log.drawCard(actor.name, 1);
        }
        // Carrot Hammer: attacker gains 1 energy when this card breaks the target's shield.
        if (shieldBroke && trait.tags.contains('attacker_energy_on_shield_break')) {
          actor.receiveEnergy(1);
          log.energySteal(actor.name, actor.name, 1);
        }
        // October Treat (attacker side for damage cards like reptile-tail-08):
        // draw when the attack does NOT break the target's shield.
        if (trait.tags.contains('draw_if_shield_not_break') && !shieldBroke) {
          onDrawCard?.call(actor.id);
          log.drawCard(actor.name, 1);
        }
        if (trait.tags.contains('end_last_stand') && target.isInLastStand) {
          target.lastStandTicks = 0;
          target.hp = 0;
          target.isFainted = true;
          log.fainted(target.name);
        }
        // Lifesteal — heal attacker by however much HP the enemy actually lost.
        // Uses kMaxFlatHealing cap so drain cards can't trivialise sustain.
        if (effect.lifeSteal && actual > 0) {
          final heal = actual.clamp(0, kMaxFlatHealing);
          actor.receiveHealing(heal);
          log.heal(actor.name, heal, actor.hp);
        }
        if (trait.tags.contains('energy_on_crit') && isCrit) {
          actor.receiveEnergy(1);
        }
        // Fish Hook: apply Attack+ to self when hitting a Plant or Reptile.
        // 'Dusk' from the original Axie game does not exist in our class set.
        if (trait.tags.contains('self_atk_up_vs_plant_reptile') &&
            (target.creatureClass == CreatureClass.plant ||
             target.creatureClass == CreatureClass.reptile)) {
          actor.applyBuff(BuffType.attackUp, 20, 1);
          log.buff(actor.name, 'attackUp', 20, 1);
        }
        // Clam Slash: apply Attack+ to self when hitting a Beast or Bug.
        if (trait.tags.contains('self_atk_up_vs_beast_bug') &&
            (target.creatureClass == CreatureClass.beast ||
             target.creatureClass == CreatureClass.bug)) {
          actor.applyBuff(BuffType.attackUp, 20, 1);
          log.buff(actor.name, 'attackUp', 20, 1);
        }
        // Aqua Mirror: gain Speed+ when the hit lands.
        if (trait.tags.contains('self_speed_up_on_hit') && actual > 0) {
          actor.applyBuff(BuffType.speedUp, 20, 1);
          log.buff(actor.name, 'speedUp', 20, 1);
        }
        // target_aroma: mark the hit enemy with Aroma so allies focus it.
        if (trait.tags.contains('target_aroma') &&
            !target.isFainted &&
            actual > 0) {
          target.applyDebuff(DebuffType.aroma, 0, 2);
          log.debuff(target.name, 'aroma', 0, 2);
        }
        // Heart Break II: isolate target on the 3rd+ card in a combo so it
        // cannot use ally-targeting cards for the rest of this round.
        if (trait.tags.contains('isolated_on_combo_3') &&
            comboIndex >= 2 &&
            !target.isFainted) {
          target.applyDebuff(DebuffType.isolate, 0, 1);
          log.debuff(target.name, 'isolate', 0, 1);
        }
        // Blackmail: transfer all debuffs from actor to target.
        // Fires regardless of HP damage dealt (shield may absorb the hit, but
        // the debuffs still move). Does not fire if the target died from the hit.
        if (trait.tags.contains('transfer_debuffs') && !target.isFainted) {
          final toTransfer = List<StatusEffect>.from(actor.debuffs);
          if (toTransfer.isNotEmpty) {
            actor.debuffs.clear();
            log.debuff(actor.name, 'cleanse', 0, 0);
            for (final d in toTransfer) {
              target.applyDebuff(d.type, d.value, d.roundsRemaining);
              log.debuff(target.name, d.type.name, d.value, d.roundsRemaining);
            }
          }
        }
        if (target.isReflecting && actual > 0) {
          final reflect = (actual * (target.debuffs
                      .where((d) => d.type == DebuffType.reflect)
                      .firstOrNull
                      ?.value ?? 0) /
                  100.0)
              .round()
              .clamp(1, kMaxSingleHitDamage);
          if (reflect > 0 && !actor.isFainted) {
            final reflected = actor.takeDamage(reflect, ignoreShield: true);
            log.damage(actor.name, reflected, actor.hp);
            if (actor.isFainted) log.fainted(actor.name);
          }
        }
        // Energy steal/drain — runs even if the hit kills the target.
        // steal: enemy loses 1 energy, attacker's team gains 1 energy.
        // drain: enemy loses 1 energy, attacker gains nothing.
        if (effect.energySteal || effect.energyDrain) {
          final enemy = _firstAlive(enemyTeam) ?? target;
          final drained = enemy.drainEnergy(1);
          if (drained > 0) {
            if (effect.energySteal) {
              actor.receiveEnergy(drained);
              log.energySteal(actor.name, enemy.name, drained);
            } else {
              log.energyDrain(actor.name, enemy.name, drained);
            }
          }
        }
        // Tail Slap: gain 1 energy when used as a combo card (2nd+ card).
        if (trait.tags.contains('energy_gain_on_combo') && comboIndex >= 1) {
          actor.receiveEnergy(1);
          log.energySteal(actor.name, actor.name, 1);
        }
        // Night Steal / Vegetal Bite: steal 1 enemy energy when used in a combo.
        if (trait.tags.contains('energy_steal_on_combo') && comboIndex >= 1) {
          final enemy = _firstAlive(enemyTeam) ?? target;
          final drained = enemy.drainEnergy(1);
          if (drained > 0) {
            actor.receiveEnergy(drained);
            log.energySteal(actor.name, enemy.name, drained);
          }
        }
        // Scale Dart: gain 1 energy if the target has any active buff.
        if (trait.tags.contains('energy_gain_vs_buffed') &&
            target.buffs.isNotEmpty) {
          actor.receiveEnergy(1);
          log.energySteal(actor.name, actor.name, 1);
        }
        // Vegan Diet: lifesteal when target is Plant class.
        if (trait.tags.contains('lifesteal_vs_plant') &&
            target.creatureClass == CreatureClass.plant &&
            actual > 0) {
          final heal = actual.clamp(0, kMaxFlatHealing);
          actor.receiveHealing(heal);
          log.heal(actor.name, heal, actor.hp);
        }
        // Why So Serious: lifesteal when target is Aquatic class.
        if (trait.tags.contains('lifesteal_vs_aquatic') &&
            target.creatureClass == CreatureClass.aquatic &&
            actual > 0) {
          final heal = actual.clamp(0, kMaxFlatHealing);
          actor.receiveHealing(heal);
          log.heal(actor.name, heal, actor.hp);
        }
        // Woodman Power: gain shield equal to the damage dealt this hit.
        if (trait.tags.contains('shield_equal_to_damage') && actual > 0) {
          final shieldAmt = actual.clamp(0, kMaxShield);
          actor.applyShield(shieldAmt);
          log.shield(actor.name, shieldAmt, actor.shield);
        }
        // Death Mark: apply Lethal when target HP falls to ≤ 50% (bypasses Last Stand).
        if (trait.tags.contains('apply_lethal_if_low_hp') &&
            !target.isFainted &&
            target.hp <= target.maxHp ~/ 2) {
          target.applyDebuff(DebuffType.lethal, 0, 1);
          log.debuff(target.name, 'lethal', 0, 1);
        }
        // Grub Surprise: apply Fear when the target had a shield before this hit.
        if (trait.tags.contains('apply_fear_if_shielded') &&
            !target.isFainted &&
            shieldBefore > 0) {
          target.applyDebuff(DebuffType.fear, 0, 1);
          log.debuff(target.name, 'fear', 0, 1);
        }
        // Kotaro Bite: gain 1 energy when the target is faster than this Axie.
        if (trait.tags.contains('energy_if_target_faster') &&
            target.effectiveSpeed > actor.effectiveSpeed) {
          actor.receiveEnergy(1);
          log.energySteal(actor.name, actor.name, 1);
        }
        // Chomp: apply Stun when this Axie plays 3 or more cards this round.
        if (trait.tags.contains('stun_on_combo_3_total') &&
            actorComboSize >= 3 &&
            !target.isFainted) {
          target.applyDebuff(DebuffType.stunned, 0, 1);
          log.stun(target.name);
        }
        // All-out Shot: deal self-damage equal to 30% of own max HP (ignores shield).
        if (trait.tags.contains('self_damage_30pct_max_hp') && !actor.isFainted) {
          final selfDmg = (actor.maxHp * 0.3).round();
          actor.takeDamage(selfDmg, ignoreShield: true);
          log.damage(actor.name, selfDmg, actor.hp);
          if (actor.isFainted) log.fainted(actor.name);
        }

      // ── Healing ───────────────────────────────────────────────────────────
      case EffectType.heal:
        final targets =
            _resolveMultiple(effect.target, actor, actorTeam, enemyTeam);
        for (final t in targets) {
          if (t.isFainted) continue;
          final amount = effect.value.clamp(0, kMaxFlatHealing);
          t.receiveHealing(amount);
          log.heal(t.name, amount, t.hp);
        }

      // ── Shield ────────────────────────────────────────────────────────────
      case EffectType.shield:
        final target = _resolveTarget(
          effect.target,
          actor,
          actorTeam,
          enemyTeam,
        );
        if (target == null || target.isFainted) {
          log.noTarget();
          return;
        }
        final amount =
            _applySameClassShieldBonus(effect.value, actor, trait).clamp(0, kMaxShield);
        target.applyShield(amount);
        log.shield(target.name, amount, target.shield);

      // ── Buffs (single or multi-target) ────────────────────────────────────
      case EffectType.buff:
        final targets =
            _resolveMultiple(effect.target, actor, actorTeam, enemyTeam);
        for (final t in targets) {
          if (t.isFainted) continue;
          if (t.isHealBlocked && effect.buffType == BuffType.regen) continue;
          t.applyBuff(effect.buffType!, effect.value, effect.duration);
          log.buff(
              t.name, effect.buffType!.name, effect.value, effect.duration);
        }

      // ── Debuffs (single OR multi-target, e.g. Kapre Smoke hits all enemies)
      case EffectType.debuff:
        final targets =
            _resolveMultiple(effect.target, actor, actorTeam, enemyTeam);
        for (final t in targets) {
          if (t.isFainted) continue;
          t.applyDebuff(effect.debuffType!, effect.value, effect.duration);
          if (effect.debuffType == DebuffType.stunned) {
            log.stun(t.name);
          } else {
            log.debuff(
                t.name, effect.debuffType!.name, effect.value, effect.duration);
          }
          if (t.isFainted) log.fainted(t.name);
        }

      // ── Shield break — removes enemy shield, then applies shield to self ─────
      case EffectType.shieldBreak:
        final target =
            _resolveTarget(effect.target, actor, actorTeam, enemyTeam);
        if (target != null && !target.isFainted) {
          target.shield = 0;
          log.shieldBreak(target.name);
        }
        // Apply self-shield of effect.value
        if (effect.value > 0) {
          final amount = _applySameClassShieldBonus(effect.value, actor, trait)
              .clamp(0, kMaxShield);
          actor.applyShield(amount);
          log.shield(actor.name, amount, actor.shield);
        }
    }

    if (effect.type == EffectType.damage ||
        effect.type == EffectType.shieldBreak) {
      actor.consumeAttackModifiers();
    }

    // Per-action poison tick — all poisoned pets take 1 HP × stacks after every card.
    // Mirrors the Axie mechanic: "loses 2 HP for every action (Stackable)".
    // Our scale: 1 HP/stack/action keeps it proportional to our lower HP pools.
    _tickPoison([...actorTeam, ...enemyTeam], log);

    // Self-aroma — applies regardless of primary effect type so that cards like
    // Eggbomb (damage) and Sugar Rush (damage) both force-target themselves.
    if (trait.tags.contains('self_aroma')) {
      actor.applyDebuff(DebuffType.aroma, 0, 2); // lasts until end of next round
      log.debuff(actor.name, 'aroma', 0, 2);
    }

    // Acrobatic (beast-horn-12): gain Speed+ when used as the 2nd+ card in a combo.
    if (trait.tags.contains('self_speed_up_on_combo') && comboIndex >= 1) {
      actor.applyBuff(BuffType.speedUp, 20, 1);
      log.buff(actor.name, 'speedUp', 20, 1);
    }

    // Self-shield on attack — +10% bonus when card class matches attacker class.
    if (effect.selfShield > 0) {
      final amount = _applySameClassShieldBonus(effect.selfShield, actor, trait);
      final shieldAmt = amount.clamp(0, kMaxShield);
      actor.applyShield(shieldAmt);
      log.shield(actor.name, shieldAmt, actor.shield);
    }
  }

  // ── Damage formula ─────────────────────────────────────────────────────────
  //
  // Final damage = (base × classMult) + comboBonus
  //
  // Combo bonus (Axie Skill mechanic):
  //   Each card after the first in a round adds: (cardAttack × skill) / 500
  //   comboIndex 0 = first card (no bonus), 1 = second card, etc.
  //
  // Class advantage (+15%) and same-class card bonus (+10%) stack:
  //   Bird using a Bird card against Beast = ×1.25 damage

  int _computeDamage(
      Pet attacker, Pet defender, int traitBaseValue, Trait trait,
      {int comboIndex = 0}) {
    final comboBonus =
        comboIndex > 0 ? (traitBaseValue * attacker.skill ~/ 500) : 0;
    final raw = attacker.effectiveAttack + traitBaseValue + comboBonus;
    final base = (raw - defender.effectiveDefense).clamp(1, 999);
    return (base * _classMult(attacker, defender, trait)).round().clamp(1, 999);
  }

  // ── Critical hit ──────────────────────────────────────────────────────────
  //
  // Crit chance = effectiveMorale × 0.1% − defender.speed × 0.05%
  // Clamped 0–30%.  Crits deal ×2 damage (×3 with double_crit_damage tag).
  //
  // moraleDown debuff reduces the attacker's effective morale.
  // moraleUp   buff    increases the attacker's effective morale.

  bool _rollCrit(Pet attacker, Pet defender) {
    if (attacker.isJinxed || defender.isCritBlocked) return false;
    double moraleMult = 1.0;
    for (final d in attacker.debuffs) {
      if (d.type == DebuffType.moraleDown) moraleMult -= d.value / 100.0;
    }
    for (final b in attacker.buffs) {
      if (b.type == BuffType.moraleUp) moraleMult += b.value / 100.0;
    }
    final effectiveMorale = (attacker.morale * moraleMult.clamp(0.0, 3.0)).round();
    final chance = (effectiveMorale * 0.001 - defender.speed * 0.0005).clamp(0.0, 0.30);
    return chance > 0 && _rng.nextDouble() < chance;
  }

  double _classMult(Pet attacker, Pet defender, Trait trait) {
    double m = 1.0;
    if (attacker.creatureClass.isStrongAgainst(defender.creatureClass)) {
      m += 0.15;
    } else if (attacker.creatureClass.isWeakAgainst(defender.creatureClass)) {
      m -= 0.15;
    }
    if (trait.partClass != null && trait.partClass == attacker.creatureClass) {
      m += 0.10;
    }
    return m;
  }

  int _applySameClassShieldBonus(int baseShield, Pet actor, Trait trait) {
    if (baseShield <= 0) return 0;
    if (trait.partClass != null && trait.partClass == actor.creatureClass) {
      return (baseShield * 1.10).round();
    }
    return baseShield;
  }

  // ── Per-action poison ──────────────────────────────────────────────────────

  void _tickPoison(List<Pet> allPets, BattleLogger log) {
    for (final pet in allPets) {
      if (pet.isFainted) continue;
      final poison =
          pet.debuffs.where((d) => d.type == DebuffType.poisoned).firstOrNull;
      if (poison == null) continue;
      final dmg = poison.value; // 1 HP per stack per action
      pet.takeDamage(dmg, ignoreShield: true);
      log.poisonTick(pet.name, dmg, pet.hp);
      if (pet.isFainted) log.fainted(pet.name);
    }
  }

  int _clamp(int value, int cap) => value.clamp(1, cap);

  void _applyShieldBreakReactions({
    required Pet target,
    required Pet attacker,
    required Trait trait,
  }) {
    // Shipwreck: attack up when your shield is broken.
    if (trait.tags.contains('on_shield_break_attack_up')) {
      target.applyBuff(BuffType.attackUp, 20, 1);
      log.buff(target.name, 'attackUp', 20, 1);
    }
    // Aqua Stock / similar: restore 1 energy when your shield breaks.
    if (trait.tags.contains('on_shield_break_energy')) {
      target.receiveEnergy(1);
      log.energySteal(target.name, target.name, 1);
    }
    // Sticky Goo: stun the attacker unconditionally on shield break.
    if (trait.tags.contains('on_shield_break_stun_attacker') &&
        !attacker.isFainted) {
      attacker.applyDebuff(DebuffType.stunned, 0, 1);
      log.stun(attacker.name);
    }
    // Anesthetic Bait / Beast-back-10: counter-stun by attacker class on shield break.
    final hitByAquaBirdSB = attacker.creatureClass == CreatureClass.aquatic ||
                            attacker.creatureClass == CreatureClass.bird;
    final hitByPlantReptileSB = attacker.creatureClass == CreatureClass.plant ||
                                attacker.creatureClass == CreatureClass.reptile;
    if (trait.tags.contains('counter_stun_aqua_bird') &&
        hitByAquaBirdSB &&
        !attacker.isFainted) {
      attacker.applyDebuff(DebuffType.stunned, 0, 1);
      log.stun(attacker.name);
    }
    if (trait.tags.contains('counter_stun_plant_reptile') &&
        hitByPlantReptileSB &&
        !attacker.isFainted) {
      attacker.applyDebuff(DebuffType.stunned, 0, 1);
      log.stun(attacker.name);
    }
    // Ivory Chop: draw a card when your shield is broken.
    if (trait.tags.contains('draw_if_shield_break')) {
      onDrawCard?.call(target.id);
      log.drawCard(target.name, 1);
    }
  }

  void _applyOnHitReactions({
    required Pet target,
    required Pet attacker,
    required Trait trait,
    bool shieldBroke = false,
  }) {
    final hitByAquatic      = attacker.creatureClass == CreatureClass.aquatic;
    final hitByBird         = attacker.creatureClass == CreatureClass.bird;
    final hitByBeast        = attacker.creatureClass == CreatureClass.beast;
    final hitByBug          = attacker.creatureClass == CreatureClass.bug;
    final hitByPlantReptile = attacker.creatureClass == CreatureClass.plant ||
                              attacker.creatureClass == CreatureClass.reptile;
    final hitByAquaBird     = hitByAquatic || hitByBird;
    const hitByMech         = false;

    // Aqua Stock: gain 1 energy when hit by an Aquatic attacker.
    if (trait.tags.contains('on_hit_energy_vs_aquatic') && hitByAquatic) {
      target.receiveEnergy(1);
      log.energySteal(target.name, attacker.name, 1);
    }

    // Cattail Slap: draw a card when hit by Beast, Bug, or Mech.
    if (trait.tags.contains('draw_if_hit_by_beast_bug_mech') &&
        (hitByBeast || hitByBug || hitByMech)) {
      onDrawCard?.call(target.id);
      log.drawCard(target.name, 1);
    }

    // October Treat: draw a card when hit and shield was NOT broken.
    if (trait.tags.contains('draw_if_hit_shield_held') && !shieldBroke) {
      onDrawCard?.call(target.id);
      log.drawCard(target.name, 1);
    }

    // Anesthetic Bait / Beast-back-10: counter-stun attacker by class on ANY hit.
    // (These tags also appear in shield-break reactions but apply here for hits
    //  that don't break the shield.)
    if (trait.tags.contains('counter_stun_aqua_bird') &&
        hitByAquaBird &&
        !attacker.isFainted &&
        !shieldBroke) { // shield-break path already handles this case
      attacker.applyDebuff(DebuffType.stunned, 0, 1);
      log.stun(attacker.name);
    }
    if (trait.tags.contains('counter_stun_plant_reptile') &&
        hitByPlantReptile &&
        !attacker.isFainted &&
        !shieldBroke) {
      attacker.applyDebuff(DebuffType.stunned, 0, 1);
      log.stun(attacker.name);
    }

    // Reptile-back-10 (Ivory Stab / Shield-on-hit): gain a small shield when struck.
    if (trait.tags.contains('shield_when_hit')) {
      target.applyShield(20);
      log.shield(target.name, 20, target.shield);
    }

    // Headshot / Numbing Lecretion / Leek Leak: disable attacker's next card.
    if (trait.tags.contains('disable_horn_next') ||
        trait.tags.contains('disable_ability') ||
        trait.tags.contains('disable_melee_next') ||
        trait.tags.contains('disable_mouth_next')) {
      if (!attacker.isFainted) {
        attacker.applyDebuff(DebuffType.disabled, 0, 1);
        log.debuff(attacker.name, 'disabled', 0, 1);
      }
    }

    // Tiny Catapult / Bug-back-08 (Sticky Goo reflect): apply reflect status.
    if (trait.tags.contains('reflect_ranged') ||
        trait.tags.contains('reflect_melee')) {
      target.applyDebuff(DebuffType.reflect, 40, 1);
      log.debuff(target.name, 'reflect', 40, 1);
    }
  }

  // ── Target resolution ──────────────────────────────────────────────────────
  //
  // _resolveTarget   → returns a single Pet or null
  // _resolveMultiple → returns a list (may be length 1 for single-target specs)
  //
  // All multi-effect types (heal, buff, debuff) go through _resolveMultiple
  // so that specs like 'all_allies' work without special-casing at the call site.

  // ── Formation targeting ────────────────────────────────────────────────────
  //
  // Team lists are ordered [front(0), mid(1), back(2)].
  // Default 'enemy' attacks the front-most alive pet (_firstAlive = index 0).
  // 'lowest_hp_enemy' and 'all_enemies' naturally bypass formation.
  // 'back_enemy' pierces directly to the back row — skips the front.

  Pet? _resolveTarget(
    String spec,
    Pet actor,
    List<Pet> actorTeam,
    List<Pet> enemyTeam,
  ) {
    return switch (spec) {
      'enemy'          => _preferredTarget(_aliveCandidates(enemyTeam)),
      'lowest_hp_enemy'=> _preferredTarget(_lowestHpCandidates(enemyTeam)),
      'fastest_enemy'  => _preferredTarget(_fastestCandidates(enemyTeam)),
      'furthest_enemy' => _preferredTarget(_backRowCandidates(enemyTeam)),
      'back_enemy'     => _preferredTarget(_backRowCandidates(enemyTeam)),
      'self'           => actor,
      'lowest_hp_ally' => _lowestHp(actorTeam),
      // front_ally = first alive teammate (used by heal cards like Forest Spirit)
      'front_ally'     => _firstAlive(actorTeam),
      _                => _firstAlive(enemyTeam),
    };
  }

  List<Pet> _resolveMultiple(
    String spec,
    Pet actor,
    List<Pet> actorTeam,
    List<Pet> enemyTeam,
  ) {
    return switch (spec) {
      'all_enemies'    => enemyTeam.where((p) => !p.isFainted).toList(),
      'all_allies'     => actorTeam.where((p) => !p.isFainted).toList(),
      'lowest_hp_ally' => _singleOrEmpty(_lowestHp(actorTeam)),
      'lowest_hp_enemy'=> _singleOrEmpty(_lowestHp(enemyTeam)),
      'back_enemy'     => _singleOrEmpty(_backRow(enemyTeam)),
      'front_ally'     => _singleOrEmpty(_firstAlive(actorTeam)),
      _                => _singleOrEmpty(_resolveTarget(spec, actor, actorTeam, enemyTeam)),
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Pet? _firstAlive(List<Pet> team) {
    for (final p in team) {
      if (!p.isFainted) return p;
    }
    return null;
  }

  List<Pet> _aliveCandidates(List<Pet> team) =>
      team.where((p) => !p.isFainted).toList();

  List<Pet> _lowestHpCandidates(List<Pet> team) {
    final alive = _aliveCandidates(team);
    alive.sort((a, b) => a.hp.compareTo(b.hp));
    return alive;
  }

  List<Pet> _fastestCandidates(List<Pet> team) {
    final alive = _aliveCandidates(team);
    alive.sort((a, b) => b.effectiveSpeed.compareTo(a.effectiveSpeed));
    return alive;
  }

  List<Pet> _backRowCandidates(List<Pet> team) {
    final alive = _aliveCandidates(team);
    return alive.reversed.toList();
  }

  Pet? _lowestHp(List<Pet> team) {
    final alive = _lowestHpCandidates(team);
    return alive.isEmpty ? null : _preferredTarget(alive);
  }

  /// Back row = last alive pet in the team list (highest index still alive).
  /// Falls back to front if only one pet remains.
  Pet? _backRow(List<Pet> team) {
    final alive = _backRowCandidates(team);
    return alive.isEmpty ? null : _preferredTarget(alive);
  }

  List<Pet> _singleOrEmpty(Pet? pet) => pet != null ? [pet] : [];

  Pet? _preferredTarget(List<Pet> candidates) {
    if (candidates.isEmpty) return null;
    final aroma = candidates.where((p) => p.isAromatized && !p.isFainted).toList();
    if (aroma.isNotEmpty) return aroma.first;

    final visible = candidates.where((p) => !p.isStenched && !p.isFainted).toList();
    if (visible.isNotEmpty) return visible.first;

    return candidates.firstWhere((p) => !p.isFainted, orElse: () => candidates.first);
  }
}
