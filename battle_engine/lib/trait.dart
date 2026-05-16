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
  // ── Axie class traits ─────────────────────────────────────────────────────
  // Beast class: burst damage + morale-based. Cards deal high ATK, gain
  // shield as a side-effect of aggression. Mirrors Axie Classic Beast cards.

  static Trait get beastHorn => Trait(
        id: 'beast_horn',
        name: 'Dual Blade', // beast/dual blade.png
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Target any enemy. Apply Doubt and Grievous Wound.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 55, target: 'enemy'),
      );

  static Trait get beastBack => Trait(
        id: 'beast_back',
        name: 'Ronin', // beast/ronin.png
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Deal bonus damage per energy spent before this card this turn.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 45, target: 'enemy'),
      );

  static Trait get beastTail => Trait(
        id: 'beast_tail',
        name: 'Buba Brush', // beast/buba brush.png
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 2,
        cooldownMax: 0,
        description: 'Retain. Splash in Fury form.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 80, target: 'enemy'),
      );

  static Trait get beastMouth => Trait(
        id: 'beast_mouth',
        name: 'Axie Kiss', // beast/axie kiss.png
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Target the lowest HP enemy. Apply Death Mark.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 60, target: 'lowest_hp_enemy'),
      );

  // ── Plant ─────────────────────────────────────────────────────────────────
  // Plant class: tank + sustain. Cards prioritise shield and healing.
  // "Serious" is a legendary 0-energy mouth card in Axie Classic.

  static Trait get plantHorn => Trait(
        id: 'plant_horn',
        name: 'Cactus', // Cactus horn
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Initial: +15 damage and apply Taunt to self.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 60, target: 'enemy'),
      );

  static Trait get plantBack => Trait(
        id: 'plant_back',
        name: 'Pumpkin', // plant/pumpkin.png
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Secret: target ally. Next time attacked, draw 1 card (Bulwark style effect).',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.shield, value: 70, target: 'self'),
      );

  static Trait get plantTail => Trait(
        id: 'plant_tail',
        name: 'Cattail', // plant/cattail.png
        type: TraitType.support,
        part: TraitPart.tail,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Skill: target ally and heal. Card text includes delayed Taunt.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.heal, value: 60, target: 'lowest_hp_ally'),
      );

  static Trait get plantMouth => Trait(
        id: 'plant_mouth',
        name: 'Serious', // Serious mouth — the iconic 0-energy card
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Initial: +30 damage and apply Sleep to self.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 70, target: 'enemy'),
      );

  // ── Aquatic ───────────────────────────────────────────────────────────────
  // Aquatic class: speed + utility. Fast attacks, evasion, and control.

  static Trait get aquaticHorn => Trait(
        id: 'aquatic_horn',
        name: 'Lam', // aquatic/lam.png
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Target the lowest HP enemy. Damage scales down by target missing HP.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 90, target: 'lowest_hp_enemy'),
      );

  static Trait get aquaticBack => Trait(
        id: 'aquatic_back',
        name: 'Sponge', // aquatic/sponge.png
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 2,
        cooldownMax: 0,
        description:
            'Retain skill: shield allies and apply Bulwark-style protection.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.shield, value: 30, target: 'all_allies'),
      );

  static Trait get aquaticTail => Trait(
        id: 'aquatic_tail',
        name: 'Koi', // aquatic/koi.png
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 2,
        cooldownMax: 0,
        description:
            'Ambush. Consume Bubble for splash scaling (approximated as high single-target damage).',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 145, target: 'enemy'),
      );

  static Trait get aquaticMouth => Trait(
        id: 'aquatic_mouth',
        name: 'Catfish', // aquatic/catfish.png
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Attack all enemies and generate Bubble for allies.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.aoe, value: 25, target: 'all_enemies'),
      );

  // ── Bird ──────────────────────────────────────────────────────────────────
  // Bird class: glass cannon + speed. Feather Lunge is the highest-damage
  // single card in the game. Peace Treaty disrupts enemy defences.

  static Trait get birdHorn => Trait(
        id: 'bird_horn',
        name: 'Eggshell', // Eggshell horn — blocks crits
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 3 hits and gain Eggshell stacks (approximated).',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 25, target: 'enemy'),
      );

  static Trait get birdBack => Trait(
        id: 'bird_back',
        name: 'Feather Spear', // bird/feather spear.png
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 2 hits and gain Feather synergy (approximated).',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 30, target: 'enemy'),
      );

  static Trait get birdTail => Trait(
        id: 'bird_tail',
        name: 'Pigeon Post', // Pigeon Post tail — draw a card in Axie
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Deal 55 damage to the front enemy. Card text adds 1 Blackmail to opponent hand.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 55, target: 'enemy'),
      );

  static Trait get birdMouth => Trait(
        id: 'bird_mouth',
        name: 'Doubletalk', // bird/doubletalk.png
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Random 2-hit attack and adds Jinx based on unique enemies hit.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 25, target: 'enemy'),
      );

  // ── Bug ───────────────────────────────────────────────────────────────────
  // Bug class: burst + debuffs. Mandible Strike is the highest-value 1-energy
  // attack. Numbing Lecretion applies stun to lock down enemies.

  static Trait get bugHorn => Trait(
        id: 'bug_horn',
        name: 'Pincer', // bug/pincer.png
        type: TraitType.defensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Secret: shield allies and punish Keep usage (approximated as defensive shield).',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.shield, value: 35, target: 'all_allies'),
      );

  static Trait get bugBack => Trait(
        id: 'bug_back',
        name: 'Lagging', // bug/lagging.png
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Secret: target ally with Bulwark-style protection against Skill/Secret cards.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.shield, value: 70, target: 'self'),
      );

  static Trait get bugTail => Trait(
        id: 'bug_tail',
        name: 'Twin Tail', // bug/twin tail.png
        type: TraitType.defensive,
        part: TraitPart.tail,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Secret: target ally and trigger enemy hand disruption when attacked.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.shield, value: 65, target: 'self'),
      );

  static Trait get bugMouth => Trait(
        id: 'bug_mouth',
        name: 'Square Teeth', // bug/square teeth.png
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 0,
        cooldownMax: 0,
        description:
            'Consume shield for bonus damage (approximated as low-cost strike).',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 10, target: 'enemy'),
      );

  // ── Reptile ───────────────────────────────────────────────────────────────
  // ── Beast variant skills ──────────────────────────────────────────────────

  static Trait get beastHorn2 => Trait(
        id: 'beast_horn_2',
        name: 'Ivory Stab',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 50 damage and raise own ATK by 20% for 1 round.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 20,
          buffType: BuffType.attackUp,
          duration: 1,
          target: 'self',
          selfShield: 15,
        ),
      );

  static Trait get beastBack2 => Trait(
        id: 'beast_back_2',
        name: 'Ronin',
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 55 damage. Bonus damage when comboed.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 55,
            target: 'enemy',
            selfShield: 20),
      );

  // ── Plant variant skills ──────────────────────────────────────────────────

  static Trait get plantHorn2 => Trait(
        id: 'plant_horn_2',
        name: 'Wall of Plant',
        type: TraitType.defensive,
        part: TraitPart.horn,
        energyCost: 2,
        cooldownMax: 2,
        description: 'Raise DEF by 30% for 2 rounds and gain 50 shield.',
        rarity: SkillRarity.rare,
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 30,
          buffType: BuffType.defenseUp,
          duration: 2,
          target: 'self',
          selfShield: 50,
        ),
      );

  static Trait get plantBack2 => Trait(
        id: 'plant_back_2',
        name: 'Prickly Trap',
        type: TraitType.utility,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Apply 1 poison stack to front enemy + gain 30 shield. Punishes aggression.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 1,
          debuffType: DebuffType.poisoned,
          duration: 999,
          target: 'enemy',
          selfShield: 30,
        ),
      );

  // ── Aquatic variant skills ────────────────────────────────────────────────

  static Trait get aquaticHorn2 => Trait(
        id: 'aquatic_horn_2',
        name: 'Lam Glue',
        type: TraitType.utility,
        part: TraitPart.horn,
        energyCost: 2,
        cooldownMax: 2,
        description: 'Slow ALL enemies (Speed Down 20%/1r) and gain 15 shield.',
        rarity: SkillRarity.rare,
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 20,
          debuffType: DebuffType.speedDown,
          duration: 1,
          target: 'all_enemies',
          selfShield: 15,
        ),
      );

  static Trait get aquaticBack2 => Trait(
        id: 'aquatic_back_2',
        name: 'Goldfish',
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Speed Up 20% for 2 rounds and gain 35 shield.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 20,
          buffType: BuffType.speedUp,
          duration: 2,
          target: 'self',
          selfShield: 35,
        ),
      );

  // ── Bird variant skills ───────────────────────────────────────────────────

  static Trait get birdHorn2 => Trait(
        id: 'bird_horn_2',
        name: 'Kestrel',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Pierce the front row — deal 55 damage to the back-row enemy.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 55,
            target: 'back_enemy',
            selfShield: 15),
      );

  static Trait get birdBack2 => Trait(
        id: 'bird_back_2',
        name: 'Swallow Dive',
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 45 damage + Speed Up 20%/1r. Hit and retreat.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 20,
          buffType: BuffType.speedUp,
          duration: 1,
          target: 'self',
          selfShield: 15,
        ),
      );

  // ── Bug variant skills ────────────────────────────────────────────────────

  static Trait get bugHorn2 => Trait(
        id: 'bug_horn_2',
        name: 'Twin Needle',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 55 damage. Combos powerfully with other Bug cards.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 55,
            target: 'enemy',
            selfShield: 15),
      );

  static Trait get bugBack2 => Trait(
        id: 'bug_back_2',
        name: 'Lagging',
        type: TraitType.utility,
        part: TraitPart.back,
        energyCost: 2,
        cooldownMax: 2,
        description:
            'Reduce ATK by 20% on ALL enemies for 2 rounds and gain 25 shield.',
        rarity: SkillRarity.rare,
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 20,
          debuffType: DebuffType.attackDown,
          duration: 2,
          target: 'all_enemies',
          selfShield: 25,
        ),
      );

  // ── Reptile variant skills ────────────────────────────────────────────────

  static Trait get reptileHorn2 => Trait(
        id: 'reptile_horn_2',
        name: 'Risky Beast',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 60 damage + gain 10 shield. High risk, high reward.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage,
            value: 60,
            target: 'enemy',
            selfShield: 10),
      );

  static Trait get reptileBack2 => Trait(
        id: 'reptile_back_2',
        name: 'Bulwark',
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Raise DEF by 30% for 1 round and gain 45 shield.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 30,
          buffType: BuffType.defenseUp,
          duration: 1,
          target: 'self',
          selfShield: 45,
        ),
      );

  // ── Reptile class: tank + sustain ─────────────────────────────────────────

  static Trait get reptileHorn => Trait(
        id: 'reptile_horn',
        name: 'Cerastes', // reptile/cerastes.png
        type: TraitType.defensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Secret: target ally with Guard/Bulwark-style reactive poison+bleed defense.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.shield, value: 70, target: 'self'),
      );

  static Trait get reptileBack => Trait(
        id: 'reptile_back',
        name: 'Bone Sail', // Bone Sail back — iconic large shield
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Secret: target ally with Bulwark-style debuff reflection protection.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.shield, value: 70, target: 'self'),
      );

  static Trait get reptileTail => Trait(
        id: 'reptile_tail',
        name: 'Wall Gecko', // reptile/wall gecko.png
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 1,
        cooldownMax: 0,
        description:
            'Attack self and taunt; next turn heals based on HP lost (approximated as low ranged strike).',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 30, target: 'enemy'),
      );

  static Trait get reptileMouth => Trait(
        id: 'reptile_mouth',
        name: 'Toothless Bite', // reptile/toothless bite.png
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Ambush attack that applies Death Mark.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
            type: EffectType.damage, value: 60, target: 'back_enemy'),
      );
}
