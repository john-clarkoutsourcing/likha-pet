/// The six creature classes — each has distinct base stats and a preferred
/// playstyle. Use generic terms; never reference the original IP by name.
enum CreatureClass { beast, bug, bird, plant, aquatic, reptile }

extension CreatureClassStats on CreatureClass {
  String get displayName => switch (this) {
    CreatureClass.beast   => 'Beast',
    CreatureClass.bug     => 'Bug',
    CreatureClass.bird    => 'Bird',
    CreatureClass.plant   => 'Plant',
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
    CreatureClass.plant   => [CreatureClass.aquatic, CreatureClass.bird],
    CreatureClass.reptile => [CreatureClass.aquatic, CreatureClass.bird],
    CreatureClass.aquatic => [CreatureClass.beast,   CreatureClass.bug],
    CreatureClass.bird    => [CreatureClass.beast,   CreatureClass.bug],
    CreatureClass.beast   => [CreatureClass.plant,   CreatureClass.reptile],
    CreatureClass.bug     => [CreatureClass.plant,   CreatureClass.reptile],
  };

  bool isStrongAgainst(CreatureClass other) => advantageGroup.contains(other);
  bool isWeakAgainst(CreatureClass other)   => other.advantageGroup.contains(this);

  // ── Base body stats (body class alone, before any part contributions) ────
  //
  // Calibrated so that a pure-breed creature (4 parts of the same class)
  // produces the same HP and Speed totals as the original hardcoded values:
  //   plant 200/31  aquatic 160/39  beast 140/35
  //   reptile 165/35  bird 120/43  bug 155/31

  ({int hp, int speed, int skill, int morale}) get baseBodyStats => switch (this) {
    CreatureClass.plant   => (hp: 192, speed: 31, skill: 20, morale: 20),
    CreatureClass.aquatic => (hp: 156, speed: 31, skill: 25, morale: 17),
    CreatureClass.beast   => (hp: 140, speed: 31, skill: 25, morale: 28),
    CreatureClass.reptile => (hp: 157, speed: 31, skill: 20, morale: 22),
    CreatureClass.bird    => (hp: 120, speed: 35, skill: 23, morale: 20),
    CreatureClass.bug     => (hp: 151, speed: 31, skill: 25, morale: 23),
  };

  // ── Part stat bonus per part (×4 for a pure-breed creature) ─────────────
  //
  // Matches the reference card game's per-part contribution table:
  //   Plant +3HP +1Morale  |  Aquatic +3Speed +1HP   |  Beast  +3Morale +1Speed
  //   Bird  +3Speed +1Morale | Bug +3Morale +1HP    |  Reptile +3HP +1Speed
  // (scaled ÷1.5 → ×2/×1 to fit our 4-part system)

  ({int hp, int speed, int skill, int morale}) get partStatBonus => switch (this) {
    CreatureClass.plant   => (hp: 2, speed: 0, skill: 0, morale: 1),
    CreatureClass.aquatic => (hp: 1, speed: 2, skill: 0, morale: 0),
    CreatureClass.beast   => (hp: 0, speed: 1, skill: 0, morale: 2),
    CreatureClass.bird    => (hp: 0, speed: 2, skill: 0, morale: 1),
    CreatureClass.bug     => (hp: 1, speed: 0, skill: 0, morale: 2),
    CreatureClass.reptile => (hp: 2, speed: 1, skill: 0, morale: 0),
  };
}

enum TraitType { offensive, defensive, support, utility }

enum EffectType { damage, shield, heal, buff, debuff, aoe, shieldBreak }

enum BuffType { attackUp, defenseUp, speedUp, energized, regen }

enum DebuffType { attackDown, defenseDown, stunned, poisoned, burned, speedDown }

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
  final int selfShield; // shield applied to the attacker immediately when this resolves (0 = none)

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
      id: id, name: name, type: type, part: part,
      energyCost: energyCost, cooldownMax: cooldownMax,
      effect: effect, description: description,
      rarity: rarity, comboTag: comboTag, tags: tags,
      partClass: partClass,
    );
    t.cooldownRemaining = cooldownRemaining;
    return t;
  }

  /// Returns a copy of this trait with [cls] set as the partClass.
  /// Called by PartDefinition.buildTrait() so each card knows its class.
  Trait withPartClass(CreatureClass cls) {
    final t = Trait(
      id: id, name: name, type: type, part: part,
      energyCost: energyCost, cooldownMax: cooldownMax,
      effect: effect, description: description,
      rarity: rarity, comboTag: comboTag, tags: tags,
      partClass: cls,
    );
    t.cooldownRemaining = cooldownRemaining;
    return t;
  }
}

