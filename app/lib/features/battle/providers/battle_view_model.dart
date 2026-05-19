import 'dart:ui' show Offset;
import 'package:flutter/material.dart' show Color;
import 'package:likha_pet_battle_engine/battle_state.dart';
import 'package:likha_pet_battle_engine/energy_pool.dart';
import 'package:likha_pet_battle_engine/pet.dart';
import 'package:likha_pet_battle_engine/skill_card.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../data/creature_registry.dart' show CreatureDefinition;
import '../data/trait_card_catalog.dart';
import '../widgets/pet_character_widget.dart' show PetCharacterAnimState;
import '../widgets/pet_sprite_widget.dart' show PetSpriteConfig;

// ── PvpMatchEndData ───────────────────────────────────────────────────────────

class PvpMatchEndData {
  final String? winnerUid;
  final bool dispute;
  final int mmrDelta;
  const PvpMatchEndData(
      {required this.winnerUid, required this.dispute, required this.mmrDelta});
}

class ResolvingCardItem {
  final String id;
  final String name;
  final String? imagePath;

  const ResolvingCardItem({
    required this.id,
    required this.name,
    this.imagePath,
  });
}

class BattleImpactEvent {
  final int id;
  final String actorId;
  final String targetId;
  final String effectType;
  final bool isCritical;
  final int damage;
  final int healAmount;
  final int shieldAmount;
  final String statusApplied;
  final int targetHpAfter;
  final int targetShieldAfter;
  final bool targetIsFainted;
  final int actorHpAfter;
  final int actorShieldAfter;

  const BattleImpactEvent({
    required this.id,
    required this.actorId,
    required this.targetId,
    required this.effectType,
    this.isCritical = false,
    required this.damage,
    required this.healAmount,
    required this.shieldAmount,
    required this.statusApplied,
    required this.targetHpAfter,
    required this.targetShieldAfter,
    required this.targetIsFainted,
    required this.actorHpAfter,
    required this.actorShieldAfter,
  });
}

// ── TraitViewModel ────────────────────────────────────────────────────────────

class TraitViewModel {
  final String id;
  final String name;
  final String description;
  final String typeName;
  final String partName;
  final String effectSummary;
  final String targetSummary;
  final String targetingMode; // 'front' | 'pierce' | 'ally'
  final int energyCost;
  final int cooldownMax;
  final int cooldownRemaining;
  final bool isReady;
  final bool canAfford;
  final String
      effectIconKey; // 'damage'|'heal'|'shield'|'poison'|'burn'|'stun'|etc.
  final int effectIconValue; // primary numeric value shown alongside icon
  final int shieldAmount;

  const TraitViewModel({
    required this.id,
    required this.name,
    required this.description,
    required this.typeName,
    required this.partName,
    required this.effectSummary,
    required this.targetSummary,
    required this.targetingMode,
    required this.energyCost,
    required this.cooldownMax,
    required this.cooldownRemaining,
    required this.isReady,
    required this.canAfford,
    this.effectIconKey = 'damage',
    this.effectIconValue = 0,
    this.shieldAmount = 0,
  });

  bool get isUsable => isReady && canAfford;

  factory TraitViewModel.fromTrait(Trait t, Pet owner,
          {int? availableEnergy}) =>
      TraitViewModel(
        id: t.id,
        name: t.name,
        description: t.description,
        typeName: t.type.name,
        partName: t.part.name,
        effectSummary: _effectSummary(t),
        targetSummary: _targetSummary(t.effect.target),
        targetingMode: _targetingMode(t.effect.target),
        energyCost: t.energyCost,
        cooldownMax: t.cooldownMax,
        cooldownRemaining: t.cooldownRemaining,
        isReady: t.isReady,
        canAfford: availableEnergy != null
            ? availableEnergy >= t.energyCost
            : owner.canAfford(t.energyCost),
        effectIconKey: _iconKey(t),
        effectIconValue: t.effect.value,
        shieldAmount: _shieldAmount(t),
      );

