import 'classic_card_specs.dart';

/// The six creature classes — each has distinct base stats and a preferred
/// playstyle. Use generic terms; never reference the original IP by name.
enum CreatureClass { beast, bug, bird, plant, aquatic, reptile }

extension CreatureClassStats on CreatureClass {
  String get displayName => switch (this) {
        CreatureClass.beast => 'Beast',
        CreatureClass.bug => 'Bug',
        CreatureClass.bird => 'Bird',
        CreatureClass.plant => 'Plant',
        CreatureClass.aquatic => 'Aquatic',
        CreatureClass.reptile => 'Reptile',
      };

  // ── Class advantage — 3-group triangle (official Axie Arena rules) ────────
  //
  // Three groups, each beats the next:
  //   Tank  (Plant, Reptile)  → +15% vs Speed  (Aquatic, Bird)
  //   Speed (Aquatic, Bird)   → +15% vs Burst  (Beast, Bug)
  //   Burst (Beast, Bug)      → +15% vs Tank   (Plant, Reptile)
  //
  // A class is weak (-15%) against the group that beats it.
  // Classes within the same group are neutral to each other.
  //
  // Reference: Axie Arena documentation — "Reptile, Plant deal 15% more
  // damage vs Aqua, Bird. Aqua, Bird deal 15% more vs Beast, Bug.
  // Beast, Bug deal 15% more vs Reptile, Plant."

  List<CreatureClass> get advantageGroup => switch (this) {
        CreatureClass.plant => [CreatureClass.aquatic, CreatureClass.bird],
        CreatureClass.reptile => [CreatureClass.aquatic, CreatureClass.bird],
        CreatureClass.aquatic => [CreatureClass.beast, CreatureClass.bug],
        CreatureClass.bird => [CreatureClass.beast, CreatureClass.bug],
        CreatureClass.beast => [CreatureClass.plant, CreatureClass.reptile],
        CreatureClass.bug => [CreatureClass.plant, CreatureClass.reptile],
      };

  bool isStrongAgainst(CreatureClass other) => advantageGroup.contains(other);
  bool isWeakAgainst(CreatureClass other) =>
      other.advantageGroup.contains(this);

  // ── Base body stats (body class alone, before any part contributions) ────
  //
  // Calibrated so that a pure-breed creature (4 parts of the same class)
  // produces the same HP and Speed totals as the original hardcoded values:
  //   plant 200/31  aquatic 160/39  beast 140/35
  //   reptile 165/35  bird 120/43  bug 155/31

  ({int hp, int speed, int skill, int morale}) get baseBodyStats =>
      switch (this) {
        CreatureClass.plant => (hp: 192, speed: 31, skill: 20, morale: 20),
        CreatureClass.aquatic => (hp: 156, speed: 31, skill: 25, morale: 17),
        CreatureClass.beast => (hp: 140, speed: 31, skill: 25, morale: 28),
        CreatureClass.reptile => (hp: 157, speed: 31, skill: 20, morale: 22),
        CreatureClass.bird => (hp: 120, speed: 35, skill: 23, morale: 20),
        CreatureClass.bug => (hp: 151, speed: 31, skill: 25, morale: 23),
      };

  // ── Part stat bonus per part (×4 for a pure-breed creature) ─────────────
  //
  // Matches the reference card game's per-part contribution table:
  //   Plant +3HP +1Morale  |  Aquatic +3Speed +1HP   |  Beast  +3Morale +1Speed
  //   Bird  +3Speed +1Morale | Bug +3Morale +1HP    |  Reptile +3HP +1Speed
  // (scaled ÷1.5 → ×2/×1 to fit our 4-part system)

  ({int hp, int speed, int skill, int morale}) get partStatBonus =>
      switch (this) {
        CreatureClass.plant => (hp: 2, speed: 0, skill: 0, morale: 1),
        CreatureClass.aquatic => (hp: 1, speed: 2, skill: 0, morale: 0),
        CreatureClass.beast => (hp: 0, speed: 1, skill: 0, morale: 2),
        CreatureClass.bird => (hp: 0, speed: 2, skill: 0, morale: 1),
        CreatureClass.bug => (hp: 1, speed: 0, skill: 0, morale: 2),
        CreatureClass.reptile => (hp: 2, speed: 1, skill: 0, morale: 0),
      };
}

