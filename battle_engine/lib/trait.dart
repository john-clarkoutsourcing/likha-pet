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

  const TraitEffect({
    required this.type,
    required this.value,
    this.buffType,
    this.debuffType,
    this.duration = 0,
    required this.target,
    this.selfShield = 0,
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
  static Trait withClassicCardStats({
    required Trait baseTrait,
    required String traitId,
    required String cardId,
  }) {
    final spec = kClassicCardSpecs[cardId];
    if (spec == null) {
      return Trait(
        id: traitId,
        name: baseTrait.name,
        type: baseTrait.type,
        part: baseTrait.part,
        energyCost: baseTrait.energyCost,
        cooldownMax: baseTrait.cooldownMax,
        effect: baseTrait.effect,
        description: baseTrait.description,
        rarity: baseTrait.rarity,
        comboTag: baseTrait.comboTag,
        tags: baseTrait.tags,
        partClass: baseTrait.partClass,
      );
    }

    final effect = _effectFromClassic(baseTrait.effect, spec);
    return Trait(
      id: traitId,
      name: spec.name,
      type: spec.attack > 0 ? TraitType.offensive : TraitType.support,
      part: baseTrait.part,
      energyCost: spec.energy,
      cooldownMax: baseTrait.cooldownMax,
      effect: effect,
      description: spec.description,
      rarity: baseTrait.rarity,
      comboTag: baseTrait.comboTag,
      tags: baseTrait.tags,
      partClass: baseTrait.partClass,
    );
  }

  static TraitEffect _effectFromClassic(
      TraitEffect base, ClassicCardSpec spec) {
    if (spec.attack > 0) {
      return TraitEffect(
        type: EffectType.damage,
        value: spec.attack,
        target: base.target,
        selfShield: spec.defense,
      );
    }
    if (spec.defense > 0) {
      return TraitEffect(
        type: EffectType.shield,
        value: spec.defense,
        target: 'self',
      );
    }
    return TraitEffect(
      type: EffectType.damage,
      value: 0,
      target: base.target,
    );
  }

  // ── Axie class traits ─────────────────────────────────────────────────────
  // Beast class: burst damage + morale-based. Cards deal high ATK, gain
  // shield as a side-effect of aggression. Mirrors Axie Classic Beast cards.

  static Trait get beastHorn => Trait(
        id: 'beast_horn',
        name: 'Ivory Stab', // beast-horn-04
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Gain 1 energy per critical strike dealt by your team this round.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 90,
            target: 'enemy',
            selfShield: 30),
      );

  static Trait get beastBack => Trait(
        id: 'beast_back',
        name: 'Heroic Reward', // beast-back-04
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 0,
        cooldownMax: 0,
        description:
            'Draw a card when attacking an Aquatic, Bird, or Dawn target.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 55, target: 'enemy'),
      );

  static Trait get beastTail => Trait(
        id: 'beast_tail',
        name: 'Night Steal', // beast-tail-04
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Steal 1 energy from your opponent when comboed with another card.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 90,
            target: 'enemy',
            selfShield: 20),
      );

  static Trait get beastMouth => Trait(
        id: 'beast_mouth',
        name: 'Piercing Sound', // beast-mouth-04
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Destroy 1 of your opponent\'s energy.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 85,
            target: 'enemy',
            selfShield: 30),
      );

  // ── Plant ─────────────────────────────────────────────────────────────────
  // Plant class: tank + sustain. Cards prioritise shield and healing.
  // "Serious" is a legendary 0-energy mouth card in Axie Classic.

  static Trait get plantHorn => Trait(
        id: 'plant_horn',
        name: 'Wooden Stab', // plant-horn-04
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 120% damage if this Axie\'s shield breaks.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 105,
            target: 'enemy',
            selfShield: 40),
      );

  static Trait get plantBack => Trait(
        id: 'plant_back',
        name: 'Shroom\'s Grace', // plant-back-04
        type: TraitType.support,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Heal this Axie for 120 HP.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.shield, value: 50, target: 'self'),
      );

  static Trait get plantTail => Trait(
        id: 'plant_tail',
        name: 'Cattail Slap', // plant-tail-04
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 0,
        cooldownMax: 0,
        description: 'Draw a card if struck by a Beast, Bug, or Mech card.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 10,
            target: 'enemy',
            selfShield: 30),
      );

  static Trait get plantMouth => Trait(
        id: 'plant_mouth',
        name: 'Drain Bite', // plant-mouth-04
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Heal this Axie by the damage this card inflicts.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 60,
            target: 'enemy',
            selfShield: 60),
      );

  // ── Aquatic ───────────────────────────────────────────────────────────────
  // Aquatic class: speed + utility. Fast attacks, evasion, and control.

  static Trait get aquaticHorn => Trait(
        id: 'aquatic_horn',
        name: 'Deep Sea Gore', // aquatic-horn-04
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Deal 30% of shield gained when the round started as bonus damage.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 80,
            target: 'enemy',
            selfShield: 50),
      );

  static Trait get aquaticBack => Trait(
        id: 'aquatic_back',
        name: 'Scale Dart', // aquatic-back-04
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Draw a card when attacking an idle target.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 100,
            target: 'back_enemy',
            selfShield: 35),
      );

  static Trait get aquaticTail => Trait(
        id: 'aquatic_tail',
        name: 'Tail Slap', // aquatic-tail-04
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 0,
        cooldownMax: 0,
        description: 'Gain 1 energy when comboed with another card.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 20, target: 'enemy'),
      );

  static Trait get aquaticMouth => Trait(
        id: 'aquatic_mouth',
        name: 'Swallow', // aquatic-mouth-04
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Heal this Axie by the damage inflicted with this card.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 90,
            target: 'enemy',
            selfShield: 25),
      );

  // ── Bird ──────────────────────────────────────────────────────────────────
  // Bird class: glass cannon + speed. Feather Lunge is the highest-damage
  // single card in the game. Peace Treaty disrupts enemy defences.

  static Trait get birdHorn => Trait(
        id: 'bird_horn',
        name: 'Cockadoodledoo', // bird-horn-04
        type: TraitType.support,
        part: TraitPart.horn,
        energyCost: 0,
        cooldownMax: 0,
        description: 'Apply attack+ to the whole team',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.buff,
            value: 20,
            buffType: BuffType.attackUp,
            duration: 1,
            target: 'self',
            selfShield: 20),
      );

  static Trait get birdBack => Trait(
        id: 'bird_back',
        name: 'Heart Break', // bird-back-04
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Apply Chill for 4 rounds.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 120,
            target: 'back_enemy',
            selfShield: 30),
      );

  static Trait get birdTail => Trait(
        id: 'bird_tail',
        name: 'Sunder Armor', // bird-tail-04
        type: TraitType.utility,
        part: TraitPart.tail,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Add 20% shield to this Axie for each debuff it possesses.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 105,
            target: 'enemy',
            selfShield: 30),
      );

  static Trait get birdMouth => Trait(
        id: 'bird_mouth',
        name: 'Peace Treaty', // bird-mouth-04
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Apply Attack- on target.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 120,
            target: 'enemy',
            selfShield: 25),
      );

  // ── Bug ───────────────────────────────────────────────────────────────────
  // Bug class: burst + debuffs. Mandible Strike is the highest-value 1-energy
  // attack. Numbing Lecretion applies stun to lock down enemies.

  static Trait get bugHorn => Trait(
        id: 'bug_horn',
        name: 'Bug Signal', // bug-horn-04
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Steal energy from your opponent when chained with another "Bug Signal" card.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 90,
            target: 'back_enemy',
            selfShield: 35),
      );

  static Trait get bugBack => Trait(
        id: 'bug_back',
        name: 'Barb Strike', // bug-back-04
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Apply 2 poison to target when played in a chain.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 90,
            target: 'back_enemy',
            selfShield: 40),
      );

  static Trait get bugTail => Trait(
        id: 'bug_tail',
        name: 'Twin Needle', // bug-tail-04
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 0,
        cooldownMax: 0,
        description: 'Attack twice when comboed with another card.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 35, target: 'back_enemy'),
      );

  static Trait get bugMouth => Trait(
        id: 'bug_mouth',
        name: 'Sunder Claw', // bug-mouth-04
        type: TraitType.utility,
        part: TraitPart.mouth,
        energyCost: 0,
        cooldownMax: 0,
        description:
            'Randomly discard 1 card from your enemy\'s hand when comboed with another card',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 20, target: 'enemy'),
      );

  // ── Reptile ───────────────────────────────────────────────────────────────
  // ── Beast variant skills ──────────────────────────────────────────────────

  static Trait get beastHorn2 => Trait(
        id: 'beast_horn_2',
        name: 'Merry Legion',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Bonus 20% shield when comboed.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 90,
            target: 'enemy',
            selfShield: 40),
      );

  static Trait get beastBack2 => Trait(
        id: 'beast_back_2',
        name: 'Nitro Leap',
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Attack first if any Axie is in Last Stand.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 120,
            target: 'enemy',
            selfShield: 35),
      );

  // ── Plant variant skills ──────────────────────────────────────────────────

  static Trait get plantHorn2 => Trait(
        id: 'plant_horn_2',
        name: 'Healing Aroma',
        type: TraitType.defensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Heal this Axie for120 HP.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 0,
          buffType: BuffType.defenseUp,
          duration: 1,
          target: 'self',
          selfShield: 50,
        ),
      );

  static Trait get plantBack2 => Trait(
        id: 'plant_back_2',
        name: 'Cleanse Scent',
        type: TraitType.utility,
        part: TraitPart.back,
        energyCost: 0,
        cooldownMax: 0,
        description:
            'Remove all debuffs from self. Can activate while stunned or feared.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 0,
          debuffType: DebuffType.poisoned,
          duration: 1,
          target: 'self',
          selfShield: 30,
        ),
      );

  // ── Aquatic variant skills ────────────────────────────────────────────────

  static Trait get aquaticHorn2 => Trait(
        id: 'aquatic_horn_2',
        name: 'Clam Slash',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Apply Attack+ to this Axie when attacking Beast, Bug, or Mech targets.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 115,
            target: 'enemy',
            selfShield: 35),
      );

  static Trait get aquaticBack2 => Trait(
        id: 'aquatic_back_2',
        name: 'Swift Escape',
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Apply Speed+ to this Axie for 2 rounds when attacked.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 100,
            target: 'back_enemy',
            selfShield: 35),
      );

  // ── Bird variant skills ───────────────────────────────────────────────────

  static Trait get birdHorn2 => Trait(
        id: 'bird_horn_2',
        name: 'Air Force One',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 120% damage when chained with another "Trump" card.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 125,
            target: 'back_enemy',
            selfShield: 30),
      );

  static Trait get birdBack2 => Trait(
        id: 'bird_back_2',
        name: 'Ill-omened',
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Apply Jinx for 4 rounds.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 120,
            target: 'back_enemy',
            selfShield: 30),
      );

  // ── Bug variant skills ────────────────────────────────────────────────────

  static Trait get bugHorn2 => Trait(
        id: 'bug_horn_2',
        name: 'Grub Surprise',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Apply Fear to shielded targets.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 120,
            target: 'enemy',
            selfShield: 20),
      );

  static Trait get bugBack2 => Trait(
        id: 'bug_back_2',
        name: 'Bug Noise',
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Apply Attack- to target.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 100,
            target: 'enemy',
            selfShield: 45),
      );

  // ── Reptile variant skills ────────────────────────────────────────────────

  static Trait get reptileHorn2 => Trait(
        id: 'reptile_horn_2',
        name: 'Surprise Invasion',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 130% damage if target is faster than this Axie.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 100,
            target: 'enemy',
            selfShield: 40),
      );

  static Trait get reptileBack2 => Trait(
        id: 'reptile_back_2',
        name: 'Vine Dagger',
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 0,
        cooldownMax: 0,
        description:
            'Double shield from this card when comboed with a plant card.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 25,
            target: 'enemy',
            selfShield: 30),
      );

  // ── Reptile class: tank + sustain ─────────────────────────────────────────

  static Trait get reptileHorn => Trait(
        id: 'reptile_horn',
        name: 'Scaly Lunge', // reptile-horn-04
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 120% damage when chained with another "lunge" card.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 120,
            target: 'enemy',
            selfShield: 30),
      );

  static Trait get reptileBack => Trait(
        id: 'reptile_back',
        name: 'Spike Throw', // reptile-back-04
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Target enemy with lowest shield when comboed with 2 or more cards.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 80,
            target: 'back_enemy',
            selfShield: 50),
      );

  static Trait get reptileTail => Trait(
        id: 'reptile_tail',
        name: 'Scale Dart', // reptile-tail-04
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Generate 1 energy when attacking a buffed target.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 75,
            target: 'back_enemy',
            selfShield: 60),
      );

  static Trait get reptileMouth => Trait(
        id: 'reptile_mouth',
        name: 'Kotaro bite', // reptile-mouth-04
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Gain 1 energy if target is faster than this Axie.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 85,
            target: 'enemy',
            selfShield: 30),
      );
}