  static String _iconKey(Trait t) {
    final e = t.effect;
    return switch (e.type) {
      EffectType.damage => 'damage',

      EffectType.heal => 'heal',
      EffectType.shield => 'shield',
      EffectType.shieldBreak => 'shield_break',
      EffectType.buff => switch (e.buffType) {
          BuffType.attackUp => 'atk_up',
          BuffType.defenseUp => 'def_up',
          BuffType.speedUp => 'spd_up',
          BuffType.moraleUp => 'morale_up',
          BuffType.energized => 'energized',
          BuffType.regen => 'regen',
          null => 'buff',
        },
      EffectType.debuff => switch (e.debuffType) {
          DebuffType.stunned => 'stun',
          DebuffType.poisoned => 'poison',
          DebuffType.attackDown => 'atk_down',
          DebuffType.defenseDown => 'def_down',
          DebuffType.burned => 'burn',
          DebuffType.sleep => 'sleep',
          DebuffType.fear => 'fear',
          DebuffType.aroma => 'aroma',
          DebuffType.chill => 'chill',
          DebuffType.jinx => 'jinx',
          DebuffType.healBlocked => 'heal_block',
          DebuffType.critBlocked => 'crit_block',
          DebuffType.disabled => 'disabled',
          DebuffType.reflect => 'reflect',
          DebuffType.stench => 'stench',
          DebuffType.speedDown => 'spd_down',
          DebuffType.isolate => 'isolate',
          DebuffType.moraleDown => 'morale_down',
          DebuffType.fragile => 'fragile',
          DebuffType.lethal => 'lethal',
          null => 'debuff',
        },
    };
  }

  static String _effectSummary(Trait t) {
    final e = t.effect;
    final shd = e.selfShield > 0 ? ' +${e.selfShield}SHD' : '';
    return switch (e.type) {
      EffectType.damage => '${e.value} DMG$shd',

      EffectType.heal => 'HEAL ${e.value}',
      EffectType.shield => 'SHIELD ${e.value}',
      EffectType.shieldBreak =>
        e.value > 0 ? 'BREAK + SHIELD ${e.value}' : 'SHIELD BREAK',
      EffectType.buff => switch (e.buffType) {
          BuffType.attackUp => 'ATK +${e.value}',
          BuffType.defenseUp => 'DEF +${e.value}',
          BuffType.speedUp => 'SPD +${e.value}',
          BuffType.moraleUp => 'MORALE UP',
          BuffType.energized => 'EN +${e.value}',
          BuffType.regen => 'REGEN ${e.value}/r',
          null => 'BUFF +${e.value}',
        },
      EffectType.debuff => (switch (e.debuffType) {
            DebuffType.stunned => 'STUN',
            DebuffType.poisoned => 'PSN ${e.value}',
            DebuffType.attackDown => 'ATK -${e.value}',
            DebuffType.defenseDown => 'DEF -${e.value}',
            DebuffType.burned => 'BURN ${e.value}',
            DebuffType.sleep => 'SLEEP',
            DebuffType.fear => 'FEAR',
            DebuffType.aroma => 'AROMA',
            DebuffType.chill => 'CHILL',
            DebuffType.jinx => 'JINX',
            DebuffType.healBlocked => 'HEAL BLOCK',
            DebuffType.critBlocked => 'CRIT BLOCK',
            DebuffType.disabled => 'DISABLED',
            DebuffType.reflect => 'REFLECT',
            DebuffType.stench => 'STENCH ${e.duration}',
            DebuffType.speedDown => 'SLOW',
            DebuffType.isolate => 'ISOLATE',
            DebuffType.moraleDown => 'MORALE DOWN',
            DebuffType.fragile => 'FRAGILE',
            DebuffType.lethal => 'LETHAL',
            null => 'DEBUFF',
          }) +
          shd,
    };
  }

  static int _shieldAmount(Trait t) {
    final e = t.effect;
    if (e.type == EffectType.shield) {
      return (e.value + e.selfShield).clamp(0, 999);
    }
    return e.selfShield.clamp(0, 999);
  }

  static String _targetSummary(String target) => switch (target) {
        'enemy' => 'Front',
        'lowest_hp_enemy' => 'Weakest',
        'back_enemy' => 'Back Row',
        'all_enemies' => 'All Foes',
        'self' => 'Self',
        'lowest_hp_ally' => 'Ally',
        'all_allies' => 'All Allies',
        _ => target,
      };

  static String _targetingMode(String target) => switch (target) {

        'lowest_hp_enemy' || 'back_enemy' => 'pierce',
        'all_allies' || 'lowest_hp_ally' => 'ally',
        _ => 'front',
      };
}