enum TraitType { offensive, defensive, support, utility }

enum EffectType { damage, shield, heal, buff, debuff, aoe, shieldBreak }

enum BuffType { attackUp, defenseUp, speedUp, energized, regen }

enum DebuffType {
  attackDown,
  defenseDown,
  stunned,
  poisoned,
  burned,
  stench,
  speedDown
}

enum SkillRarity { common, rare, epic }

/// Character part that grants a trait.
///
/// body = the pet's core identity, while horn/back/mouth/tail map to
/// equip-like active skill parts.
enum TraitPart { body, horn, back, mouth, tail }

class TraitEffect {
  final EffectType type;
  final int value;
  final BuffType? buffType;
  final DebuffType? debuffType;
  final int duration; // rounds the buff/debuff lasts (0 = instant)
  final String target; // 'enemy', 'ally', 'self', 'all_enemies', 'all_allies'
  final int
      selfShield; // shield applied to the attacker immediately when this resolves (0 = none)
  final bool lifeSteal;   // heal attacker by actual HP damage dealt
  final bool energySteal; // remove 1 enemy energy AND give 1 to attacker's team
  final bool energyDrain; // remove 1 enemy energy only (no gain to attacker)

  const TraitEffect({
    required this.type,
    required this.value,
    this.buffType,
    this.debuffType,
    this.duration = 0,
    required this.target,
    this.selfShield = 0,
    this.lifeSteal = false,
    this.energySteal = false,
    this.energyDrain = false,
  });
}

class Trait {
  final String id;
  final String name;
  final TraitType type;
  final TraitPart part;
  final int energyCost;
  final int cooldownMax;
  final TraitEffect effect;
  final String description;
  final SkillRarity rarity;
  final String? comboTag;
  final List<String> tags;

  /// Which creature class this card/part belongs to.
  /// Used for the +10% same-class attack/shield bonus.
  final CreatureClass? partClass;

  int cooldownRemaining = 0;

  Trait({
    required this.id,
    required this.name,
    required this.type,
    this.part = TraitPart.body,
    required this.energyCost,
    required this.cooldownMax,
    required this.effect,
    required this.description,
    this.rarity = SkillRarity.common,
    this.comboTag,
    this.tags = const [],
    this.partClass,
  });

  bool get isReady => cooldownRemaining == 0;

  void triggerCooldown() {
    cooldownRemaining = cooldownMax;
  }

  void tickCooldown() {
    if (cooldownRemaining > 0) cooldownRemaining--;
  }

  Trait clone() {
    final t = Trait(
      id: id,
      name: name,
      type: type,
      part: part,
      energyCost: energyCost,
      cooldownMax: cooldownMax,
      effect: effect,
      description: description,
      rarity: rarity,
      comboTag: comboTag,
      tags: tags,
      partClass: partClass,
    );
    t.cooldownRemaining = cooldownRemaining;
    return t;
  }

  /// Returns a copy of this trait with [cls] set as the partClass.
  /// Called by PartDefinition.buildTrait() so each card knows its class.
  Trait withPartClass(CreatureClass cls) {
    final t = Trait(
      id: id,
      name: name,
      type: type,
      part: part,
      energyCost: energyCost,
      cooldownMax: cooldownMax,
      effect: effect,
      description: description,
      rarity: rarity,
      comboTag: comboTag,
      tags: tags,
      partClass: cls,
    );
    t.cooldownRemaining = cooldownRemaining;
    return t;
  }
}

// ── Pre-built trait library ──────────────────────────────────────────────────

class TraitLibrary {
  /// Builds a Trait whose numeric values (attack, defense, energy) come from
  /// [kClassicCardSpecs]. The base trait supplies everything semantic:
  /// effect type, target, buff/debuff kind, part, cooldown, rarity.
  static Trait withClassicCardStats({
    required Trait baseTrait,
    required String traitId,
    required String cardId,
  }) {
    final spec = kClassicCardSpecs[cardId];
    if (spec == null) return baseTrait;

    return Trait(
      id: traitId,
      name: spec.name,
      type: baseTrait.type,
      part: baseTrait.part,
      energyCost: spec.energy,
      cooldownMax: baseTrait.cooldownMax,
      effect: _effectFromClassic(baseTrait.effect, spec),
      description: spec.description,
      rarity: baseTrait.rarity,
      comboTag: baseTrait.comboTag,
      tags: baseTrait.tags,
      partClass: baseTrait.partClass,
    );
  }

