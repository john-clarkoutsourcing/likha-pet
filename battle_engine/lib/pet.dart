import 'trait.dart';
import 'battle_logger.dart';
import 'energy_pool.dart';

// ── Fixed base stats (compile-time constants, never modified by items/levels) ─
const int kBaseHp = 150;
const int kBaseAttack = 30;
const int kBaseDefense = 30;
const int kBaseSpeed = 30;
const int kBaseEnergy = kTeamEnergyStart; // kept for backward compat
const int kEnergyRegen = kTeamEnergyRegen;
const int kEnergyCap = kTeamEnergyCap;

class StatusEffect {
  final DebuffType type;
  // Mutable so poison stacks can accumulate (1 stack = 4 HP damage/round).
  int value;
  int roundsRemaining;

  StatusEffect({
    required this.type,
    required this.value,
    required this.roundsRemaining,
  });
}

class BuffEffect {
  final BuffType type;
  final int value;
  int roundsRemaining;

  BuffEffect({
    required this.type,
    required this.value,
    required this.roundsRemaining,
  });
}

class Pet {
  final String id;
  final String name;
  final List<Trait> traits;

  final CreatureClass creatureClass;
  final int speed;   // turn order — higher acts first
  final int maxHp;
  final int morale;  // increases crit chance and combo resilience
  final int skill;   // adds bonus damage for multi-card combos

  /// Row on the 3×3 formation grid: 0 = Front, 1 = Mid, 2 = Back.
  /// Front is targeted first by default; Back is furthest.
  final int row;

  /// Lane (column) on the 3×3 formation grid: 0 = Upper, 1 = Center, 2 = Lower.
  /// Used for split-path targeting when enemies share the same distance.
  final int lane;

  int hp;
  int shield;
  bool isFainted;
  int lastStandTicks = 0;

  EnergyPool? _pool;
  int _ownEnergy;

  void linkPool(EnergyPool pool) => _pool = pool;
  int get energy => _pool?.energy ?? _ownEnergy;

  final List<StatusEffect> debuffs = [];
  final List<BuffEffect> buffs = [];

  Pet({
    required this.id,
    required this.name,
    required this.traits,
    this.creatureClass = CreatureClass.beast,
    this.speed         = kBaseSpeed,
    this.maxHp         = kBaseHp,
    this.morale        = 20,
    this.skill         = 20,
    this.row           = 0,
    this.lane          = 1,
    int? hp,
    int energy         = kBaseEnergy,
    this.shield        = 0,
    this.isFainted     = false,
  }) : hp = hp ?? maxHp,
       _ownEnergy = energy;

  // ── Computed stat helpers ──────────────────────────────────────────────────
  //
  // Buffs/debuffs store their value as a PERCENTAGE (e.g. 20 = 20%).
  // They stack additively: two Attack Up stacks = +40% total.
  // This matches the official Axie Arena documentation:
  //   "Attack Up — Increases the next Attack by 20% (Stackable)"
  //   "Speed Up  — Increases Speed by 20% for the next round (Stackable)"

  int get effectiveAttack {
    int upPct = 0, dnPct = 0;
    for (final b in buffs)   { if (b.type == BuffType.attackUp)      upPct += b.value; }
    for (final d in debuffs) { if (d.type == DebuffType.attackDown)  dnPct += d.value; }
    final net = upPct - dnPct;
    if (net == 0) return kBaseAttack;
    return (kBaseAttack * (1.0 + net / 100.0)).round().clamp(1, 999);
  }

  int get effectiveDefense {
    int upPct = 0, dnPct = 0;
    for (final b in buffs)   { if (b.type == BuffType.defenseUp)     upPct += b.value; }
    for (final d in debuffs) {
      if (d.type == DebuffType.defenseDown) dnPct += d.value;
      if (d.type == DebuffType.fragile)     dnPct += 25; // fragile = flat −25%
    }
    final net = upPct - dnPct;
    if (net == 0) return kBaseDefense;
    return (kBaseDefense * (1.0 + net / 100.0)).round().clamp(0, 999);
  }

  /// Speed used for turn ordering — +20%/stack with Speed Up, -20%/stack with Speed Down.
  int get effectiveSpeed {
    int upPct = 0, dnPct = 0;
    for (final b in buffs)   { if (b.type == BuffType.speedUp)      upPct += b.value; }
    for (final d in debuffs) { if (d.type == DebuffType.speedDown)  dnPct += d.value; }
    final net = upPct - dnPct;
    if (net == 0) return speed;
    return (speed * (1.0 + net / 100.0)).round().clamp(1, 999);
  }