// ── CardViewModel ─────────────────────────────────────────────────────────────

const _kPetClass = {
  'plant_1': 'plant',
  'aquatic_1': 'aquatic',
  'beast_1': 'beast',
  'reptile_1': 'reptile',
  'bird_1': 'bird',
  'bug_1': 'bug',
};

const _kTypePart = {
  'offensive': 'horn',
  'defensive': 'back',
  'support': 'tail',
  'utility': 'mouth',
};

const _kPartAsset = {
  'horn': 'horn',
  'back': 'back',
  'tail': 'tail',
  'mouth': 'mouth',
  'body': 'back',
};

// Card-art variant number derived from the Spine skeleton name for each creature:
//   04-ena-plant, 03-puffy-aquatic (→04 nearest), 05-dps-beast (→04 nearest),
//   08-machito-reptile, 12-momo-bird, 06-pomodoro-bug
const _kPetVariant = {
  'plant_1': '04',
  'aquatic_1': '04',
  'beast_1': '04',
  'reptile_1': '08',
  'bird_1': '12',
  'bug_1': '06',
};

// Pet class → color mapping for card badges and visual identity
const _kPetClassColor = {
  'plant': Color(0xFF2ECC71), // Green
  'aquatic': Color(0xFF3498DB), // Blue
  'beast': Color(0xFFE74C3C), // Red/Orange-Red
  'reptile': Color(0xFF66BB6A), // Light Green
  'bird': Color(0xFFFF80AB), // Pink
  'bug': Color(0xFFFF5252), // Bright Red
};

class CardViewModel {
  final String instanceId;
  final String ownerPetId;
  final String ownerPetName;
  final bool isPity;
  final TraitViewModel trait;
  final String? cardArtPath;

  /// Full Axie-style card-frame PNG for this skill.
  /// Path: `assets/images/cards/{class}/{name}.png`
  final String? cardTemplatePath;

  const CardViewModel({
    required this.instanceId,
    required this.ownerPetId,
    required this.ownerPetName,
    required this.trait,
    this.isPity = false,
    this.cardArtPath,
    this.cardTemplatePath,
  });

  /// Display name combining pet name and skill name: "[Pet Name] - [Skill Name]"
  /// This strengthens pet identity and makes card ownership clear.
  String get displayName => '$ownerPetName - ${trait.name}';

  /// Pity cards are visually flagged with a star (★).
  String get displayNameWithPity => isPity ? '★ $displayName' : displayName;

  /// Pet class color for visual identity (badge color on card).
  Color get petColor {
    final petClass = _kPetClass[ownerPetId] ?? 'beast';
    return _kPetClassColor[petClass] ?? const Color(0xFF9C27B0);
  }

  static String? _resolveArt(
    String ownerPetId,
    String traitType,
    String traitPart,
    String rarity,
  ) {
    final cls = _kPetClass[ownerPetId];
    final part = _kPartAsset[traitPart] ?? _kTypePart[traitType];
    // Use the creature-specific card variant so art matches the Spine character.
    final variant = _kPetVariant[ownerPetId] ?? '04';
    if (cls == null || part == null) return null;
    return 'assets/images/part-cards/$cls-$part-$variant.png';
  }

  factory CardViewModel.fromCard(
    SkillCard card,
    Pet owner, {
    int? availableEnergy,
    String? cardArtPathOverride,
  }) {
    final trait = TraitViewModel.fromTrait(card.trait, owner,
        availableEnergy: availableEnergy);
    final resolvedArtPath = cardArtPathOverride ??
        _resolveArt(
          card.ownerPetId,
          trait.typeName,
          trait.partName,
          card.trait.rarity.name,
        );
    return CardViewModel(
      instanceId: card.instanceId,
      ownerPetId: card.ownerPetId,
      ownerPetName: owner.name,
      isPity: card.isPity,
      trait: trait,
      // Player pets supply exact art from their part definition;
      // fall back to the class-based lookup for registry (enemy) pets.
      cardArtPath: resolvedArtPath,
      cardTemplatePath: _resolveClassicTemplateFromCardArt(resolvedArtPath) ??
          _resolveTemplate(card.trait),
    );
  }

  /// Fallback template lookup by trait ID (used when no part-card mapping exists).
  static String? _resolveTemplate(Trait trait) =>
      TraitCardCatalog.templatePathForTrait(trait);

