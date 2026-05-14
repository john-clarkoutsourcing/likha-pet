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
  final int value;  // damage per round (poison) or stat modifier amount
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

  // Speed determines turn order — higher speed acts first in a round.
  // Default is kBaseSpeed (30). Give each pet a unique value for interesting
  // turn orders without any stat progression.
  final int speed;

  int hp;
  int shield; // flat damage absorption remaining
  bool isFainted;

  // ── Energy — shared pool (set via linkPool) or per-pet fallback ───────────
  EnergyPool? _pool;
  int _ownEnergy;

  /// Links this pet to a shared team energy pool.
  /// After linking, all canAfford / spendEnergy calls operate on the pool.
  void linkPool(EnergyPool pool) => _pool = pool;

  int get energy => _pool?.energy ?? _ownEnergy;

  final List<StatusEffect> debuffs = [];
  final List<BuffEffect> buffs = [];

  Pet({
    required this.id,
    required this.name,
    required this.traits,
    this.speed    = kBaseSpeed,
    this.hp       = kBaseHp,
    int energy    = kBaseEnergy,
    this.shield   = 0,
    this.isFainted = false,
  }) : _ownEnergy = energy;

  // ── Computed stat helpers (buffs stack additively) ─────────────────────────

  int get effectiveAttack {
    int bonus = 0;
    for (final b in buffs) {
      if (b.type == BuffType.attackUp) bonus += b.value;
    }
    int penalty = 0;
    for (final d in debuffs) {
      if (d.type == DebuffType.attackDown) penalty += d.value;
    }
    return kBaseAttack + bonus - penalty;
  }

  int get effectiveDefense {
    int bonus = 0;
    for (final b in buffs) {
      if (b.type == BuffType.defenseUp) bonus += b.value;
    }
    int penalty = 0;
    for (final d in debuffs) {
      if (d.type == DebuffType.defenseDown) penalty += d.value;
    }
    return kBaseDefense + bonus - penalty;
  }

  bool get isStunned  => debuffs.any((d) => d.type == DebuffType.stunned);
  bool get isPoisoned => debuffs.any((d) => d.type == DebuffType.poisoned);
  bool get isBurned   => debuffs.any((d) => d.type == DebuffType.burned);

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

  // ── Status processing (called at START of each round) ─────────────────────

  void processStatusEffects(BattleLogger log) {
    for (final d in List.of(debuffs)) {
      if (d.type == DebuffType.poisoned) {
        final dmg = d.value;
        takeDamage(dmg, ignoreShield: false);
        log.poisonTick(name, dmg, hp);
        d.roundsRemaining--;
      } else if (d.type == DebuffType.burned) {
        // Burn ignores shield and deals flat damage
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

    for (final t in traits) {
      t.tickCooldown();
    }
  }

  // ── Damage / healing application ──────────────────────────────────────────

  /// Applies [finalDamage] directly to HP (after shield absorption).
  /// [finalDamage] is expected to already have defense subtracted by the resolver.
  /// Returns actual HP lost.
  int takeDamage(int finalDamage, {bool ignoreShield = false}) {
    if (isFainted) return 0;

    int remaining = finalDamage.clamp(1, 999);

    if (!ignoreShield && shield > 0) {
      final absorbed = remaining.clamp(0, shield);
      shield -= absorbed;
      remaining -= absorbed;
    }

    final actual = remaining.clamp(0, 999);
    hp -= actual;
    if (hp <= 0) {
      hp = 0;
      isFainted = true;
    }
    return actual;
  }

  void receiveHealing(int amount) {
    if (isFainted) return;
    hp = (hp + amount).clamp(0, kBaseHp);
  }

  void applyShield(int amount) {
    shield = (shield + amount).clamp(0, 40); // hard cap: 40
  }

  void applyBuff(BuffType type, int value, int duration) {
    buffs.add(BuffEffect(type: type, value: value, roundsRemaining: duration));
  }

  void applyDebuff(DebuffType type, int value, int duration) {
    debuffs.add(StatusEffect(type: type, value: value, roundsRemaining: duration));
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
}