  bool get isStunned       => debuffs.any((d) => d.type == DebuffType.stunned);
  bool get isLethalTarget  => debuffs.any((d) => d.type == DebuffType.lethal);
  bool get isFragile       => debuffs.any((d) => d.type == DebuffType.fragile);
  bool get isMoraleDebuffed=> debuffs.any((d) => d.type == DebuffType.moraleDown);
  bool get isMoraleBuffed  => buffs.any((b)  => b.type  == BuffType.moraleUp);
  bool get isPoisoned => debuffs.any((d) => d.type == DebuffType.poisoned);
  bool get isBurned   => debuffs.any((d) => d.type == DebuffType.burned);
  bool get isAsleep   => debuffs.any((d) => d.type == DebuffType.sleep);
  bool get isFeared   => debuffs.any((d) => d.type == DebuffType.fear);
  bool get isAromatized => debuffs.any((d) => d.type == DebuffType.aroma);
  bool get isChilled  => debuffs.any((d) => d.type == DebuffType.chill);
  bool get isJinxed   => debuffs.any((d) => d.type == DebuffType.jinx);
  bool get isHealBlocked => debuffs.any((d) => d.type == DebuffType.healBlocked);
  bool get isCritBlocked => debuffs.any((d) => d.type == DebuffType.critBlocked);
  bool get isDisabled => debuffs.any((d) => d.type == DebuffType.disabled);
  bool get isReflecting => debuffs.any((d) => d.type == DebuffType.reflect);
  bool get isStenched => debuffs.any((d) => d.type == DebuffType.stench);
  bool get isInLastStand => lastStandTicks > 0;
  bool get isIsolated => debuffs.any((d) => d.type == DebuffType.isolate);
  bool get canEnterLastStand => !isChilled;

  // ── Energy helpers ─────────────────────────────────────────────────────────

  /// Regens own energy only when NOT linked to a shared pool.
  /// Shared-pool regen is driven by [EnergyPool.regen()] in the engine.
  void regenEnergy() {
    if (_pool != null) return;
    _ownEnergy = (_ownEnergy + kEnergyRegen).clamp(0, kEnergyCap);
  }

  bool canAfford(int cost) => _pool?.canAfford(cost) ?? (_ownEnergy >= cost);

  void spendEnergy(int cost) {
    if (_pool != null) {
      _pool!.spend(cost);
    } else {
      _ownEnergy = (_ownEnergy - cost).clamp(0, kEnergyCap);
    }
  }

  /// Adds [amount] energy to this pet's pool (or own energy if solo).
  void receiveEnergy(int amount) {
    if (_pool != null) {
      _pool!.add(amount);
    } else {
      _ownEnergy = (_ownEnergy + amount).clamp(0, kEnergyCap);
    }
  }

  /// Removes up to [amount] energy from this pet's pool.
  /// Returns the amount actually removed (capped by available energy).
  int drainEnergy(int amount) {
    final available = energy;
    final actual = amount.clamp(0, available);
    spendEnergy(actual);
    return actual;
  }

  // ── Status processing (called at START of each round) ─────────────────────

  void processStatusEffects(BattleLogger log) {
    for (final d in List.of(debuffs)) {
      if (d.type == DebuffType.poisoned) {
        // Poison now ticks per ACTION (in ActionResolver), not per round.
        // Only keep the stacks alive — no damage here.
      } else if (d.type == DebuffType.burned) {
        final dmg = d.value;
        takeDamage(dmg, ignoreShield: true);
        log.burnTick(name, dmg, hp);
        d.roundsRemaining--;
      }
    }

    for (final b in List.of(buffs)) {
      if (b.type == BuffType.regen) {
        receiveHealing(b.value);
        log.regenTick(name, b.value, hp);
        b.roundsRemaining--;
      }
    }

    debuffs.removeWhere((d) => d.roundsRemaining <= 0);
    buffs.removeWhere((b) => b.roundsRemaining <= 0);

    if (lastStandTicks > 0) {
      lastStandTicks--;
      if (lastStandTicks <= 0) {
        lastStandTicks = 0;
        hp = 0;
        isFainted = true;
      }
    }

    for (final t in traits) {
      t.tickCooldown();
    }
  }

  /// Round-end expiry for non-DoT/non-regen statuses.
  /// Keeps buffs/debuffs active during action resolution for this full round.
  void tickRoundDurations() {
    for (final d in List.of(debuffs)) {
      if (d.type == DebuffType.poisoned ||
          d.type == DebuffType.burned ||
          d.type == DebuffType.stunned) {
        continue;
      }
      d.roundsRemaining--;
    }

    for (final b in List.of(buffs)) {
      if (b.type == BuffType.regen) continue;
      b.roundsRemaining--;
    }

    debuffs.removeWhere((d) => d.roundsRemaining <= 0);
    buffs.removeWhere((b) => b.roundsRemaining <= 0);
  }

  /// Classic-style: attack modifiers are consumed when the pet attacks.
  void consumeAttackModifiers() {
    buffs.removeWhere((b) => b.type == BuffType.attackUp);
    debuffs.removeWhere((d) => d.type == DebuffType.attackDown);
  }

  // ── Damage / healing application ──────────────────────────────────────────