  /// Converts part-card art path to matching Axie Classic card template path.
  /// Example:
  ///   assets/images/part-cards/beast-horn-04.png
  ///   -> assets/images/classic-cards/beast-horn-04.png
  static String? _resolveClassicTemplateFromCardArt(String? cardArtPath) {
    if (cardArtPath == null || cardArtPath.isEmpty) return null;
    final file = cardArtPath.split('/').last;
    final m = RegExp(
      r'^(beast|bug|bird|plant|aquatic|reptile)-(horn|back|tail|mouth)-(\d{2})\.png$',
    ).firstMatch(file);
    if (m == null) return null;
    final id = '${m.group(1)}-${m.group(2)}-${m.group(3)}';
    return 'assets/images/classic-cards/$id.png';
  }
}

// ── TurnOrderEntry ────────────────────────────────────────────────────────────

class TurnOrderEntry {
  final String petId;
  final String name;
  final int speed;
  final int hp;     // tiebreaker: lowest hp acts first
  final int skill;  // tiebreaker: highest skill acts first
  final int morale; // tiebreaker: highest morale acts first
  final bool isPlayer;
  final bool isFainted;
  final String? texturePath; // avatar shown in the attack-order HUD strip

  const TurnOrderEntry({
    required this.petId,
    required this.name,
    required this.speed,
    this.hp    = 0,
    this.skill  = 0,
    this.morale = 0,
    required this.isPlayer,
    required this.isFainted,
    this.texturePath,
  });
}

// ── PetViewModel ──────────────────────────────────────────────────────────────

class PetViewModel {
  final String id;
  final String name;
  final int hp;
  final int maxHp;
  final int energy;
  final int maxEnergy;
  final int shield;
  final int speed;
  final int position; // 0=front, 1=mid, 2=back
  final bool isFainted;
  final bool isStunned;
  final bool isPoisoned;
  final int morale;
  final int skill;

  /// Active buff type names  — e.g. ['attackUp', 'speedUp', 'regen']
  final List<String> activeBuffs;

  /// Active debuff type names — e.g. ['poisoned', 'burned', 'speedDown']
  final List<String> activeDebuffs;

  /// Remaining rounds per debuff type, keyed by debuff name.
  final Map<String, int> debuffRoundsRemaining;

  /// Current poison stack count (0 = not poisoned, 1–13 = stacks).
  final int poisonStacks;
  final List<TraitViewModel> traits;
  final PetSpriteConfig? spriteConfig;

  /// Card art path for each part slot. Key = 'horn'|'back'|'tail'|'mouth'.
  final Map<String, String> partCardArt;

  /// Full creature definition — used to render via PetRendererWidget.
  final CreatureDefinition? creatureDef;

  /// Axie classic Last Stand — pet is at 0 HP but still fighting on morale.
  final bool isInLastStand;
  final int lastStandTicks; // remaining turns in Last Stand (1–4)

  /// 3×3 lane (0=upper, 1=center, 2=lower) — used for visual y-offset within a row.
  final int lane;

  const PetViewModel({
    required this.id,
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.energy,
    required this.maxEnergy,
    required this.shield,
    required this.speed,
    required this.position,
    required this.isFainted,
    required this.isStunned,
    required this.isPoisoned,
    this.morale = 20,
    this.skill = 20,
    this.activeBuffs = const [],
    this.activeDebuffs = const [],
    this.debuffRoundsRemaining = const {},
    this.poisonStacks = 0,
    required this.traits,
    this.spriteConfig,
    this.partCardArt = const {},
    this.creatureDef,
    this.isInLastStand = false,
    this.lastStandTicks = 0,
    this.lane = 1,
  });

  double get hpPercent => maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;

  int debuffRoundsFor(String debuffType) => debuffRoundsRemaining[debuffType] ?? 0;

  String get positionLabel => switch (position) {
        0 => 'FRONT',
        1 => 'MID',
        _ => 'BACK',
      };

