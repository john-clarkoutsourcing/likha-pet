enum TraitType { offensive, defensive, support, utility }

enum EffectType { damage, shield, heal, buff, debuff, aoe, shieldBreak }

enum BuffType { attackUp, defenseUp, speedUp, energized, regen }

enum DebuffType { attackDown, defenseDown, stunned, poisoned, burned, speedDown }

enum SkillRarity { common, rare, epic }

class TraitEffect {
  final EffectType type;
  final int value;
  final BuffType? buffType;
  final DebuffType? debuffType;
  final int duration; // rounds the buff/debuff lasts (0 = instant)
  final String target; // 'enemy', 'ally', 'self', 'all_enemies', 'all_allies'

  const TraitEffect({
    required this.type,
    required this.value,
    this.buffType,
    this.debuffType,
    this.duration = 0,
    required this.target,
  });
}

class Trait {
  final String id;
  final String name;
  final TraitType type;
  final int energyCost;
  final int cooldownMax;
  final TraitEffect effect;
  final String description;
  final SkillRarity rarity;
  final String? comboTag;
  final List<String> tags;

  int cooldownRemaining = 0;

  Trait({
    required this.id,
    required this.name,
    required this.type,
    required this.energyCost,
    required this.cooldownMax,
    required this.effect,
    required this.description,
    this.rarity = SkillRarity.common,
    this.comboTag,
    this.tags = const [],
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
      energyCost: energyCost,
      cooldownMax: cooldownMax,
      effect: effect,
      description: description,
      rarity: rarity,
      comboTag: comboTag,
      tags: tags,
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
        energyCost: 1,
        cooldownMax: 0,
        description: 'Raise defense by 15 for 2 rounds.',
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 15,
          buffType: BuffType.defenseUp,
          duration: 2,
          target: 'self',
        ),
      );

  static Trait get amihanVeil => Trait(
        id: 'amihan_veil',
        name: 'Amihan Veil',
        type: TraitType.defensive,
        energyCost: 2,
        cooldownMax: 3,
        description: 'Apply a shield that absorbs 40 damage.',
        effect: const TraitEffect(
          type: EffectType.shield,
          value: 40,
          target: 'self',
        ),
      );

  static Trait get sarimanokAura => Trait(
        id: 'sarimanok_aura',
        name: 'Sarimanok Aura',
        type: TraitType.support,
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
        energyCost: 2,
        cooldownMax: 0,
        description: 'Apply poison to a single enemy (8 dmg/round, 3 rounds).',
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 8,
          debuffType: DebuffType.poisoned,
          duration: 3,
          target: 'enemy',
        ),
      );

  static Trait get anakngLupaSlam => Trait(
        id: 'anak_ng_lupa_slam',
        name: 'Anak ng Lupa Slam',
        type: TraitType.offensive,
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
        energyCost: 2,
        cooldownMax: 3,
        description: 'Grant Defense +15 to ALL allies for 2 rounds.',
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 15,
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
        energyCost: 2,
        cooldownMax: 3,
        description: 'Reduce Attack by 10 on ALL enemies for 2 rounds.',
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 10,
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
        energyCost: 2,
        cooldownMax: 3,
        description: 'Speed Down + DEF -10 (2 rounds) on front enemy.',
        rarity: SkillRarity.rare,
        comboTag: 'spirit',
        tags: const ['speedDown', 'debuff', 'front'],
        effect: const TraitEffect(
          type: EffectType.debuff,
          value: 10,
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
}