// ── Pre-built trait library ──────────────────────────────────────────────────

class TraitLibrary {
  static Trait get bakunawaSwallow => Trait(
        id: 'bakunawa_swallow',
        name: 'Bakunawa Swallow',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 2,
        cooldownMax: 0,
        description: 'Deal 50 damage to the lowest-HP enemy.',
        effect: const TraitEffect(
          type: EffectType.damage,
          value: 50,
          target: 'lowest_hp_enemy',
        ),
      );

  static Trait get lakanCounter => Trait(
        id: 'lakan_counter',
        name: 'Lakan Counter',
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Raise DEF by 20% for 2 rounds.',
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 20,
          buffType: BuffType.defenseUp,
          duration: 2,
          target: 'self',
        ),
      );

  static Trait get amihanVeil => Trait(
        id: 'amihan_veil',
        name: 'Amihan Veil',
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Raise DEF by 20 for 2 rounds and gain 30 shield.',
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 20,
          buffType: BuffType.defenseUp,
          duration: 2,
          target: 'self',
          selfShield: 30,
        ),
      );

  static Trait get sarimanokAura => Trait(
        id: 'sarimanok_aura',
        name: 'Sarimanok Aura',
        type: TraitType.support,
        part: TraitPart.tail,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Heal the lowest-HP ally for 35 HP.',
        effect: const TraitEffect(
          type: EffectType.heal,
          value: 35,
          target: 'lowest_hp_ally',
        ),
      );

  static Trait get tikbalangCharge => Trait(
        id: 'tikbalang_charge',
        name: 'Tikbalang Charge',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 30 damage to a single enemy.',
        effect: const TraitEffect(
          type: EffectType.damage,
          value: 30,
          target: 'enemy',
        ),
      );

  static Trait get manananggalDrain => Trait(
        id: 'manananggal_drain',
        name: 'Manananggal Drain',
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Apply 1 poison stack to front enemy. Stacks up to 13 (4 pure HP dmg/stack/round).',
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 1,
          debuffType: DebuffType.poisoned,
          duration: 999,
          target: 'enemy',
        ),
      );

  static Trait get anakngLupaSlam => Trait(
        id: 'anak_ng_lupa_slam',
        name: 'Anak ng Lupa Slam',
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 2,
        cooldownMax: 0,
        description: 'Deal 25 damage to ALL enemies.',
        effect: const TraitEffect(
          type: EffectType.aoe,
          value: 25,
          target: 'all_enemies',
        ),
      );

  static Trait get diwataBlessing => Trait(
        id: 'diwata_blessing',
        name: 'Diwata Blessing',
        type: TraitType.support,
        part: TraitPart.tail,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Heal all allies for 20 HP.',
        effect: const TraitEffect(
          type: EffectType.heal,
          value: 20,
          target: 'all_allies',
        ),
      );

  // ── New traits ─────────────────────────────────────────────────────────────

  /// The spirit of communal unity shields the whole team.
  static Trait get bayanihanShield => Trait(
        id: 'bayanihan_shield',
        name: 'Bayanihan Shield',
        type: TraitType.support,
        part: TraitPart.back,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Grant DEF +20% to ALL allies for 2 rounds.',
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 20,
          buffType: BuffType.defenseUp,
          duration: 2,
          target: 'all_allies',
        ),
      );

  /// The giant's cursed smoke blinds every enemy simultaneously.
  static Trait get kapreSmoke => Trait(
        id: 'kapre_smoke',
        name: 'Kapre Smoke',
        type: TraitType.utility,
        part: TraitPart.mouth,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Reduce ATK by 20% on ALL enemies for 2 rounds.',
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 20,
          debuffType: DebuffType.attackDown,
          duration: 2,
          target: 'all_enemies',
        ),
      );

  /// A blinding burst of fairy light paralyses one target.
  static Trait get enkantoFlash => Trait(
        id: 'enkanto_flash',
        name: 'Enkanto Flash',
        type: TraitType.utility,
        part: TraitPart.mouth,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Stun one enemy for 1 round (they skip their turn).',
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 0,
          debuffType: DebuffType.stunned,
          duration: 1,
          target: 'enemy',
        ),
      );

  /// The shapeshifter's lethal bite tears through one target.
  static Trait get aswangFang => Trait(
        id: 'aswang_fang',
        name: 'Aswang Fang',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 2,
        cooldownMax: 0,
        description: 'Deal 45 damage to a single enemy.',
        effect: const TraitEffect(
          type: EffectType.damage,
          value: 45,
          target: 'enemy',
        ),
      );

  /// The forest spirit's arrow pierces through the front line.
  static Trait get tikbalangSnipe => Trait(
        id: 'tikbalang_snipe',
        name: 'Tikbalang Snipe',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 2,
        cooldownMax: 0,
        description: 'Pierce the front line — deal 35 damage to the BACK row enemy.',
        effect: const TraitEffect(
          type: EffectType.damage,
          value: 35,
          target: 'back_enemy',
        ),
      );

  // ── Phase 2 skills ─────────────────────────────────────────────────────────

  /// Sigbin shadow slows + weakens an enemy simultaneously.
  static Trait get sigbinShadow => Trait(
        id: 'sigbin_shadow',
        name: 'Sigbin Shadow',
        type: TraitType.utility,
        part: TraitPart.mouth,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Speed Down -20% (2 rounds) on front enemy.',
        rarity: SkillRarity.rare,
        comboTag: 'spirit',
        tags: const ['speedDown', 'debuff', 'front'],
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 20,
          debuffType: DebuffType.speedDown,
          duration: 2,
          target: 'enemy',
        ),
      );

  /// Nuno sa Punso grants persistent HP recovery.
  static Trait get nunoRegen => Trait(
        id: 'nuno_regen',
        name: 'Nuno sa Punso',
        type: TraitType.support,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Gain REGEN 15 HP/round for 3 rounds (self).',
        rarity: SkillRarity.common,
        tags: const ['regen', 'dot', 'self'],
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 15,
          buffType: BuffType.regen,
          duration: 3,
          target: 'self',
        ),
      );

  /// Perlas ni Marikit strips buffs from all enemies while dealing AoE.
  static Trait get perlasStrike => Trait(
        id: 'perlas_strike',
        name: 'Perlas ni Marikit',
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Deal 20 AoE damage to all enemies + remove their shields.',
        rarity: SkillRarity.rare,
        tags: const ['aoe', 'shieldBreak'],
        effect: const TraitEffect(
          type: EffectType.aoe,
          value: 20,
          target: 'all_enemies',
        ),
      );

  /// Bathala's Wrath — divine punishment bonus vs poisoned targets.
  static Trait get bathalaWrath => Trait(
        id: 'bathala_wrath',
        name: "Bathala's Wrath",
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 2,
        cooldownMax: 4,
        description: 'Deal 60 damage to front enemy. +20 bonus if target is poisoned.',
        rarity: SkillRarity.epic,
        tags: const ['damage', 'synergy:poison', 'front'],
        effect: const TraitEffect(
          type: EffectType.damage,
          value: 60,
          target: 'enemy',
        ),
      );

  /// Agimat Ward steals the enemy's shield protection.
  static Trait get agimatWard => Trait(
        id: 'agimat_ward',
        name: 'Agimat Ward',
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Remove all shield from front enemy + apply SHIELD 30 to self.',
        rarity: SkillRarity.rare,
        tags: const ['shieldBreak', 'shield', 'self'],
        effect: const TraitEffect(
          type: EffectType.shieldBreak,
          value: 30,
          target: 'enemy',
        ),
      );

  /// Lambana Dance heals and cleanses the most wounded ally.
  static Trait get lambanaDance => Trait(
        id: 'lambana_dance',
        name: 'Lambana Dance',
        type: TraitType.support,
        part: TraitPart.tail,
        energyCost: 2,
        cooldownMax: 4,
        description: 'HEAL 25 to lowest HP ally and cleanse 1 debuff.',
        rarity: SkillRarity.rare,
        tags: const ['heal', 'cleanse', 'ally'],
        effect: const TraitEffect(
          type: EffectType.heal,
          value: 25,
          target: 'lowest_hp_ally',
        ),
      );

  /// Kulam Curse stacks two DoTs simultaneously.
  static Trait get kulamCurse => Trait(
        id: 'kulam_curse',
        name: 'Kulam Curse',
        type: TraitType.utility,
        part: TraitPart.mouth,
        energyCost: 2,
        cooldownMax: 4,
        description: 'Apply BURNED (5/round 3r) + POISON (8/round 2r) to front enemy.',
        rarity: SkillRarity.epic,
        tags: const ['burn', 'poison', 'multi-dot', 'front'],
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 8,
          debuffType: DebuffType.burned,
          duration: 3,
          target: 'enemy',
        ),
      );

  // ── Beast ─────────────────────────────────────────────────────────────────
  // Beast class: burst damage + morale-based. Cards deal high ATK, gain
  // shield as a side-effect of aggression. Mirrors Axie Classic Beast cards.

  static Trait get beastHorn => Trait(
        id: 'beast_horn',
        name: 'Nut Crack',           // Nut Cracker horn
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 55 damage to the front enemy. Devastating when comboed with another attack.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(type: EffectType.damage, value: 55, target: 'enemy', selfShield: 20),
      );

  static Trait get beastBack => Trait(
        id: 'beast_back',
        name: 'Rage',                // Rage back
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 15 damage + raise own ATK by 20% for 1 round. ATK bonus stacks each use.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff, value: 20,
          buffType: BuffType.attackUp, duration: 1, target: 'self',
          selfShield: 30,
        ),
      );

  static Trait get beastTail => Trait(
        id: 'beast_tail',
        name: 'Sinister Strike',     // Dual Blade tail
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 55 damage to the front enemy. Crits when combined with a Morale buff.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(type: EffectType.damage, value: 55, target: 'enemy', selfShield: 20),
      );

  static Trait get beastMouth => Trait(
        id: 'beast_mouth',
        name: 'Chomp',               // Chomps mouth
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 50 damage to the front enemy. Bonus damage when target is below half HP.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(type: EffectType.damage, value: 50, target: 'enemy', selfShield: 20),
      );

  // ── Plant ─────────────────────────────────────────────────────────────────
  // Plant class: tank + sustain. Cards prioritise shield and healing.
  // "Serious" is a legendary 0-energy mouth card in Axie Classic.

  static Trait get plantHorn => Trait(
        id: 'plant_horn',
        name: 'Cactus',              // Cactus horn
        type: TraitType.defensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Raise DEF by 20 for 1 round and gain 45 shield. Counter-posture: punishes attackers.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff, value: 20,
          buffType: BuffType.defenseUp, duration: 1, target: 'self',
          selfShield: 45,
        ),
      );

  static Trait get plantBack => Trait(
        id: 'plant_back',
        name: 'Sponge',              // Sponge back
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Raise DEF by 20% for 2 rounds and gain 35 shield. Absorbs damage for the team.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff, value: 20,
          buffType: BuffType.defenseUp, duration: 2, target: 'self',
          selfShield: 35,
        ),
      );

  static Trait get plantTail => Trait(
        id: 'plant_tail',
        name: 'Healing Herbs',       // Cattail / Carrot Hammer tail
        type: TraitType.support,
        part: TraitPart.tail,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Restore 40 HP to the lowest-HP ally. Plant sustain keeps the team alive.',
        rarity: SkillRarity.rare,
        effect: const TraitEffect(type: EffectType.heal, value: 40, target: 'lowest_hp_ally'),
      );

  static Trait get plantMouth => Trait(
        id: 'plant_mouth',
        name: 'Serious',             // Serious mouth — the iconic 0-energy card
        type: TraitType.defensive,
        part: TraitPart.mouth,
        energyCost: 0,               // FREE — no energy cost, playable every round
        cooldownMax: 0,
        description: 'FREE card (0 energy): instantly gain 40 shield. Can be played any round at no cost.',
        rarity: SkillRarity.rare,
        effect: const TraitEffect(
          type: EffectType.buff, value: 0,
          buffType: BuffType.defenseUp, duration: 0, target: 'self',
          selfShield: 40,
        ),
      );

  // ── Aquatic ───────────────────────────────────────────────────────────────
  // Aquatic class: speed + utility. Fast attacks, evasion, and control.

  static Trait get aquaticHorn => Trait(
        id: 'aquatic_horn',
        name: 'Angry Lam',           // Angry Lam horn
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Pierce the formation — deal 50 damage directly to the back-row enemy.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(type: EffectType.damage, value: 50, target: 'back_enemy', selfShield: 20),
      );

  static Trait get aquaticBack => Trait(
        id: 'aquatic_back',
        name: 'Shelter',             // Shelter back — Axie Classic's iconic DEF card
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Raise DEF by 20 for 1 round and gain 40 shield. Disables critical strikes this round.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff, value: 20,
          buffType: BuffType.defenseUp, duration: 1, target: 'self',
          selfShield: 40,
        ),
      );

  static Trait get aquaticTail => Trait(
        id: 'aquatic_tail',
        name: 'Swift Escape',        // Swift Escape tail
        type: TraitType.defensive,
        part: TraitPart.tail,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Gain Speed Up +20% for 1 round and 25 shield. Move faster to dodge or strike first.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff, value: 20,
          buffType: BuffType.speedUp, duration: 1, target: 'self',
          selfShield: 25,
        ),
      );

  static Trait get aquaticMouth => Trait(
        id: 'aquatic_mouth',
        name: 'Upstream Swim',       // Upstream Swim mouth
        type: TraitType.utility,
        part: TraitPart.mouth,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Stun the front enemy for 1 round (they skip their next action).',
        rarity: SkillRarity.rare,
        effect: const TraitEffect(
          type: EffectType.debuff, value: 0,
          debuffType: DebuffType.stunned, duration: 1, target: 'enemy',
        ),
      );

  // ── Bird ──────────────────────────────────────────────────────────────────
  // Bird class: glass cannon + speed. Feather Lunge is the highest-damage
  // single card in the game. Peace Treaty disrupts enemy defences.

  static Trait get birdHorn => Trait(
        id: 'bird_horn',
        name: 'Eggshell',            // Eggshell horn — blocks crits
        type: TraitType.defensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Raise ATK by 20% for 1 round and gain 40 shield. Next attack cannot be a critical hit against you.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff, value: 20,
          buffType: BuffType.attackUp, duration: 1, target: 'self',
          selfShield: 40,
        ),
      );

  static Trait get birdBack => Trait(
        id: 'bird_back',
        name: 'Feather Lunge',       // Feather Lunge back — highest ATK in game
        type: TraitType.offensive,
        part: TraitPart.back,
        energyCost: 2,
        cooldownMax: 0,
        description: 'Deal 65 damage to the front enemy — the most powerful single strike in the roster.',
        rarity: SkillRarity.rare,
        effect: const TraitEffect(type: EffectType.damage, value: 65, target: 'enemy', selfShield: 15),
      );

  static Trait get birdTail => Trait(
        id: 'bird_tail',
        name: 'Pigeon Post',         // Pigeon Post tail — draw a card in Axie
        type: TraitType.offensive,
        part: TraitPart.tail,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 50 damage to the front enemy. Scouts ahead — draws an extra card next round.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(type: EffectType.damage, value: 50, target: 'enemy', selfShield: 20),
      );

  static Trait get birdMouth => Trait(
        id: 'bird_mouth',
        name: 'Peace Treaty',        // Peace Treaty mouth — discard enemy card
        type: TraitType.defensive,
        part: TraitPart.mouth,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Shatter the enemy\'s shield and gain 25 shield. Disrupts the enemy\'s defensive line.',
        rarity: SkillRarity.rare,
        effect: const TraitEffect(type: EffectType.shieldBreak, value: 25, target: 'enemy'),
      );

  // ── Bug ───────────────────────────────────────────────────────────────────
  // Bug class: burst + debuffs. Mandible Strike is the highest-value 1-energy
  // attack. Numbing Lecretion applies stun to lock down enemies.

  static Trait get bugHorn => Trait(
        id: 'bug_horn',
        name: 'Mandible Strike',     // Mandible Strike horn — high single damage
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 60 damage to the front enemy — the highest-value 1-energy attack.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(type: EffectType.damage, value: 60, target: 'enemy', selfShield: 20),
      );

  static Trait get bugBack => Trait(
        id: 'bug_back',
        name: 'Sticky Goo',          // Sticky Goo back — slows enemy
        type: TraitType.utility,
        part: TraitPart.back,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Slow the front enemy (Speed Down) for 1 round and gain 25 shield.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.debuff, value: 0,
          debuffType: DebuffType.speedDown, duration: 1, target: 'enemy',
          selfShield: 25,
        ),
      );

  static Trait get bugTail => Trait(
        id: 'bug_tail',
        name: 'Venom Spit',          // Venom Spit tail — poison DoT
        type: TraitType.utility,
        part: TraitPart.tail,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Apply 1 poison stack (4 pure HP dmg/stack/round). Stacks up to 13.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.debuff, value: 1,
          debuffType: DebuffType.poisoned, duration: 999, target: 'enemy',
        ),
      );

  static Trait get bugMouth => Trait(
        id: 'bug_mouth',
        name: 'Numbing Lecretion',   // Numbing Lecretion mouth — stun
        type: TraitType.utility,
        part: TraitPart.mouth,
        energyCost: 2,
        cooldownMax: 2,
        description: 'Secrete paralysing venom — stun the front enemy for 1 round.',
        rarity: SkillRarity.rare,
        effect: const TraitEffect(
          type: EffectType.debuff, value: 0,
          debuffType: DebuffType.stunned, duration: 1, target: 'enemy',
          selfShield: 15,
        ),
      );

  // ── Reptile ───────────────────────────────────────────────────────────────
  // Reptile class: tank + sustain. Bone Sail (back) gives a huge 2-energy
  // shield. Tiny Catapult pierces the front row to hit the back.

  static Trait get reptileHorn => Trait(
        id: 'reptile_horn',
        name: 'Tiny Dino',           // Tiny Dino horn
        type: TraitType.offensive,
        part: TraitPart.horn,
        energyCost: 1,
        cooldownMax: 0,
        description: 'Deal 50 damage to the front enemy.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(type: EffectType.damage, value: 50, target: 'enemy', selfShield: 25),
      );

  static Trait get reptileBack => Trait(
        id: 'reptile_back',
        name: 'Bone Sail',           // Bone Sail back — iconic large shield
        type: TraitType.defensive,
        part: TraitPart.back,
        energyCost: 2,
        cooldownMax: 0,
        description: 'Raise DEF by 20 for 2 rounds and gain 40 shield — the strongest defensive card for Reptile.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(
          type: EffectType.buff, value: 20,
          buffType: BuffType.defenseUp, duration: 2, target: 'self',
          selfShield: 40,
        ),
      );

  static Trait get reptileTail => Trait(
        id: 'reptile_tail',
        name: 'Scale Regeneration',  // Reptile tail regen
        type: TraitType.support,
        part: TraitPart.tail,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Regrow scales — REGEN 20 HP/round for 3 rounds (self).',
        rarity: SkillRarity.rare,
        effect: const TraitEffect(
          type: EffectType.buff, value: 20,
          buffType: BuffType.regen, duration: 3, target: 'self',
        ),
      );

  static Trait get reptileMouth => Trait(
        id: 'reptile_mouth',
        name: 'Tiny Catapult',       // Tiny Catapult mouth — pierce back row
        type: TraitType.offensive,
        part: TraitPart.mouth,
        energyCost: 2,
        cooldownMax: 0,
        description: 'Launch a projectile — pierce the front row and deal 50 damage to the back enemy.',
        rarity: SkillRarity.common,
        effect: const TraitEffect(type: EffectType.damage, value: 50, target: 'back_enemy', selfShield: 25),
      );
}