  factory PetViewModel.fromSnapshot(
    PetSnapshot snap,
    List<Trait> liveTraits,
    Pet livePet,
    int position, {
    PetSpriteConfig? spriteConfig,
    Map<String, String> partCardArt = const {},
    CreatureDefinition? creatureDef,
  }) =>
      PetViewModel(
        id: snap.id,
        name: snap.name,
        hp: snap.hp,
        maxHp: snap.maxHp,
        energy: snap.energy,
        maxEnergy: kEnergyCap,
        shield: snap.shield,
        speed: livePet.speed,
        position: position,
        isFainted: snap.isFainted,
        isStunned: snap.isStunned,
        isPoisoned: snap.debuffs.any((d) => d.type == 'poisoned'),
        morale: snap.morale,
        skill: snap.skill,
        activeBuffs: snap.buffs.map((b) => b.type).toList(),
        activeDebuffs: snap.debuffs.map((d) => d.type).toList(),
        debuffRoundsRemaining: {
          for (final d in snap.debuffs)
            d.type: (snap.debuffs
                    .where((x) => x.type == d.type)
                    .fold<int>(0, (maxValue, x) =>
                        x.roundsRemaining > maxValue ? x.roundsRemaining : maxValue)),
        },
        poisonStacks: snap.debuffs
            .where((d) => d.type == 'poisoned')
            .fold(0, (s, d) => d.value),
        traits: liveTraits
            .map((t) => TraitViewModel.fromTrait(t, livePet))
            .toList(),
        spriteConfig: spriteConfig,
        partCardArt: partCardArt,
        creatureDef: creatureDef,
        isInLastStand: snap.isInLastStand,
        lastStandTicks: snap.lastStandTicks,
        lane: livePet.lane,
      );

  factory PetViewModel.initial(
    String id,
    String name,
    int speed,
    int position,
    List<Trait> traits,
    Pet livePet, {
    PetSpriteConfig? spriteConfig,
    Map<String, String> partCardArt = const {},
    CreatureDefinition? creatureDef,
  }) =>
      PetViewModel(
        id: id,
        name: name,
        hp: livePet.maxHp,
        maxHp: livePet.maxHp,
        energy: kBaseEnergy,
        maxEnergy: kEnergyCap,
        shield: 0,
        speed: speed,
        position: position,
        isFainted: false,
        isStunned: false,
        isPoisoned: false,
        morale: livePet.morale,
        skill: livePet.skill,
        traits:
            traits.map((t) => TraitViewModel.fromTrait(t, livePet)).toList(),
        spriteConfig: spriteConfig,
        partCardArt: partCardArt,
        creatureDef: creatureDef,
        lane: livePet.lane,
      );
}

// ── PveBattleViewModel ────────────────────────────────────────────────────────

class PveBattleViewModel {
  final int currentRound;
  final List<PetViewModel> playerTeam;
  final List<PetViewModel> enemyTeam;
  final String roundLog;
  final bool isBattleOver;
  final String? outcome;
  final String playerTeamName;
  final String enemyTeamName;
  final List<TurnOrderEntry> turnOrder;

  final String? selectedPetId;

  /// petId → list of cardInstanceIds assigned this round
  final Map<String, List<String>> pendingSkills;
  final bool isResolving;

  /// During resolve: actor pet id whose queued cards are being shown under
  /// attack-order HUD. Null when no card queue is currently displayed.
  final String? resolvingCardPetId;

  /// During resolve: remaining card names for [resolvingCardPetId] in the
  /// exact execution order for this unit turn.
  final List<ResolvingCardItem> resolvingCardQueue;

  final List<CardViewModel> hand;
  final int deckDrawSize;
  final int deckDiscardSize;

  final int playerTeamEnergy;
  final int enemyTeamEnergy;
  final bool isBloodMoon;

  final bool needsDiscard;
  final int excessDiscards;

  final Map<String, PetCharacterAnimState> petAnimStates;
  final Map<String, String> petEffectVfx;

  /// Maps petId → slot name ('horn'|'back'|'tail'|'mouth') while that pet
  /// is animating an attack, so the widget plays the slot-specific Spine clip.
  final Map<String, String> petAttackSlots;
  final Set<String> newCardIds;

  /// Cards that fizzled mid-round (target died before card resolved).
  final Set<String> fizzledCardIds;

  /// petId → fractional dash offset applied to its Positioned widget.
  /// (0.0–1.0 fractions of battlefield width/height).
  /// Used to slide a melee attacker toward the target and back.
  final Map<String, Offset> petDashOffsets;