  /// Fills numeric values from [spec] while preserving the semantic effect
  /// type defined in [base]:
  ///   damage  → value = spec.attack, selfShield = spec.defense
  ///   shield  → value = spec.defense
  ///   buff/debuff/etc → selfShield = spec.defense, all other fields preserved
  static TraitEffect _effectFromClassic(TraitEffect base, ClassicCardSpec spec) {
    if (base.type == EffectType.damage) {
      return TraitEffect(
        type: EffectType.damage,
        value: spec.attack,
        target: base.target,
        selfShield: spec.defense,
        lifeSteal: base.lifeSteal,
        energySteal: base.energySteal,
        energyDrain: base.energyDrain,
      );
    }
    if (base.type == EffectType.shield) {
      return TraitEffect(
        type: EffectType.shield,
        value: spec.defense,
        target: base.target,
      );
    }
    return TraitEffect(
      type: base.type,
      value: base.value,
      buffType: base.buffType,
      debuffType: base.debuffType,
      duration: base.duration,
      target: base.target,
      selfShield: spec.defense,
    );
  }

  /// Minimal skeleton trait — name/description/energyCost are placeholders
  /// that [withClassicCardStats] overwrites from the spec.
  static Trait _base({
    required String id,
    required TraitType type,
    required TraitPart part,
    required TraitEffect effect,
    int cooldownMax = 0,
    SkillRarity rarity = SkillRarity.common,
    String? comboTag,
    List<String> tags = const [],
    CreatureClass? partClass,
  }) =>
      Trait(
        id: id,
        name: '',
        type: type,
        part: part,
        energyCost: 0,
        cooldownMax: cooldownMax,
        description: '',
        rarity: rarity,
        comboTag: comboTag,
        tags: tags,
        partClass: partClass,
        effect: effect,
      );

