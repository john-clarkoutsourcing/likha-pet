import 'package:likha_pet_battle_engine/battle_state.dart';
import 'package:likha_pet_battle_engine/energy_pool.dart';
import 'package:likha_pet_battle_engine/pet.dart';
import 'package:likha_pet_battle_engine/skill_card.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../widgets/pet_character_widget.dart' show PetCharacterConfig, PetCharacterAnimState;
import '../widgets/pet_sprite_widget.dart' show PetSpriteConfig;

// ── TraitViewModel ────────────────────────────────────────────────────────────

class TraitViewModel {
  final String id;
  final String name;
  final String description;
  final String typeName;
  final String partName;
  final String effectSummary;
  final String targetSummary;
  final String targetingMode; // 'front' | 'pierce' | 'aoe' | 'ally'
  final int    energyCost;
  final int    cooldownMax;
  final int    cooldownRemaining;
  final bool   isReady;
  final bool   canAfford;
  final String effectIconKey;   // 'damage'|'aoe'|'heal'|'shield'|'poison'|'burn'|'stun'|etc.
  final int    effectIconValue; // primary numeric value shown alongside icon

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
    this.effectIconKey   = 'damage',
    this.effectIconValue = 0,
  });

  bool get isUsable => isReady && canAfford;

  factory TraitViewModel.fromTrait(Trait t, Pet owner, {int? availableEnergy}) =>
      TraitViewModel(
        id:               t.id,
        name:             t.name,
        description:      t.description,
        typeName:         t.type.name,
        partName:         t.part.name,
        effectSummary:    _effectSummary(t),
        targetSummary:    _targetSummary(t.effect.target),
        targetingMode:    _targetingMode(t.effect.target),
        energyCost:       t.energyCost,
        cooldownMax:      t.cooldownMax,
        cooldownRemaining: t.cooldownRemaining,
        isReady:          t.isReady,
        canAfford: availableEnergy != null
            ? availableEnergy >= t.energyCost
            : owner.canAfford(t.energyCost),
        effectIconKey:   _iconKey(t),
        effectIconValue: t.effect.value,
      );

  static String _iconKey(Trait t) {
    final e = t.effect;
    return switch (e.type) {
      EffectType.damage      => 'damage',
      EffectType.aoe         => 'aoe',
      EffectType.heal        => 'heal',
      EffectType.shield      => 'shield',
      EffectType.shieldBreak => 'shield_break',
      EffectType.buff => switch (e.buffType) {
        BuffType.attackUp  => 'atk_up',
        BuffType.defenseUp => 'def_up',
        BuffType.speedUp   => 'spd_up',
        BuffType.energized => 'energized',
        BuffType.regen     => 'regen',
        null               => 'buff',
      },
      EffectType.debuff => switch (e.debuffType) {
        DebuffType.stunned     => 'stun',
        DebuffType.poisoned    => 'poison',
        DebuffType.attackDown  => 'atk_down',
        DebuffType.defenseDown => 'def_down',
        DebuffType.burned      => 'burn',
        DebuffType.speedDown   => 'spd_down',
        null                   => 'debuff',
      },
    };
  }

  static String _effectSummary(Trait t) {
    final e = t.effect;
    final shd = e.selfShield > 0 ? ' +${e.selfShield}SHD' : '';
    return switch (e.type) {
      EffectType.damage      => '${e.value} DMG$shd',
      EffectType.aoe         => '${e.value} AoE$shd',
      EffectType.heal        => 'HEAL ${e.value}',
      EffectType.shield      => 'SHIELD ${e.value}',
      EffectType.shieldBreak => e.value > 0 ? 'BREAK + SHIELD ${e.value}' : 'SHIELD BREAK',
      EffectType.buff => switch (e.buffType) {
        BuffType.attackUp  => 'ATK +${e.value}',
        BuffType.defenseUp => 'DEF +${e.value}',
        BuffType.speedUp   => 'SPD +${e.value}',
        BuffType.energized => 'EN +${e.value}',
        BuffType.regen     => 'REGEN ${e.value}/r',
        null               => 'BUFF +${e.value}',
      },
      EffectType.debuff => (switch (e.debuffType) {
        DebuffType.stunned     => 'STUN',
        DebuffType.poisoned    => 'PSN ${e.value}',
        DebuffType.attackDown  => 'ATK -${e.value}',
        DebuffType.defenseDown => 'DEF -${e.value}',
        DebuffType.burned      => 'BURN ${e.value}',
        DebuffType.speedDown   => 'SLOW',
        null                   => 'DEBUFF',
      }) + shd,
    };
  }

  static String _targetSummary(String target) => switch (target) {
    'enemy'           => 'Front',
    'lowest_hp_enemy' => 'Weakest',
    'back_enemy'      => 'Back Row',
    'all_enemies'     => 'All Foes',
    'self'            => 'Self',
    'lowest_hp_ally'  => 'Ally',
    'all_allies'      => 'All Allies',
    _                 => target,
  };

  static String _targetingMode(String target) => switch (target) {
    'all_enemies'                     => 'aoe',
    'lowest_hp_enemy' || 'back_enemy' => 'pierce',
    'all_allies' || 'lowest_hp_ally'  => 'ally',
    _                                 => 'front',
  };
}

