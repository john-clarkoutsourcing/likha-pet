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

  // Raw base stats per the universal combat spec (pre-scaling).
  // Scaling is applied in CreatureDefinition.toPet():
  //   Battle HP    = (total_hp    × 6) + 150
  //   Battle Stats = (total_stat  × 4) + 100
  ({int hp, int speed, int skill, int morale}) get baseBodyStats =>
      switch (this) {
        CreatureClass.plant   => (hp: 43, speed: 31, skill: 31, morale: 35),
        CreatureClass.aquatic => (hp: 39, speed: 39, skill: 35, morale: 27),
        CreatureClass.beast   => (hp: 31, speed: 35, skill: 31, morale: 43),
        CreatureClass.reptile => (hp: 39, speed: 39, skill: 35, morale: 27),
        CreatureClass.bird    => (hp: 31, speed: 43, skill: 35, morale: 31),
        CreatureClass.bug     => (hp: 35, speed: 31, skill: 35, morale: 39),
      };

  // Per-part raw stat bonus (spec: 6 parts in classic; we use 4 active parts).
  // Pure-breed with 4 of the same part: adds 4× this bonus to body base.
  ({int hp, int speed, int skill, int morale}) get partStatBonus =>
      switch (this) {
        CreatureClass.plant   => (hp: 3, speed: 0, skill: 0, morale: 1),
        CreatureClass.reptile => (hp: 3, speed: 1, skill: 0, morale: 0),
        CreatureClass.aquatic => (hp: 1, speed: 3, skill: 0, morale: 0),
        CreatureClass.bird    => (hp: 0, speed: 3, skill: 1, morale: 0),
        CreatureClass.bug     => (hp: 1, speed: 0, skill: 3, morale: 0),
        CreatureClass.beast   => (hp: 0, speed: 1, skill: 0, morale: 3),
      };
}

enum TraitType { offensive, defensive, support, utility }

enum EffectType { damage, shield, heal, buff, debuff, shieldBreak }

enum BuffType {
  attackUp,   // +X% attack for N rounds (consumed on attack)
  defenseUp,  // +X% defense for N rounds
  speedUp,    // +X% speed for N rounds (affects turn order)
  energized,  // +X bonus energy per round
  regen,      // restore X HP per round
  moraleUp,   // +X% morale → higher crit chance for N rounds
}

enum DebuffType {
  attackDown,   // −X% attack for N rounds
  defenseDown,  // −X% defense for N rounds
  stunned,      // skip next action (consumed on skip)
  poisoned,     // lose X HP per action (stacks, ticks per card played)
  burned,       // lose X HP per round (ticks at round start)
  sleep,        // next hit ignores shield (removed on hit)
  fear,         // skip next action (consumed on skip)
  aroma,        // forced target for enemies
  chill,        // cannot enter Last Stand
  jinx,         // cannot deal critical hits
  healBlocked,  // cannot receive healing
  critBlocked,  // cannot be critically hit
  disabled,     // next card is skipped (consumed on skip)
  reflect,      // reflect X% of incoming damage to attacker
  stench,       // enemies skip targeting this pet
  speedDown,    // −X% speed for N rounds
  isolate,      // cannot use ally-targeting cards this round
  moraleDown,   // −X% morale → lower crit chance for N rounds
  fragile,      // −25% defense (flat, for N rounds)
  lethal,       // bypasses Last Stand when HP drops to zero
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