  /// Applies [finalDamage] directly to HP (after shield absorption).
  /// [finalDamage] is expected to already have defense subtracted by the resolver.
  /// Returns actual HP lost.
  int takeDamage(int finalDamage,
      {bool ignoreShield = false,
      bool ignoreLastStand = false,
      bool forceLastStand = false}) {
    if (isFainted) return 0;

    // If already in Last Stand, consume ticks instead of taking normal damage
    if (lastStandTicks > 0 && !ignoreLastStand) {
      lastStandTicks = (lastStandTicks - 2).clamp(0, 999); // -2 ticks for incoming hit
      if (lastStandTicks <= 0) {
        hp = 0;
        isFainted = true;
      }
      return finalDamage.clamp(1, 999);
    }

    int remaining = finalDamage.clamp(1, 999);

    if (!ignoreShield && shield > 0) {
      final absorbed = remaining.clamp(0, shield);
      shield -= absorbed;
      remaining -= absorbed;
    }

    final actual = remaining.clamp(0, 999);
    hp -= actual;
    if (hp <= 0) {
      // Check lethal debuff (bypasses Last Stand)
      final hasLethal = debuffs.any((d) => d.type == DebuffType.lethal);
      
      // Try Last Stand trigger if not forced, not ignoring, and no lethal
      if (!ignoreLastStand && !hasLethal && !forceLastStand) {
        if (checkLastStandTrigger(finalDamage)) {
          hp = 1;
          lastStandTicks = _computeLastStandTicks();
          return actual;
        }
      } else if (forceLastStand && !hasLethal) {
        hp = 1;
        lastStandTicks = _computeLastStandTicks();
        return actual;
      }
      
      // No Last Stand: faint normally
      hp = 0;
      isFainted = true;
    }
    return actual;
  }

  void receiveHealing(int amount) {
    if (isFainted || isHealBlocked) return;
    hp = (hp + amount).clamp(0, maxHp);
  }

  void applyShield(int amount) {
    shield = (shield + amount).clamp(0, 999);
  }

  void applyBuff(BuffType type, int value, int duration) {
    buffs.add(BuffEffect(type: type, value: value, roundsRemaining: duration));
  }

  void applyDebuff(DebuffType type, int value, int duration) {
    if (type == DebuffType.poisoned) {
      // Stacking poison: add 1 stack (value = stacks, capped at 13).
      final existing = debuffs.where((d) => d.type == DebuffType.poisoned).firstOrNull;
      if (existing != null) {
        existing.value = (existing.value + 1).clamp(1, 13);
        return;
      }
      debuffs.add(StatusEffect(type: type, value: 1, roundsRemaining: 999));
      return;
    }
    if (type == DebuffType.stench) {
      final existing = debuffs.where((d) => d.type == DebuffType.stench).firstOrNull;
      if (existing != null) {
        existing.roundsRemaining =
            duration > existing.roundsRemaining ? duration : existing.roundsRemaining;
        return;
      }
    }
    debuffs.add(StatusEffect(type: type, value: value, roundsRemaining: duration));
  }

  void removeDebuff(DebuffType type) {
    debuffs.removeWhere((d) => d.type == type);
  }

  // ── Trait selection: return the best available trait, or null ─────────────

  Trait? selectTrait() {
    return traits.firstWhere(
      (t) => t.isReady && canAfford(t.energyCost),
      orElse: () => traits.first, // fallback: always return first (may be on CD)
    );
  }

  @override
  String toString() =>
      '$name [HP:$hp  E:$energy  Shld:$shield${isFainted ? " FAINTED" : ""}]';

  // Expose own energy for PetSnapshot serialization (pool energy read via getter)
  int get ownEnergy => _ownEnergy;

  int _computeLastStandTicks() {
    // Last Stand Ticks are determined by Morale brackets (Axie Infinity Classic):
    // 0–29 morale    → 1 tick  (very low morale Aquas/Birds)
    // 30–50 morale   → 2 ticks (standard Aquas, Birds, Plants, Reptiles)
    // 51–70 morale   → 3 ticks (pure Beasts, Mechs, Bugs)
    // 71+ morale     → 4 ticks (requires morale buffs like Self-Harm or Purify)
    return switch (morale) {
      < 30 => 1,
      < 51 => 2,
      < 71 => 3,
      _ => 4,
    };
  }

  /// Check if this pet would survive a fatal blow via Last Stand.
  /// Returns true if the morale modifier exceeds overkill damage.
  /// Overkill = damage - remainingHp
  /// Morale Modifier = (100 / remainingHp) * morale
  /// Triggers if: Morale Modifier > Overkill
  bool checkLastStandTrigger(int damageAmount) {
    if (!canEnterLastStand || hp <= 0) return false;
    
    final overkill = (damageAmount - hp).clamp(0, 9999);
    final moraleModifier = ((100.0 / hp) * morale).round();
    
    return moraleModifier > overkill;
  }
}