// ── CardViewModel ─────────────────────────────────────────────────────────────

const _kPetClass = {
  'plant_1':   'plant',
  'aquatic_1': 'aquatic',
  'beast_1':   'beast',
  'reptile_1': 'reptile',
  'bird_1':    'bird',
  'bug_1':     'bug',
};

const _kTypePart = {
  'offensive': 'horn', 'defensive': 'back',
  'support':   'tail', 'utility':   'mouth',
};

const _kPartAsset = {
  'horn':  'horn',
  'back':  'back',
  'tail':  'tail',
  'mouth': 'mouth',
  'body':  'back',
};

// Card-art variant number derived from the Spine skeleton name for each creature:
//   04-ena-plant, 03-puffy-aquatic (→04 nearest), 05-dps-beast (→04 nearest),
//   08-machito-reptile, 12-momo-bird, 06-pomodoro-bug
const _kPetVariant = {
  'plant_1':   '04',
  'aquatic_1': '04',
  'beast_1':   '04',
  'reptile_1': '08',
  'bird_1':    '12',
  'bug_1':     '06',
};

class CardViewModel {
  final String         instanceId;
  final String         ownerPetId;
  final String         ownerPetName;
  final bool           isPity;
  final TraitViewModel trait;
  final String?        cardArtPath;

  const CardViewModel({
    required this.instanceId,
    required this.ownerPetId,
    required this.ownerPetName,
    required this.trait,
    this.isPity      = false,
    this.cardArtPath,
  });

  static String? _resolveArt(
    String ownerPetId,
    String traitType,
    String traitPart,
    String rarity,
  ) {
    final cls     = _kPetClass[ownerPetId];
    final part    = _kPartAsset[traitPart] ?? _kTypePart[traitType];
    // Use the creature-specific card variant so art matches the Spine character.
    final variant = _kPetVariant[ownerPetId] ?? '04';
    if (cls == null || part == null) return null;
    return 'assets/images/cards/$cls-$part-$variant.png';
  }

  factory CardViewModel.fromCard(SkillCard card, Pet owner, {int? availableEnergy}) {
    final trait = TraitViewModel.fromTrait(card.trait, owner, availableEnergy: availableEnergy);
    return CardViewModel(
      instanceId:   card.instanceId,
      ownerPetId:   card.ownerPetId,
      ownerPetName: owner.name,
      isPity:       card.isPity,
      trait:        trait,
      cardArtPath:  _resolveArt(
        card.ownerPetId,
        trait.typeName,
        trait.partName,
        card.trait.rarity.name,
      ),
    );
  }
}

// ── TurnOrderEntry ────────────────────────────────────────────────────────────

class TurnOrderEntry {
  final String  petId;
  final String  name;
  final int     speed;
  final bool    isPlayer;
  final bool    isFainted;
  final String? texturePath; // avatar shown in the attack-order HUD strip

  const TurnOrderEntry({
    required this.petId,
    required this.name,
    required this.speed,
    required this.isPlayer,
    required this.isFainted,
    this.texturePath,
  });
}

// ── PetViewModel ──────────────────────────────────────────────────────────────