  Trait copyWith({
    String? id,
    String? name,
    TraitType? type,
    TraitPart? part,
    int? energyCost,
    int? cooldownMax,
    TraitEffect? effect,
    String? description,
    SkillRarity? rarity,
    String? comboTag,
    List<String>? tags,
    CreatureClass? partClass,
  }) {
    final t = Trait(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      part: part ?? this.part,
      energyCost: energyCost ?? this.energyCost,
      cooldownMax: cooldownMax ?? this.cooldownMax,
      effect: effect ?? this.effect,
      description: description ?? this.description,
      rarity: rarity ?? this.rarity,
      comboTag: comboTag ?? this.comboTag,
      tags: tags ?? this.tags,
      partClass: partClass ?? this.partClass,
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

    final trait = Trait(
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
    return _classicOverride(trait, cardId);
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

  // ═══════════════════════════════════════════════════════════════════════════
  // CARD AUTHORING GUIDE — how to add a new card
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // Every card in the game is built in three steps:
  //
  //  STEP 1 — Add the spec to classic_card_specs.dart
  //  ─────────────────────────────────────────────────
  //  Key format: '<class>-<part>-<NN>'   e.g. 'bird-back-05'
  //  Values: name, attack, defense, energy, description.
  //  The 'attack' value becomes damage (for damage cards) or is ignored.
  //  The 'defense' value becomes selfShield (shield the actor gains after acting).
  //
  //  STEP 2 — Pick or create a base TraitLibrary getter
  //  ──────────────────────────────────────────────────
  //  The static getters (beastHorn, plantBack, birdBack, etc.) define the
  //  PRIMARY EFFECT TYPE for all variants of a part slot.
  //  e.g. all 'bird_back_*' cards start as damage → back_enemy.
  //  If the PRIMARY EFFECT TYPE you need doesn't match any existing getter,
  //  create a new static getter (see plantMouthVegetalBite as an example).
  //
  //  Base getters use:  EffectType.damage / heal / shield / buff / debuff
  //  _effectFromClassic then fills in the numeric values from the spec.
  //
  //  STEP 3 — Add a case in _classicOverride (this method)
  //  ──────────────────────────────────────────────────────
  //  Use this to specialise a card beyond what its base getter provides.
  //
  //  RULE A — Change PRIMARY effect type:
  //    Use trait.copyWith(effect: TraitEffect(...)) with the new type.
  //    Required when the card does something fundamentally different from
  //    its class default (e.g. Eggbomb is bird-back but deals damage, not buff).
  //    Always use  TraitEffect(... selfShield: trait.effect.selfShield)
  //    to preserve the spec's defense value — it is already computed.
  //
  //  RULE B — Add a TAG for a secondary/conditional behaviour:
  //    Use trait.copyWith(tags: [...trait.tags, 'my_new_tag']).
  //    Tags drive ADDITIONAL logic in ActionResolver on top of the primary effect.
  //    Use a tag (not a new effect type) when:
  //      • The card still does its normal damage/heal/shield AND also does X
  //      • The extra behaviour is conditional (on combo count, on shield break, etc.)
  //
  //  RULE C — Change effect AND add a tag:
  //    trait.copyWith(effect: TraitEffect(...), tags: [...trait.tags, 'tag'])
  //    Needed when the primary effect must change AND extra behaviour exists.
  //    Example: Eggbomb changes damage target AND adds target_aroma.
  //
  // ── TAG REFERENCE — all recognised tags ──────────────────────────────────
  //
  //  ATTACKER TAGS (checked against the card being played):
  //
  //  Crit / damage modifiers:
  //    crit_if_first              Guaranteed crit when comboIndex == 0
  //    double_crit_damage         Crits deal ×3 instead of ×2
  //    double_damage_last_stand   Actor in last stand → ×2 damage
  //    bonus_damage_if_debuffed   Target has debuffs → ×1.2 damage
  //    bonus_damage_vs_bug        Target is Bug class → ×1.5 damage
  //    multi_hit_3                Strike 3 times (each hit uses kMaxAoeDamagePerHit cap)
  //    prevent_last_stand         Kill target outright — bypass last stand
  //    force_last_stand_if_killed Force target into last stand instead of dying
  //    end_last_stand             Finish a target already in last stand
  //    skip_targets_in_last_stand Prefer non-last-stand targets
  //
  //  Card draw (attacker draws on condition):
  //    draw_if_attack_first            comboIndex == 0
  //    draw_if_attack_idle_target      target had no shield (shieldBefore == 0)
  //    draw_if_attack_aqua_bird_dawn   target is Aquatic or Bird class
  //    draw_if_shield_not_break        attack did NOT break target's shield
  //    attacker_energy_on_shield_break attacker gains energy when shield breaks
  //
  //  Self-effects after attacking:
  //    self_aroma                 Apply Aroma to self (any card type)
  //    self_speed_up              Apply SpeedUp to self after hitting
  //    energy_on_crit             Gain 1 energy on any crit
  //    attack_first_if_last_stand Go first in turn order when any pet is in last stand
  //
  //  Enemy control after hit:
  //    target_aroma               Apply Aroma to hit target (mark for focus)
  //    isolated_on_combo_3        Apply Isolate to target when comboIndex >= 2
  //    transfer_debuffs           Move all self-debuffs to target after hit
  //
  //  Misc:
  //    cleanse                    Clear all actor debuffs before primary effect
  //
  //  DEFENDER TAGS (checked against the DEFENDER's played card via roundTraitsByPetId):
  //  — These live in _applyShieldBreakReactions / _applyOnHitReactions —
  //
  //  On shield break (defender's shield is destroyed):
  //    on_shield_break_attack_up         Self gets AttackUp
  //    on_shield_break_energy            Self gains 1 energy
  //    on_shield_break_stun_attacker     Stun the attacker unconditionally
  //    counter_stun_plant_reptile        Stun attacker only if Plant or Reptile
  //    counter_stun_aqua_bird            Stun attacker only if Aquatic or Bird
  //    draw_if_shield_break              Draw a card
  //
  //  On being hit (any damage lands):
  //    on_hit_energy_vs_aquatic          Gain energy if hit by Aquatic
  //    draw_if_hit_by_beast_bug_mech     Draw card if hit by Beast, Bug, or Mech
  //    draw_if_hit_shield_held           Draw if hit but shield not broken
  //    shield_when_hit                   Gain 20 shield when struck
  //    disable_horn_next                 Disable attacker's horn card next round
  //    disable_ability                   Disable attacker's next card (generic)
  //    disable_melee_next                Disable attacker's melee card next round
  //    disable_mouth_next                Disable attacker's mouth card next round
  //    reflect_ranged                    Apply Reflect 40% status to self
  //    reflect_melee                     Apply Reflect 40% status to self
  //
  // ─────────────────────────────────────────────────────────────────────────
  static Trait _classicOverride(Trait trait, String cardId) {
    switch (cardId) {
      case 'aquatic-back-02':
        return trait.copyWith(
          effect: const TraitEffect(
            type: EffectType.debuff,
            value: 0,
            debuffType: DebuffType.critBlocked,
            duration: 1,
            target: 'self',
          ),
        );
      case 'aquatic-back-04':
        return trait.copyWith(tags: [...trait.tags, 'draw_if_attack_idle_target']);
      case 'aquatic-back-06':
        // Swift Escape: gain Speed+ when struck (reaction hook).
        return trait.copyWith(tags: [...trait.tags, 'self_speed_up_on_hit']);
      case 'aquatic-back-08':
        return trait.copyWith(tags: [...trait.tags, 'on_shield_break_attack_up']);
      case 'aquatic-mouth-08':
        // Fish Hook: deal damage AND apply Attack+ to self when hitting a
        // Plant or Reptile target. Base aquaticMouth has lifeSteal=true
        // (inherited from Swallow/04) — override to remove it.
        return trait.copyWith(
          effect: TraitEffect(
            type: EffectType.damage,
            value: trait.effect.value,          // 120 from spec
            target: trait.effect.target,        // 'enemy'
            selfShield: trait.effect.selfShield, // 25 from spec
            lifeSteal: false,                   // Fish Hook has no lifesteal
          ),
          tags: [...trait.tags, 'self_atk_up_vs_plant_reptile'],
        );
      case 'aquatic-horn-06':
        // Clam Slash: gain Attack+ when hitting Beast or Bug.
        return trait.copyWith(tags: [...trait.tags, 'self_atk_up_vs_beast_bug']);
      case 'aquatic-mouth-02':
        // Angry Lam: deal 120% damage when actor HP ≤ 50%.
        return trait.copyWith(tags: [...trait.tags, 'bonus_if_low_hp']);
      case 'aquatic-mouth-10':
        // Crimson Water: redirect to lowest-HP enemy when actor HP ≤ 50%.
        return trait.copyWith(tags: [...trait.tags, 'target_injured_if_low_hp']);
      case 'aquatic-tail-04':
        // Tail Slap: gain 1 energy when comboed (not unconditionally).
        return trait.copyWith(tags: [...trait.tags, 'energy_gain_on_combo']);
      case 'aquatic-horn-10':
        return trait.copyWith(tags: [...trait.tags, 'end_last_stand']);
      case 'aquatic-horn-12':
        return trait.copyWith(tags: [...trait.tags, 'prevent_last_stand']);
      case 'aquatic-tail-06':
        // Black Bubble: deal 110 damage AND apply Jinx for 4 rounds.
        return trait.copyWith(tags: [...trait.tags, 'apply_jinx_4']);
      case 'aquatic-tail-08':
        // Water Sphere: deal 110 damage AND apply Chill for 4 rounds.
        return trait.copyWith(tags: [...trait.tags, 'apply_chill_4']);
      case 'aquatic-tail-12':
        // Chitin Jump: targets the furthest (back-row) enemy instead of front.
        // When in a combo, the combo-lock mechanic makes all subsequent cards
        // from the same pet also chase the back-row target this round.
        return trait.copyWith(
          effect: TraitEffect(
            type:        trait.effect.type,
            value:       trait.effect.value,
            target:      'furthest_enemy',
            selfShield:  trait.effect.selfShield,
            lifeSteal:   trait.effect.lifeSteal,
            energySteal: trait.effect.energySteal,
            energyDrain: trait.effect.energyDrain,
          ),
        );
      case 'beast-back-02':
        // Single Combat: guaranteed crit when played as 3rd+ card in combo.
        // Was wrongly 'crit_if_first' (fires on 1st card — opposite of intent).
        return trait.copyWith(tags: [...trait.tags, 'crit_on_combo_3']);
      case 'beast-back-04':
        return trait.copyWith(tags: [...trait.tags, 'draw_if_attack_aqua_bird_dawn']);
      case 'beast-back-06':
        return trait.copyWith(tags: [...trait.tags, 'attack_first_if_last_stand']);
      case 'beast-back-08':
        return trait.copyWith(tags: [...trait.tags, 'double_damage_last_stand']);
      case 'beast-back-10':
        // Woodman Power: shield actor by actual damage dealt.
        // Was 'counter_stun_plant_reptile' — completely wrong mechanic.
        return trait.copyWith(tags: [...trait.tags, 'shield_equal_to_damage']);
      case 'beast-back-12':
        return trait.copyWith(tags: [...trait.tags, 'multi_hit_3']);
      case 'beast-horn-02':
        return trait.copyWith(tags: [...trait.tags, 'crit_if_first']);
      case 'beast-horn-04':
        return trait.copyWith(tags: [...trait.tags, 'energy_on_crit']);
      case 'beast-horn-08':
        return trait.copyWith(tags: [...trait.tags, 'self_aroma']);
      case 'beast-horn-10':
        return trait.copyWith(tags: [...trait.tags, 'double_crit_damage']);
      case 'beast-horn-12':
        // Acrobatic: Speed+ when comboed (not unconditionally).
        // 'self_speed_up' had no handler — renamed to 'self_speed_up_on_combo'.
        return trait.copyWith(tags: [...trait.tags, 'self_speed_up_on_combo']);
      case 'beast-mouth-08':
        // Death Mark: apply Lethal status to target when actor HP ≤ 50%.
        return trait.copyWith(tags: [...trait.tags, 'apply_lethal_if_low_hp']);
      case 'beast-tail-04':
        // Night Steal: steal energy ONLY when comboed (not unconditionally).
        // Base beastTail has energySteal=true — override to remove it.
        return trait.copyWith(
          effect: TraitEffect(
            type: EffectType.damage,
            value: trait.effect.value,
            target: trait.effect.target,
            selfShield: trait.effect.selfShield,
            energySteal: false,
          ),
          tags: [...trait.tags, 'energy_steal_on_combo'],
        );
      case 'beast-tail-06':
        return trait.copyWith(tags: [...trait.tags, 'force_last_stand_if_killed']);
      case 'beast-tail-08':
        return trait.copyWith(tags: [...trait.tags, 'draw_if_attack_first']);
      case 'beast-tail-12':
        // Gerbil Jump: skip the front enemy and target the back row.
        // 'back_enemy' falls back to any alive pet when only one remains.
        // Also clears the base energySteal=true that beastTail inherits from
        // Night Steal (beast-tail-04) — Gerbil Jump has no energy steal.
        return trait.copyWith(
          effect: TraitEffect(
            type:        trait.effect.type,
            value:       trait.effect.value,
            target:      'back_enemy',
            selfShield:  trait.effect.selfShield,
            lifeSteal:   trait.effect.lifeSteal,
            energySteal: false,
            energyDrain: trait.effect.energyDrain,
          ),
        );
      case 'bird-back-02':
        // Balloon Pop: deal 40 damage AND apply Fear for 1 turn.
        return trait.copyWith(tags: [...trait.tags, 'apply_fear_1']);
      case 'bird-back-04':
        // Heart Break: deal 120 damage AND apply Chill for 4 rounds.
        return trait.copyWith(tags: [...trait.tags, 'apply_chill_4']);
      case 'bird-back-05':
        return trait.copyWith(tags: [...trait.tags, 'isolated_on_combo_3']);
      case 'bird-back-06':
        // Ill-omened: deal 120 damage AND apply Jinx for 4 rounds.
        return trait.copyWith(tags: [...trait.tags, 'apply_jinx_4']);
      case 'bird-back-12':
        // Triple Threat: deal 40 damage, then attack again if this Axie has any debuffs.
        return trait.copyWith(tags: [...trait.tags, 'attack_again_if_debuffed']);
      case 'bird-back-08':
        // Blackmail: deal damage to back enemy + transfer ALL debuffs from self
        // to target. Base birdBack already gives damage(120, back_enemy,
        // selfShield=30) from _effectFromClassic, so only the tag is needed.
        return trait.copyWith(tags: [...trait.tags, 'transfer_debuffs']);
      case 'bird-back-09':
        // Blackmail II: deal 20% bonus damage when the target has any debuffs.
        // Base birdBack gives damage(120, back_enemy, selfShield=15) — tag only.
        return trait.copyWith(tags: [...trait.tags, 'bonus_damage_if_debuffed']);
      case 'bird-horn-02':
        // Eggbomb: deal 120 damage to enemy AND apply Aroma to the TARGET.
        // target_aroma marks the enemy so allies preferentially focus it.
        return trait.copyWith(
          effect: TraitEffect(
            type: EffectType.damage,
            value: 120, // spec.attack for bird-horn-02
            target: 'enemy',
            selfShield: trait.effect.selfShield, // 10 from spec
          ),
          tags: [...trait.tags, 'target_aroma'],
        );
      case 'bird-horn-08':
        return trait.copyWith(tags: [...trait.tags, 'disable_horn_next']);
      case 'bird-horn-06':
        // Air Force One: +20% damage when chained with another Trump card.
        return trait.copyWith(tags: [
          ...trait.tags,
          'chain_family_trump',
          'bonus_damage_on_chain_trump',
        ]);
      case 'bird-horn-12':
        // Feather Lunge: +20% damage when chained with another Lunge card.
        return trait.copyWith(tags: [
          ...trait.tags,
          'chain_family_lunge',
          'bonus_damage_on_chain_lunge',
        ]);
      case 'bird-mouth-10':
        // Dark Swoop: always seeks the fastest enemy (highest speed).
        // Was wrongly adding an unhandled 'target_fastest_enemy' tag.
        // Resolver routes via effect.target string, not tags.
        return trait.copyWith(
          effect: TraitEffect(
            type:        trait.effect.type,
            value:       trait.effect.value,
            target:      'fastest_enemy',
            selfShield:  trait.effect.selfShield,
            lifeSteal:   trait.effect.lifeSteal,
            energySteal: trait.effect.energySteal,
            energyDrain: trait.effect.energyDrain,
          ),
        );
      case 'bird-mouth-02':
        // Soothing Song: deal 60 damage (ignore shield) AND apply Sleep for 1 turn.
        return trait.copyWith(tags: [...trait.tags, 'apply_sleep_1', 'ignore_shield']);
      case 'bird-mouth-04':
        // Peace Treaty: deal damage PLUS apply Attack- for 2 rounds.
        // Must preserve the base damage from spec (120) and selfShield (30).
        return trait.copyWith(
          effect: TraitEffect(
            type: EffectType.damage,
            value: trait.effect.value,          // 120 from spec
            target: 'enemy',
            selfShield: trait.effect.selfShield, // 30 from spec
          ),
          tags: [...trait.tags, 'apply_attack_down_2'],
        );
      case 'bird-back-10':
        // Patient Hunter: prefer Aquatic targets when actor HP ≤ 50%.
        return trait.copyWith(tags: [...trait.tags, 'target_aquatic_if_low_hp']);
      case 'bird-horn-04':
        // Cockadoodle: Attack+ to THIS Axie only (not whole team).
        // Base birdHorn buffs all_allies — override to self only.
        return trait.copyWith(
          effect: const TraitEffect(
            type: EffectType.buff,
            value: 20,
            buffType: BuffType.attackUp,
            duration: 1,
            target: 'self',
          ),
        );
      case 'bird-mouth-08':
        // Insectivore: prefer Bug targets when actor HP ≤ 50%.
        return trait.copyWith(tags: [...trait.tags, 'target_bug_if_low_hp']);
      case 'bird-tail-08':
        return trait.copyWith(tags: [...trait.tags, 'skip_targets_in_last_stand']);
      case 'bird-horn-10':
        // Smart Shot: skip the front enemy and target the back row when 2+ enemies remain.
        return trait.copyWith(
          effect: TraitEffect(
            type:        trait.effect.type,
            value:       trait.effect.value,
            target:      'back_enemy',
            selfShield:  trait.effect.selfShield,
            lifeSteal:   trait.effect.lifeSteal,
            energySteal: trait.effect.energySteal,
            energyDrain: trait.effect.energyDrain,
          ),
        );
      case 'bird-tail-12':
        // All-out Shot: deal damage then inflict 30% of own max HP back on self.
        return trait.copyWith(tags: [...trait.tags, 'self_damage_30pct_max_hp']);
      case 'bug-back-02':
        // Sticky Goo: deal 40 damage AND apply Stun for 1 turn.
        // Reaction: stun the attacker when this pet's shield is broken.
        return trait.copyWith(
          tags: [...trait.tags, 'apply_stun_1', 'on_shield_break_stun_attacker'],
        );
      case 'bug-back-08':
        // Bug Splat: +50% damage vs Bug targets (was wrongly tagged reflect_ranged).
        return trait.copyWith(tags: [...trait.tags, 'bonus_damage_vs_bug']);
      case 'bug-back-04':
        // Barb Strike: deal damage as normal, then apply 2 Poison only when chained.
        return trait.copyWith(
          tags: [...trait.tags, 'apply_poison_on_chain'],
        );
      case 'bug-horn-04':
        // Bug Signal: steal energy only when chained with another Bug Signal.
        return trait.copyWith(
          effect: TraitEffect(
            type: trait.effect.type,
            value: trait.effect.value,
            target: trait.effect.target,
            selfShield: trait.effect.selfShield,
            lifeSteal: trait.effect.lifeSteal,
            energySteal: false,
            energyDrain: trait.effect.energyDrain,
          ),
          tags: [
            ...trait.tags,
            'chain_family_bug_signal',
            'energy_steal_on_chain_bug_signal',
          ],
        );
      case 'bug-mouth-08':
        // Terror Chomp: apply Fear for 2 turns when played in a class chain.
        return trait.copyWith(tags: [...trait.tags, 'apply_fear_on_chain']);
      case 'bug-back-10':
        // Scarab Curse: deal 100 damage AND apply HealBlocked for 2 rounds.
        return trait.copyWith(tags: [...trait.tags, 'apply_heal_blocked_2']);
      case 'bug-back-12':
        // Buzzing Wind: deal 10 damage AND apply Fragile for 2 rounds.
        return trait.copyWith(tags: [...trait.tags, 'apply_fragile_2']);
      case 'bug-horn-06':
        // Grub Surprise: apply Fear to shielded targets.
        return trait.copyWith(tags: [...trait.tags, 'apply_fear_if_shielded']);
      case 'bug-tail-02':
        // Chemical Warfare: deal 60 damage AND apply Stench for 3 rounds.
        return trait.copyWith(tags: [...trait.tags, 'apply_stench_3']);
      case 'bug-tail-06':
        return trait.copyWith(tags: [...trait.tags, 'counter_stun_aqua_bird']);
      case 'bug-tail-08':
        return trait.copyWith(tags: [...trait.tags, 'disable_melee_next']);
      case 'bug-tail-10':
        return trait.copyWith(tags: [...trait.tags, 'force_last_stand_if_killed']);
      case 'bug-tail-12':
        return trait.copyWith(tags: [...trait.tags, 'bonus_damage_if_debuffed']);
      case 'plant-back-02':
        // Turnip Rocket: damage card that redirects to a Bird enemy when in a
        // 2+ card combo. Base plantBack is a shield type, so override entirely.
        return trait.copyWith(
          effect: TraitEffect(
            type:       EffectType.damage,
            value:      60,   // spec.attack
            target:     'enemy',
            selfShield: 80,   // spec.defense
          ),
          tags: [...trait.tags, 'target_bird_on_combo'],
        );
      case 'plant-back-04':
        // Shroom Spite: heal self 240 HP. Base plantBack is shield type.
        return trait.copyWith(
          effect: TraitEffect(
            type: EffectType.heal,
            value: 240,
            target: 'self',
            selfShield: trait.effect.value, // spec defense stored as shield value
          ),
        );
      case 'plant-back-06':
        return trait.copyWith(tags: [...trait.tags, 'cleanse']);
      case 'plant-back-08':
        // Aqua Stock: energy from aquatic attacker hitting you, AND energy when your shield breaks.
        return trait.copyWith(tags: [...trait.tags, 'on_hit_energy_vs_aquatic', 'on_shield_break_energy']);
      case 'plant-back-12':
        // October Treat: defender draws when attacked and their shield is NOT broken.
        return trait.copyWith(tags: [...trait.tags, 'draw_if_hit_shield_held']);
      case 'plant-tail-06':
        return trait.copyWith(tags: [...trait.tags, 'disable_ability']);
      case 'plant-tail-02':
        // Carrot Hammer: ATTACKER gains energy when this card breaks the target's shield.
        return trait.copyWith(tags: [...trait.tags, 'attacker_energy_on_shield_break']);
      case 'plant-tail-04':
        return trait.copyWith(tags: [...trait.tags, 'draw_if_hit_by_beast_bug_mech']);
      case 'plant-tail-12':
        return trait.copyWith(tags: [...trait.tags, 'disable_mouth_next']);
      case 'plant-horn-08':
        // Sweet Party: heal frontline ally for 270 HP.
        // Base plantHorn is damage type so _effectFromClassic produced damage(0).
        return trait.copyWith(
          effect: TraitEffect(
            type: EffectType.heal,
            value: 270,
            target: 'front_ally',
            selfShield: trait.effect.selfShield, // 40 from spec
          ),
        );
      case 'plant-horn-10':
        // Prickly Trap: deal 120% damage if this Axie acts last in the round.
        return trait.copyWith(tags: [...trait.tags, 'bonus_if_acts_last']);
      case 'plant-horn-02':
        // Bamboo Clan: +20% damage when played in a class chain.
        return trait.copyWith(tags: [...trait.tags, 'bonus_damage_on_chain']);
      case 'plant-mouth-02':
        // Vegetal Bite: steal energy ONLY when comboed (not unconditionally).
        // Base plantMouthVegetalBite has energySteal=true — override to remove it.
        return trait.copyWith(
          effect: TraitEffect(
            type: EffectType.damage,
            value: trait.effect.value,
            target: trait.effect.target,
            selfShield: trait.effect.selfShield,
            energySteal: false,
          ),
          tags: [...trait.tags, 'energy_steal_on_combo'],
        );
      case 'plant-mouth-08':
        // Vegan Diet: lifesteal ONLY when attacking Plant targets (not always).
        // Base plantMouth has lifeSteal=true — override to remove it.
        return trait.copyWith(
          effect: TraitEffect(
            type: EffectType.damage,
            value: trait.effect.value,
            target: trait.effect.target,
            selfShield: trait.effect.selfShield,
            lifeSteal: false,
          ),
          tags: [...trait.tags, 'lifesteal_vs_plant'],
        );
      case 'plant-mouth-10':
        // Forest Spirit: heal frontline ally for 190 HP (was 120).
        return trait.copyWith(
          effect: TraitEffect(
            type: EffectType.heal,
            value: 190,
            target: 'front_ally',
            selfShield: trait.effect.selfShield, // 40 from spec
          ),
        );
      case 'reptile-mouth-02':
        // Sneaky Raid: targets the furthest (back-row) enemy instead of front.
        // Missing from _classicOverride — base reptileMouth had target: 'enemy'.
        return trait.copyWith(
          effect: TraitEffect(
            type:        trait.effect.type,
            value:       trait.effect.value,
            target:      'furthest_enemy',
            selfShield:  trait.effect.selfShield,
            lifeSteal:   trait.effect.lifeSteal,
            energySteal: trait.effect.energySteal,
            energyDrain: trait.effect.energyDrain,
          ),
        );
      case 'reptile-mouth-04':
        // Kotaro Bite: gain 1 energy when the target is faster than this Axie.
        // Advanced variant: also steals Speed (twin-state +20/-20 for 2 rounds).
        return trait.copyWith(tags: [
          ...trait.tags,
          'energy_if_target_faster',
          'steal_speed_20_2',
        ]);
      case 'reptile-mouth-10':
        // Chomp: apply Stun to target when this Axie plays 3 or more cards this round.
        return trait.copyWith(tags: [...trait.tags, 'stun_on_combo_3_total']);
      case 'reptile-horn-02':
        // Poo Fling: deal 70 damage AND apply Stench for 3 rounds.
        return trait.copyWith(tags: [...trait.tags, 'apply_stench_3']);
      case 'reptile-back-08':
        // Bulwark: apply Reflect (40%) to self for 2 rounds AND grant the spec's
        // defense shield. The previous const TraitEffect dropped selfShield entirely.
        return trait.copyWith(
          tags: [...trait.tags, 'self_aroma'],
          effect: TraitEffect(
            type: EffectType.debuff,
            value: 40, // 40% reflect per card description (was wrong 30)
            debuffType: DebuffType.reflect,
            duration: 2,
            target: 'self',
            selfShield: trait.effect.selfShield, // 80 from spec — was being lost
          ),
        );
      case 'reptile-back-10':
        return trait.copyWith(tags: [...trait.tags, 'shield_when_hit']);
      case 'reptile-horn-06':
        // Surprise Invasion: deal 130% damage when target is faster than actor.
        return trait.copyWith(tags: [...trait.tags, 'bonus_if_target_faster']);
      case 'reptile-horn-04':
        // Scaly Lunge: +20% damage when chained with another Lunge card.
        return trait.copyWith(tags: [
          ...trait.tags,
          'chain_family_lunge',
          'bonus_damage_on_chain_lunge',
        ]);
      case 'reptile-mouth-08':
        // Why So Serious: lifesteal ONLY when attacking Aquatic targets.
        // Base reptileMouth has no lifesteal — just add the conditional tag.
        return trait.copyWith(tags: [...trait.tags, 'lifesteal_vs_aquatic']);
      case 'reptile-tail-04':
        // Scale Dart (reptile): gain 1 energy when attacking a buffed target.
        return trait.copyWith(tags: [...trait.tags, 'energy_gain_vs_buffed']);
      case 'reptile-back-02':
        return trait.copyWith(tags: [...trait.tags, 'draw_if_shield_break']);
      case 'reptile-horn-08':
        return trait.copyWith(tags: [...trait.tags, 'reflect_ranged']);
      case 'reptile-tail-08':
        return trait.copyWith(tags: [...trait.tags, 'draw_if_shield_not_break']);
      case 'reptile-tail-12':
        // Venom Spray: deal 20 damage AND apply SpeedDown for 1 round.
        return trait.copyWith(tags: [...trait.tags, 'apply_speed_down_1']);
      default:
        return trait;
    }
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

  /// Chitin Jump — aquatic-tail-12: targets the furthest (back-row) enemy.
  /// When played in a combo, the combo-lock makes all subsequent enemy-facing
  /// damage cards from the same pet also attack the back-row target.
  static Trait get chitinJump => withClassicCardStats(
        baseTrait: _base(id: 'aquatic_tail', type: TraitType.offensive, part: TraitPart.tail, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'furthest_enemy')),
        traitId: 'aquatic_tail', cardId: 'aquatic-tail-12');

  static Trait get aquaticMouth => withClassicCardStats(
        baseTrait: _base(id: 'aquatic_mouth', type: TraitType.offensive, part: TraitPart.mouth, effect: const TraitEffect(type: EffectType.damage, value: 0, target: 'enemy', lifeSteal: true)),
        traitId: 'aquatic_mouth', cardId: 'aquatic-mouth-04');

  // ── Bird ──────────────────────────────────────────────────────────────────
  static Trait get birdHorn => withClassicCardStats(
        baseTrait: _base(id: 'bird_horn', type: TraitType.support, part: TraitPart.horn,
            effect: const TraitEffect(type: EffectType.buff, value: 20, buffType: BuffType.attackUp, duration: 1, target: 'all_allies')),
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
        baseTrait: _base(id: 'plant_horn_2', type: TraitType.support, part: TraitPart.horn,
            effect: const TraitEffect(type: EffectType.heal, value: 120, target: 'self')),
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
