import 'dart:math' as math;
import 'pet.dart';
import 'trait.dart';
import 'action.dart';
import 'battle_logger.dart';

// ── Hard balance caps ──────────────────────────────────────────────────────────
//
// These caps prevent any single action from one-shotting a pet or trivialising
// the healing loop. They are compile-time constants — never adjusted at runtime.
// No level scaling exists; every pet has identical base stats (kBaseHp = 150).
//
// Firebase note: the Cloud Function imports these same constants and applies
// them server-side during resolveTurn to ensure client and server produce
// identical results.

const int kMaxSingleHitDamage = 90; // Single-target damage ceiling
const int kMaxAoeDamagePerHit =
    30; // Per-target AoE ceiling (3 hits max = 90 total)
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
///   actual = clamp(net, 1, cap)   ← cap is kMaxSingleHitDamage or kMaxAoeDamagePerHit
///
/// Defense is subtracted HERE (not inside Pet.takeDamage) so that balance caps
/// are applied to the post-defense value the HP pool actually sees.
/// Pet.takeDamage only handles shield absorption.
///
/// Flutter integration:
///   ActionResolver writes to [BattleLogger]. The logger's [events] stream
///   drives animations in the BattleScreen widget tree.
class ActionResolver {
  final BattleLogger log;
  final math.Random _rng;

  ActionResolver(this.log, {required math.Random rng}) : _rng = rng;

  void resolve(Action action, List<Pet> actorTeam, List<Pet> enemyTeam,
      {int comboIndex = 0}) {
    final actor = action.actor;
    final trait = action.trait;
    final effect = trait.effect;

    if (actor.isFainted) return;
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

    log.action(actor.name, trait.name);

    switch (effect.type) {
      // ── Single-target damage ──────────────────────────────────────────────
      case EffectType.damage:
        final target = action.primaryTarget != null
            ? (action.primaryTarget!.isFainted ? null : action.primaryTarget)
            : _resolveTarget(
                effect.target,
                actor,
                actorTeam,
                enemyTeam,
              );
        if (target == null || target.isFainted) {
          log.noTarget();
          return;
        }
        final ignoreShield = effect.target == 'enemy' && target.isAsleep;
        final net = _computeDamage(actor, target, effect.value, trait,
            comboIndex: comboIndex);
        final isCrit = _rollCrit(actor, target);
        final dmg = _clamp(isCrit ? net * 2 : net, kMaxSingleHitDamage);
        final actual = target.takeDamage(dmg, ignoreShield: ignoreShield);
        if (target.isAsleep) {
          target.removeDebuff(DebuffType.sleep);
        }
        log.damage(target.name, actual, target.hp, isCrit: isCrit);
        if (target.isFainted) log.fainted(target.name);
        // Lifesteal — heal attacker by however much HP the enemy actually lost.
        // Uses kMaxFlatHealing cap so drain cards can't trivialise sustain.
        if (effect.lifeSteal && actual > 0) {
          final heal = actual.clamp(0, kMaxFlatHealing);
          actor.receiveHealing(heal);
          log.heal(actor.name, heal, actor.hp);
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

      // ── AoE damage ────────────────────────────────────────────────────────
      case EffectType.aoe:
        final targets =
            _resolveMultiple(effect.target, actor, actorTeam, enemyTeam);
        for (final t in targets) {
          if (t.isFainted) continue;
          final net = _computeDamage(actor, t, effect.value, trait,
              comboIndex: comboIndex);
          final isCrit = _rollCrit(actor, t);
          final dmg = _clamp(isCrit ? net * 2 : net, kMaxAoeDamagePerHit);
          final actual = t.takeDamage(dmg);
          log.damage(t.name, actual, t.hp, isAoe: true, isCrit: isCrit);
          if (t.isFainted) log.fainted(t.name);
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
        final amount = effect.value.clamp(0, kMaxShield);
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
          final amount = effect.value.clamp(0, kMaxShield);
          actor.applyShield(amount);
          log.shield(actor.name, amount, actor.shield);
        }
    }

    if (effect.type == EffectType.damage ||
        effect.type == EffectType.aoe ||
        effect.type == EffectType.shieldBreak) {
      actor.consumeAttackModifiers();
    }

    // Per-action poison tick — all poisoned pets take 1 HP × stacks after every card.
    // Mirrors the Axie mechanic: "loses 2 HP for every action (Stackable)".
    // Our scale: 1 HP/stack/action keeps it proportional to our lower HP pools.
    _tickPoison([...actorTeam, ...enemyTeam], log);

    // Self-shield on attack — +10% bonus when card class matches attacker class.
    if (effect.selfShield > 0) {
      int amount = effect.selfShield;
      if (trait.partClass != null && trait.partClass == actor.creatureClass) {
        amount = (amount * 1.10).round();
      }
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
  // Crit chance = attacker.morale × 0.1% − defender.speed × 0.05%
  // Clamped 0–30%.  Crits deal ×2 damage.
  // High-speed defenders are harder to crit — mimics Axie's speed/morale interplay.

  bool _rollCrit(Pet attacker, Pet defender) {
    if (attacker.isJinxed || defender.isCritBlocked) return false;
    final chance =
        (attacker.morale * 0.001 - defender.speed * 0.0005).clamp(0.0, 0.30);
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

  // ── Target resolution ──────────────────────────────────────────────────────
  //
  // _resolveTarget   → returns a single Pet or null
  // _resolveMultiple → returns a list (may be length 1 for single-target specs)
  //
  // All multi-effect types (heal, buff, debuff, aoe) go through _resolveMultiple
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
      'enemy' => _preferredTarget(_aliveCandidates(enemyTeam)), // hits front
      'lowest_hp_enemy' => _preferredTarget(_lowestHpCandidates(enemyTeam)),
      'back_enemy' => _preferredTarget(_backRowCandidates(enemyTeam)),
      'self' => actor,
      'lowest_hp_ally' => _lowestHp(actorTeam),
      _ => _firstAlive(enemyTeam),
    };
  }

  List<Pet> _resolveMultiple(
    String spec,
    Pet actor,
    List<Pet> actorTeam,
    List<Pet> enemyTeam,
  ) {
    return switch (spec) {
      'all_enemies' => enemyTeam.where((p) => !p.isFainted).toList(),
      'all_allies' => actorTeam.where((p) => !p.isFainted).toList(),
      'lowest_hp_ally' => _singleOrEmpty(_lowestHp(actorTeam)),
      'lowest_hp_enemy' => _singleOrEmpty(_lowestHp(enemyTeam)),
      'back_enemy' => _singleOrEmpty(_backRow(enemyTeam)),
      _ => _singleOrEmpty(_resolveTarget(spec, actor, actorTeam, enemyTeam)),
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