class PetViewModel {
  final String id;
  final String name;
  final int    hp;
  final int    maxHp;
  final int    energy;
  final int    maxEnergy;
  final int    shield;
  final int    speed;
  final int    position;   // 0=front, 1=mid, 2=back
  final bool   isFainted;
  final bool   isStunned;
  final bool   isPoisoned;
  final int    morale;
  final int    skill;
  /// Active buff type names  — e.g. ['attackUp', 'speedUp', 'regen']
  final List<String> activeBuffs;
  /// Active debuff type names — e.g. ['poisoned', 'burned', 'speedDown']
  final List<String> activeDebuffs;
  /// Current poison stack count (0 = not poisoned, 1–13 = stacks).
  final int poisonStacks;
  final List<TraitViewModel> traits;
  final PetSpriteConfig?     spriteConfig;
  final PetCharacterConfig?  characterConfig;
  /// Card art path for each part slot. Key = 'horn'|'back'|'tail'|'mouth'.
  final Map<String, String>  partCardArt;

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
    this.morale        = 20,
    this.skill         = 20,
    this.activeBuffs   = const [],
    this.activeDebuffs = const [],
    this.poisonStacks  = 0,
    required this.traits,
    this.spriteConfig,
    this.characterConfig,
    this.partCardArt   = const {},
  });

  double get hpPercent => maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;

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
    PetSpriteConfig?    spriteConfig,
    PetCharacterConfig? characterConfig,
    Map<String, String> partCardArt = const {},
  }) =>
      PetViewModel(
        id:        snap.id,
        name:      snap.name,
        hp:        snap.hp,
        maxHp:     snap.maxHp,
        energy:    snap.energy,
        maxEnergy: kEnergyCap,
        shield:    snap.shield,
        speed:     livePet.speed,
        position:  position,
        isFainted:     snap.isFainted,
        isStunned:     snap.isStunned,
        isPoisoned:    snap.debuffs.any((d) => d.type == 'poisoned'),
        morale:        snap.morale,
        skill:         snap.skill,
        activeBuffs:   snap.buffs.map((b) => b.type).toList(),
        activeDebuffs: snap.debuffs.map((d) => d.type).toList(),
        poisonStacks:  snap.debuffs.where((d) => d.type == 'poisoned').fold(0, (s, d) => d.value),
        traits:         liveTraits.map((t) => TraitViewModel.fromTrait(t, livePet)).toList(),
        spriteConfig:    spriteConfig,
        characterConfig: characterConfig,
        partCardArt:     partCardArt,
      );

  factory PetViewModel.initial(
    String id, String name, int speed, int position,
    List<Trait> traits, Pet livePet, {
    PetSpriteConfig?    spriteConfig,
    PetCharacterConfig? characterConfig,
    Map<String, String> partCardArt = const {},
  }) =>
      PetViewModel(
        id:        id,
        name:      name,
        hp:        livePet.maxHp,
        maxHp:     livePet.maxHp,
        energy:    kBaseEnergy,
        maxEnergy: kEnergyCap,
        shield:    0,
        speed:     speed,
        position:  position,
        isFainted:  false,
        isStunned:  false,
        isPoisoned: false,
        morale:     livePet.morale,
        skill:      livePet.skill,
        traits:     traits.map((t) => TraitViewModel.fromTrait(t, livePet)).toList(),
        spriteConfig:    spriteConfig,
        characterConfig: characterConfig,
        partCardArt:     partCardArt,
      );
}

// ── PveBattleViewModel ────────────────────────────────────────────────────────

class PveBattleViewModel {
  final int                currentRound;
  final List<PetViewModel> playerTeam;
  final List<PetViewModel> enemyTeam;
  final String             roundLog;
  final bool               isBattleOver;
  final String?            outcome;
  final String             playerTeamName;
  final String             enemyTeamName;
  final List<TurnOrderEntry> turnOrder;

  final String?                    selectedPetId;
  /// petId → list of cardInstanceIds assigned this round
  final Map<String, List<String>>  pendingSkills;
  final bool                       isResolving;

  final List<CardViewModel> hand;
  final int                 deckDrawSize;
  final int                 deckDiscardSize;

  final int playerTeamEnergy;
  final int enemyTeamEnergy;

  final bool needsDiscard;
  final int  excessDiscards;