  // ── Beast ─────────────────────────────────────────────────────────────────
  static Trait get beastHorn => withClassicCardStats(
        baseTrait: _base(id: 'beast_horn', type: TraitType.offensive, part: TraitPart.horn, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'beast_horn', cardId: 'beast-horn-04');

  static Trait get beastBack => withClassicCardStats(
        baseTrait: _base(id: 'beast_back', type: TraitType.offensive, part: TraitPart.back, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'beast_back', cardId: 'beast-back-04');

  static Trait get beastTail => withClassicCardStats(
        baseTrait: _base(id: 'beast_tail', type: TraitType.offensive, part: TraitPart.tail, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy', energySteal: true)),
        traitId: 'beast_tail', cardId: 'beast-tail-04');

  static Trait get beastMouth => withClassicCardStats(
        baseTrait: _base(id: 'beast_mouth', type: TraitType.offensive, part: TraitPart.mouth, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy', energyDrain: true)),
        traitId: 'beast_mouth', cardId: 'beast-mouth-04');

  // ── Plant ─────────────────────────────────────────────────────────────────
  static Trait get plantHorn => withClassicCardStats(
        baseTrait: _base(id: 'plant_horn', type: TraitType.offensive, part: TraitPart.horn, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'plant_horn', cardId: 'plant-horn-04');

  static Trait get plantBack => withClassicCardStats(
        baseTrait: _base(id: 'plant_back', type: TraitType.support, part: TraitPart.back, effect: const TraitEffect(type: EffectType.shield, value: 0, target: 'self')),
        traitId: 'plant_back', cardId: 'plant-back-04');

  static Trait get plantTail => withClassicCardStats(
        baseTrait: _base(id: 'plant_tail', type: TraitType.offensive, part: TraitPart.tail, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'plant_tail', cardId: 'plant-tail-04');

  static Trait get plantMouth => withClassicCardStats(
        baseTrait: _base(id: 'plant_mouth', type: TraitType.offensive, part: TraitPart.mouth, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy', lifeSteal: true)),
        traitId: 'plant_mouth', cardId: 'plant-mouth-04');

  // Vegetal Bite — steals 1 energy from enemy team when played
  static Trait get plantMouthVegetalBite => withClassicCardStats(
        baseTrait: _base(id: 'plant_mouth_vegetal_bite', type: TraitType.offensive, part: TraitPart.mouth, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy', energySteal: true)),
        traitId: 'plant_mouth_vegetal_bite', cardId: 'plant-mouth-02');

  // ── Aquatic ───────────────────────────────────────────────────────────────
  static Trait get aquaticHorn => withClassicCardStats(
        baseTrait: _base(id: 'aquatic_horn', type: TraitType.offensive, part: TraitPart.horn, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'aquatic_horn', cardId: 'aquatic-horn-04');

  static Trait get aquaticBack => withClassicCardStats(
        baseTrait: _base(id: 'aquatic_back', type: TraitType.offensive, part: TraitPart.back, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'back_enemy')),
        traitId: 'aquatic_back', cardId: 'aquatic-back-04');

  static Trait get aquaticTail => withClassicCardStats(
        baseTrait: _base(id: 'aquatic_tail', type: TraitType.offensive, part: TraitPart.tail, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'aquatic_tail', cardId: 'aquatic-tail-04');

  static Trait get aquaticMouth => withClassicCardStats(
        baseTrait: _base(id: 'aquatic_mouth', type: TraitType.offensive, part: TraitPart.mouth, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy', lifeSteal: true)),
        traitId: 'aquatic_mouth', cardId: 'aquatic-mouth-04');

  // ── Bird ──────────────────────────────────────────────────────────────────
  static Trait get birdHorn => withClassicCardStats(
        baseTrait: _base(id: 'bird_horn', type: TraitType.support, part: TraitPart.horn,
            effect: const TraitEffect(type: EffectType.buff, value: 20, buffType: BuffType.attackUp, duration: 1, target: 'self')),
        traitId: 'bird_horn', cardId: 'bird-horn-04');

  static Trait get birdBack => withClassicCardStats(
        baseTrait: _base(id: 'bird_back', type: TraitType.offensive, part: TraitPart.back, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'back_enemy')),
        traitId: 'bird_back', cardId: 'bird-back-04');

  static Trait get birdTail => withClassicCardStats(
        baseTrait: _base(id: 'bird_tail', type: TraitType.utility, part: TraitPart.tail, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'bird_tail', cardId: 'bird-tail-04');

  static Trait get birdMouth => withClassicCardStats(
        baseTrait: _base(id: 'bird_mouth', type: TraitType.offensive, part: TraitPart.mouth, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'bird_mouth', cardId: 'bird-mouth-04');

  // ── Bug ───────────────────────────────────────────────────────────────────
  static Trait get bugHorn => withClassicCardStats(
        baseTrait: _base(id: 'bug_horn', type: TraitType.offensive, part: TraitPart.horn, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'back_enemy', energySteal: true)),
        traitId: 'bug_horn', cardId: 'bug-horn-04');

  static Trait get bugBack => withClassicCardStats(
        baseTrait: _base(id: 'bug_back', type: TraitType.offensive, part: TraitPart.back, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'back_enemy')),
        traitId: 'bug_back', cardId: 'bug-back-04');

  static Trait get bugTail => withClassicCardStats(
        baseTrait: _base(id: 'bug_tail', type: TraitType.offensive, part: TraitPart.tail, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'back_enemy')),
        traitId: 'bug_tail', cardId: 'bug-tail-04');

  static Trait get bugMouth => withClassicCardStats(
        baseTrait: _base(id: 'bug_mouth', type: TraitType.utility, part: TraitPart.mouth, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'bug_mouth', cardId: 'bug-mouth-04');

  // Blood Taste — heals attacker by actual damage dealt (lifesteal)
  static Trait get bugMouthBloodTaste => withClassicCardStats(
        baseTrait: _base(id: 'bug_mouth_blood_taste', type: TraitType.offensive, part: TraitPart.mouth, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy', lifeSteal: true)),
        traitId: 'bug_mouth_blood_taste', cardId: 'bug-mouth-02');

  // ── Reptile ───────────────────────────────────────────────────────────────
  static Trait get reptileHorn => withClassicCardStats(
        baseTrait: _base(id: 'reptile_horn', type: TraitType.offensive, part: TraitPart.horn, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'reptile_horn', cardId: 'reptile-horn-04');

  static Trait get reptileBack => withClassicCardStats(
        baseTrait: _base(id: 'reptile_back', type: TraitType.offensive, part: TraitPart.back, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'back_enemy')),
        traitId: 'reptile_back', cardId: 'reptile-back-04');

  static Trait get reptileTail => withClassicCardStats(
        baseTrait: _base(id: 'reptile_tail', type: TraitType.offensive, part: TraitPart.tail, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'back_enemy')),
        traitId: 'reptile_tail', cardId: 'reptile-tail-04');

  static Trait get reptileMouth => withClassicCardStats(
        baseTrait: _base(id: 'reptile_mouth', type: TraitType.offensive, part: TraitPart.mouth, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'reptile_mouth', cardId: 'reptile-mouth-04');

  // ── Beast variant skills ──────────────────────────────────────────────────
  static Trait get beastHorn2 => withClassicCardStats(
        baseTrait: _base(id: 'beast_horn_2', type: TraitType.offensive, part: TraitPart.horn, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'beast_horn_2', cardId: 'beast-horn-06');

  static Trait get beastBack2 => withClassicCardStats(
        baseTrait: _base(id: 'beast_back_2', type: TraitType.offensive, part: TraitPart.back, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'beast_back_2', cardId: 'beast-back-06');

  // ── Plant variant skills ──────────────────────────────────────────────────
  static Trait get plantHorn2 => withClassicCardStats(
        baseTrait: _base(id: 'plant_horn_2', type: TraitType.defensive, part: TraitPart.horn,
            effect: const TraitEffect(type: EffectType.buff, value: 0, buffType: BuffType.defenseUp, duration: 1, target: 'self')),
        traitId: 'plant_horn_2', cardId: 'plant-horn-06');

  static Trait get plantBack2 => withClassicCardStats(
        baseTrait: _base(id: 'plant_back_2', type: TraitType.utility, part: TraitPart.back,
            effect: const TraitEffect(type: EffectType.debuff, value: 0, debuffType: DebuffType.poisoned, duration: 1, target: 'self')),
        traitId: 'plant_back_2', cardId: 'plant-back-06');

  // ── Aquatic variant skills ────────────────────────────────────────────────
  static Trait get aquaticHorn2 => withClassicCardStats(
        baseTrait: _base(id: 'aquatic_horn_2', type: TraitType.offensive, part: TraitPart.horn, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'aquatic_horn_2', cardId: 'aquatic-horn-06');

  static Trait get aquaticBack2 => withClassicCardStats(
        baseTrait: _base(id: 'aquatic_back_2', type: TraitType.offensive, part: TraitPart.back, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'back_enemy')),
        traitId: 'aquatic_back_2', cardId: 'aquatic-back-06');

  // ── Bird variant skills ───────────────────────────────────────────────────
  static Trait get birdHorn2 => withClassicCardStats(
        baseTrait: _base(id: 'bird_horn_2', type: TraitType.offensive, part: TraitPart.horn, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'back_enemy')),
        traitId: 'bird_horn_2', cardId: 'bird-horn-06');

  static Trait get birdBack2 => withClassicCardStats(
        baseTrait: _base(id: 'bird_back_2', type: TraitType.offensive, part: TraitPart.back, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'back_enemy')),
        traitId: 'bird_back_2', cardId: 'bird-back-06');

  // ── Bug variant skills ────────────────────────────────────────────────────
  static Trait get bugHorn2 => withClassicCardStats(
        baseTrait: _base(id: 'bug_horn_2', type: TraitType.offensive, part: TraitPart.horn, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'bug_horn_2', cardId: 'bug-horn-06');

  static Trait get bugBack2 => withClassicCardStats(
        baseTrait: _base(id: 'bug_back_2', type: TraitType.offensive, part: TraitPart.back, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'bug_back_2', cardId: 'bug-back-06');

  // ── Reptile variant skills ────────────────────────────────────────────────
  static Trait get reptileHorn2 => withClassicCardStats(
        baseTrait: _base(id: 'reptile_horn_2', type: TraitType.offensive, part: TraitPart.horn, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'reptile_horn_2', cardId: 'reptile-horn-06');

  static Trait get reptileBack2 => withClassicCardStats(
        baseTrait: _base(id: 'reptile_back_2', type: TraitType.offensive, part: TraitPart.back, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy')),
        traitId: 'reptile_back_2', cardId: 'reptile-back-06');
}