  /// actorPetId -> explicit targetPetId for the active melee dash.
  /// Used by the battlefield to keep dash landing on the correct enemy slot
  /// (front/mid/back) for pierce/back-row skills.
  final Map<String, String> petDashTargets;

  // ── Ranged projectile ───────────────────────────────────────────────────────

  /// Incremented each time a new ranged projectile is fired. The HUD watches
  /// this token to spawn exactly one ProjectileWidget per new value.
  final int pendingProjectileToken;

  /// Non-null while a ranged card is animating — the HUD uses these three
  /// fields to position and colour the in-flight projectile widget.
  final String? pendingProjectileActorId;
  final String? pendingProjectileTargetId;

  /// Creature class name ('aquatic'|'beast'|'bird'|'plant'|'reptile'|'bug')
  /// used to pick the placeholder orb colour until real VFX sprites exist.
  final String? pendingProjectileClass;

  // ── PvP extras ──────────────────────────────────────────────────────────────

  /// PvP only: true while waiting for the opponent to lock in their cards.
  final bool awaitingOpponent;

  /// PvP only: non-null when the match has ended and the result is ready.
  final PvpMatchEndData? pvpMatchEnd;

  /// Transient server-authoritative visual event used for damage/heal labels.
  final BattleImpactEvent? lastImpactEvent;

  const PveBattleViewModel({
    required this.currentRound,
    required this.playerTeam,
    required this.enemyTeam,
    required this.roundLog,
    required this.isBattleOver,
    required this.playerTeamName,
    required this.enemyTeamName,
    this.outcome,
    this.turnOrder = const [],
    this.selectedPetId,
    this.pendingSkills = const {},
    this.isResolving = false,
    this.resolvingCardPetId,
    this.resolvingCardQueue = const [],
    this.hand = const [],
    this.deckDrawSize = 0,
    this.deckDiscardSize = 0,
    this.playerTeamEnergy = kTeamEnergyStart,
    this.enemyTeamEnergy = kTeamEnergyStart,
    this.isBloodMoon = false,
    this.needsDiscard = false,
    this.excessDiscards = 0,
    this.petAnimStates = const {},
    this.petEffectVfx = const {},
    this.petAttackSlots = const {},
    this.newCardIds = const {},
    this.fizzledCardIds = const {},
    this.petDashOffsets = const {},
    this.petDashTargets = const {},
    this.pendingProjectileToken = 0,
    this.pendingProjectileActorId,
    this.pendingProjectileTargetId,
    this.pendingProjectileClass,
    this.awaitingOpponent = false,
    this.pvpMatchEnd,
    this.lastImpactEvent,
  });

  bool get allSkillsAssigned {
    final living = playerTeam.where((p) => !p.isFainted);
    return living.every((p) =>
        pendingSkills.containsKey(p.id) && pendingSkills[p.id]!.isNotEmpty);
  }

  /// Total energy that would be consumed by currently selected cards.
  int get plannedEnergySpent {
    if (pendingSkills.isEmpty || hand.isEmpty) return 0;
    final selectedIds = pendingSkills.values.expand((ids) => ids).toSet();
    if (selectedIds.isEmpty) return 0;
    return hand
        .where((c) => selectedIds.contains(c.instanceId))
        .fold(0, (sum, c) => sum + c.trait.energyCost);
  }

  /// Remaining team energy after applying selected-card planning.
  int get plannedRemainingEnergy =>
      (playerTeamEnergy - plannedEnergySpent).clamp(0, kTeamEnergyCap);

  List<CardViewModel> get selectedPetCards => hand;

  int cardsInHandFor(String petId) =>
      hand.where((c) => c.ownerPetId == petId).length;

  /// All instance IDs assigned to a given pet this round.
  List<String> assignedCardsFor(String petId) =>
      pendingSkills[petId] ?? const [];

  factory PveBattleViewModel.initial() => const PveBattleViewModel(
        currentRound: 1,
        playerTeam: [],
        enemyTeam: [],
        roundLog: '',
        isBattleOver: false,
        playerTeamName: '',
        enemyTeamName: '',
      );