  final Map<String, PetCharacterAnimState> petAnimStates;
  final Map<String, String>                petEffectVfx;
  /// Maps petId → slot name ('horn'|'back'|'tail'|'mouth') while that pet
  /// is animating an attack, so the widget plays the slot-specific Spine clip.
  final Map<String, String>                petAttackSlots;
  final Set<String>                        newCardIds;

  const PveBattleViewModel({
    required this.currentRound,
    required this.playerTeam,
    required this.enemyTeam,
    required this.roundLog,
    required this.isBattleOver,
    required this.playerTeamName,
    required this.enemyTeamName,
    this.outcome,
    this.turnOrder           = const [],
    this.selectedPetId,
    this.pendingSkills       = const {},
    this.isResolving         = false,
    this.hand                = const [],
    this.deckDrawSize        = 0,
    this.deckDiscardSize     = 0,
    this.playerTeamEnergy    = kTeamEnergyStart,
    this.enemyTeamEnergy     = kTeamEnergyStart,
    this.needsDiscard        = false,
    this.excessDiscards      = 0,
    this.petAnimStates       = const {},
    this.petEffectVfx        = const {},
    this.petAttackSlots      = const {},
    this.newCardIds          = const {},
  });

  bool get allSkillsAssigned {
    final living = playerTeam.where((p) => !p.isFainted);
    return living.every((p) => pendingSkills.containsKey(p.id) && pendingSkills[p.id]!.isNotEmpty);
  }

  List<CardViewModel> get selectedPetCards => hand;

  int cardsInHandFor(String petId) =>
      hand.where((c) => c.ownerPetId == petId).length;

  /// All instance IDs assigned to a given pet this round.
  List<String> assignedCardsFor(String petId) => pendingSkills[petId] ?? const [];

  factory PveBattleViewModel.initial() => const PveBattleViewModel(
        currentRound:   1,
        playerTeam:     [],
        enemyTeam:      [],
        roundLog:       '',
        isBattleOver:   false,
        playerTeamName: '',
        enemyTeamName:  '',
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
    List<CardViewModel>? hand,
    int? deckDrawSize,
    int? deckDiscardSize,
    int? playerTeamEnergy,
    int? enemyTeamEnergy,
    bool? needsDiscard,
    int? excessDiscards,
    Map<String, PetCharacterAnimState>? petAnimStates,
    Map<String, String>? petEffectVfx,
    Map<String, String>? petAttackSlots,
    Set<String>? newCardIds,
    bool clearSelectedPet = false,
  }) =>
      PveBattleViewModel(
        currentRound:     currentRound    ?? this.currentRound,
        playerTeam:       playerTeam      ?? this.playerTeam,
        enemyTeam:        enemyTeam       ?? this.enemyTeam,
        roundLog:         roundLog        ?? this.roundLog,
        isBattleOver:     isBattleOver    ?? this.isBattleOver,
        outcome:          outcome         ?? this.outcome,
        playerTeamName:   playerTeamName  ?? this.playerTeamName,
        enemyTeamName:    enemyTeamName   ?? this.enemyTeamName,
        turnOrder:        turnOrder       ?? this.turnOrder,
        selectedPetId:    clearSelectedPet ? null : (selectedPetId ?? this.selectedPetId),
        pendingSkills:    pendingSkills   ?? this.pendingSkills,
        isResolving:      isResolving     ?? this.isResolving,
        hand:             hand            ?? this.hand,
        deckDrawSize:     deckDrawSize    ?? this.deckDrawSize,
        deckDiscardSize:  deckDiscardSize ?? this.deckDiscardSize,
        playerTeamEnergy: playerTeamEnergy ?? this.playerTeamEnergy,
        enemyTeamEnergy:  enemyTeamEnergy  ?? this.enemyTeamEnergy,
        needsDiscard:     needsDiscard    ?? this.needsDiscard,
        excessDiscards:   excessDiscards  ?? this.excessDiscards,
        petAnimStates:    petAnimStates   ?? this.petAnimStates,
        petEffectVfx:     petEffectVfx    ?? this.petEffectVfx,
        petAttackSlots:   petAttackSlots  ?? this.petAttackSlots,
        newCardIds:       newCardIds      ?? this.newCardIds,
      );
}