  PveBattleViewModel copyWith({
    int? currentRound,
    List<PetViewModel>? playerTeam,
    List<PetViewModel>? enemyTeam,
    String? roundLog,
    bool? isBattleOver,
    String? outcome,
    String? playerTeamName,
    String? enemyTeamName,
    List<TurnOrderEntry>? turnOrder,
    String? selectedPetId,
    Map<String, List<String>>? pendingSkills,
    bool? isResolving,
    String? resolvingCardPetId,
    List<ResolvingCardItem>? resolvingCardQueue,
    bool clearResolvingCardQueue = false,
    List<CardViewModel>? hand,
    int? deckDrawSize,
    int? deckDiscardSize,
    int? playerTeamEnergy,
    int? enemyTeamEnergy,
    bool? isBloodMoon,
    bool? needsDiscard,
    int? excessDiscards,
    Map<String, PetCharacterAnimState>? petAnimStates,
    Map<String, String>? petEffectVfx,
    Map<String, String>? petAttackSlots,
    Set<String>? newCardIds,
    Set<String>? fizzledCardIds,
    Map<String, Offset>? petDashOffsets,
    Map<String, String>? petDashTargets,
    int? pendingProjectileToken,
    bool clearPendingProjectile = false,
    String? pendingProjectileActorId,
    String? pendingProjectileTargetId,
    String? pendingProjectileClass,
    bool? awaitingOpponent,
    PvpMatchEndData? pvpMatchEnd,
    BattleImpactEvent? lastImpactEvent,
    bool clearSelectedPet = false,
  }) =>
      PveBattleViewModel(
        currentRound: currentRound ?? this.currentRound,
        playerTeam: playerTeam ?? this.playerTeam,
        enemyTeam: enemyTeam ?? this.enemyTeam,
        roundLog: roundLog ?? this.roundLog,
        isBattleOver: isBattleOver ?? this.isBattleOver,
        outcome: outcome ?? this.outcome,
        playerTeamName: playerTeamName ?? this.playerTeamName,
        enemyTeamName: enemyTeamName ?? this.enemyTeamName,
        turnOrder: turnOrder ?? this.turnOrder,
        selectedPetId:
            clearSelectedPet ? null : (selectedPetId ?? this.selectedPetId),
        pendingSkills: pendingSkills ?? this.pendingSkills,
        isResolving: isResolving ?? this.isResolving,
        resolvingCardPetId: clearResolvingCardQueue
          ? null
          : (resolvingCardPetId ?? this.resolvingCardPetId),
        resolvingCardQueue: clearResolvingCardQueue
          ? const []
          : (resolvingCardQueue ?? this.resolvingCardQueue),
        hand: hand ?? this.hand,
        deckDrawSize: deckDrawSize ?? this.deckDrawSize,
        deckDiscardSize: deckDiscardSize ?? this.deckDiscardSize,
        playerTeamEnergy: playerTeamEnergy ?? this.playerTeamEnergy,
        enemyTeamEnergy: enemyTeamEnergy ?? this.enemyTeamEnergy,
        isBloodMoon: isBloodMoon ?? this.isBloodMoon,
        needsDiscard: needsDiscard ?? this.needsDiscard,
        excessDiscards: excessDiscards ?? this.excessDiscards,
        petAnimStates: petAnimStates ?? this.petAnimStates,
        petEffectVfx: petEffectVfx ?? this.petEffectVfx,
        petAttackSlots: petAttackSlots ?? this.petAttackSlots,
        newCardIds: newCardIds ?? this.newCardIds,
        fizzledCardIds: fizzledCardIds ?? this.fizzledCardIds,
        petDashOffsets: petDashOffsets ?? this.petDashOffsets,
        petDashTargets: petDashTargets ?? this.petDashTargets,
        pendingProjectileToken:
            pendingProjectileToken ?? this.pendingProjectileToken,
        pendingProjectileActorId: clearPendingProjectile
            ? null
            : (pendingProjectileActorId ?? this.pendingProjectileActorId),
        pendingProjectileTargetId: clearPendingProjectile
            ? null
            : (pendingProjectileTargetId ?? this.pendingProjectileTargetId),
        pendingProjectileClass: clearPendingProjectile
            ? null
            : (pendingProjectileClass ?? this.pendingProjectileClass),
        awaitingOpponent: awaitingOpponent ?? this.awaitingOpponent,
        pvpMatchEnd: pvpMatchEnd ?? this.pvpMatchEnd,
        lastImpactEvent: lastImpactEvent ?? this.lastImpactEvent,
      );
}
