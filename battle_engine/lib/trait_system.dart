import 'pet.dart';
import 'trait.dart';

/// Central authority on trait legality, metadata, and ID-based lookup.
///
/// Responsibilities:
///   - Validate whether a pet can legally use a trait right now
///   - Provide human-readable effect descriptions for UI tooltips
///   - Map trait IDs to fresh Trait instances (used by MonsterFactory
///     and Firebase snapshot reconstruction)
///
/// Flutter integration:
///   TraitSystem().describe(trait) → tooltip text in TraitActionBar widget.
///   TraitSystem().canUse(trait, pet) → gates the "use" button enabled state.
///   TraitSystem().getById(id) → rebuilds traits from Firestore snapshots.
///
/// Singleton pattern: use TraitSystem() anywhere — returns the same instance.
class TraitSystem {
  static final TraitSystem _instance = TraitSystem._();
  factory TraitSystem() => _instance;
  TraitSystem._();

  // ── Validation ─────────────────────────────────────────────────────────────

  /// Returns null if [actor] can legally use [trait] right now.
  /// Returns a human-readable error string if it cannot.
  ///
  /// Call this before rendering trait buttons to set their enabled state.
  String? validate(Trait trait, Pet actor) {
    if (actor.isFainted) return '${actor.name} has fainted';
    if (actor.isStunned) return '${actor.name} is stunned this round';
    if (!trait.isReady) {
      return '${trait.name} on cooldown (${trait.cooldownRemaining} rounds left)';
    }
    if (!actor.canAfford(trait.energyCost)) {
      return 'Need ${trait.energyCost} energy — ${actor.name} has ${actor.energy}';
    }
    return null;
  }

  bool canUse(Trait trait, Pet actor) => validate(trait, actor) == null;

  // ── Human-readable descriptions ────────────────────────────────────────────

  /// One-line description for UI tooltip. Format: [cost/cd] effect details.
  ///
  /// Example: "[2E · CD:1] Deal 50 damage to the lowest-HP enemy."
  String describe(Trait trait) {
    final e = trait.effect;
    final cost = '${trait.energyCost}E';
    final cd = trait.cooldownMax > 0 ? ' · CD:${trait.cooldownMax}' : '';
    final part = trait.part.name.toUpperCase();
    final prefix = '[$part · $cost$cd] ';

    return switch (e.type) {
      EffectType.damage =>
        '${prefix}Deal ${e.value} damage to ${_targetLabel(e.target)}.',
      EffectType.aoe =>
        '${prefix}Deal ${e.value} AoE damage to ${_targetLabel(e.target)}.',
      EffectType.heal =>
        '${prefix}Restore ${e.value} HP to ${_targetLabel(e.target)}.',
      EffectType.shield =>
        '${prefix}Grant ${e.value} shield to ${_targetLabel(e.target)}.',
      EffectType.shieldBreak =>
        '${prefix}Break enemy shield + grant ${e.value} shield to self.',
      EffectType.buff =>
        '${prefix}${_buffLabel(e)} to ${_targetLabel(e.target)} for ${e.duration} rounds.',
      EffectType.debuff =>
        '${prefix}${_debuffLabel(e)} on ${_targetLabel(e.target)} for ${e.duration} rounds.',
    };
  }

  // ── Trait registry (ID → Trait) ────────────────────────────────────────────
  //
  // Each entry is a factory function that returns a fresh Trait instance.
  // Trait has mutable state (cooldownRemaining), so we never cache instances.
  //
  // Firebase/PvE integration:
  //   MonsterFactory calls getById(id) to rebuild a monster's trait list
  //   from the 'traits' array in a monsters/{monsterId} Firestore document.
  //   The Cloud Function also uses this registry to validate submitted actions.

  static final Map<String, Trait Function()> _registry = {
    // Axie class-based skills (6 classes × 4 parts)
    'beast_horn': () => TraitLibrary.beastHorn,
    'beast_back': () => TraitLibrary.beastBack,
    'beast_tail': () => TraitLibrary.beastTail,
    'beast_mouth': () => TraitLibrary.beastMouth,
    'plant_horn': () => TraitLibrary.plantHorn,
    'plant_back': () => TraitLibrary.plantBack,
    'plant_tail': () => TraitLibrary.plantTail,
    'plant_mouth': () => TraitLibrary.plantMouth,
    'aquatic_horn': () => TraitLibrary.aquaticHorn,
    'aquatic_back': () => TraitLibrary.aquaticBack,
    'aquatic_tail': () => TraitLibrary.aquaticTail,
    'aquatic_mouth': () => TraitLibrary.aquaticMouth,
    'bird_horn': () => TraitLibrary.birdHorn,
    'bird_back': () => TraitLibrary.birdBack,
    'bird_tail': () => TraitLibrary.birdTail,
    'bird_mouth': () => TraitLibrary.birdMouth,
    'bug_horn': () => TraitLibrary.bugHorn,
    'bug_back': () => TraitLibrary.bugBack,
    'bug_tail': () => TraitLibrary.bugTail,
    'bug_mouth': () => TraitLibrary.bugMouth,
    'reptile_horn': () => TraitLibrary.reptileHorn,
    'reptile_back': () => TraitLibrary.reptileBack,
    'reptile_tail': () => TraitLibrary.reptileTail,
    'reptile_mouth': () => TraitLibrary.reptileMouth,
  };

  /// Returns a fresh [Trait] instance for the given [id].
  /// Throws [ArgumentError] if the ID is not registered.
  Trait getById(String id) {
    final factory = _registry[id];
    if (factory == null) throw ArgumentError('Unknown trait id: "$id"');
    return factory();
  }

  bool isRegistered(String id) => _registry.containsKey(id);

  List<String> get allTraitIds => List.unmodifiable(_registry.keys);

  /// Build a full trait list from a list of IDs.
  /// Used by MonsterFactory and Firebase pet snapshot reconstruction.
  List<Trait> buildTraitList(List<String> ids) => ids.map(getById).toList();

  // ── Card template metadata ─────────────────────────────────────────────────
  // Assets live under:
  //   assets/images/card-templates/en/cards/<class>/<name>.png
  static const String _cardTemplateBasePath =
      'assets/images/card-templates/en/cards';

  static const Map<String, ({String cardClass, String imageName})>
      _traitCardTemplate = {
    'beast_horn': (cardClass: 'beast', imageName: 'dual blade'),
    'beast_back': (cardClass: 'beast', imageName: 'ronin'),
    'beast_tail': (cardClass: 'beast', imageName: 'buba brush'),
    'beast_mouth': (cardClass: 'beast', imageName: 'axie kiss'),
    'plant_horn': (cardClass: 'plant', imageName: 'cactus'),
    'plant_back': (cardClass: 'plant', imageName: 'pumpkin'),
    'plant_tail': (cardClass: 'plant', imageName: 'cattail'),
    'plant_mouth': (cardClass: 'plant', imageName: 'serious'),
    'aquatic_horn': (cardClass: 'aquatic', imageName: 'lam'),
    'aquatic_back': (cardClass: 'aquatic', imageName: 'sponge'),
    'aquatic_tail': (cardClass: 'aquatic', imageName: 'koi'),
    'aquatic_mouth': (cardClass: 'aquatic', imageName: 'catfish'),
    'bird_horn': (cardClass: 'bird', imageName: 'eggshell'),
    'bird_back': (cardClass: 'bird', imageName: 'feather spear'),
    'bird_tail': (cardClass: 'bird', imageName: 'pigeon post'),
    'bird_mouth': (cardClass: 'bird', imageName: 'doubletalk'),
    'bug_horn': (cardClass: 'bug', imageName: 'pincer'),
    'bug_back': (cardClass: 'bug', imageName: 'lagging'),
    'bug_tail': (cardClass: 'bug', imageName: 'twin tail'),
    'bug_mouth': (cardClass: 'bug', imageName: 'square teeth'),
    'reptile_horn': (cardClass: 'reptile', imageName: 'cerastes'),
    'reptile_back': (cardClass: 'reptile', imageName: 'bone sail'),
    'reptile_tail': (cardClass: 'reptile', imageName: 'wall gecko'),
    'reptile_mouth': (cardClass: 'reptile', imageName: 'toothless bite'),
  };

  String? cardTemplatePathForId(String id) {
    final meta = _traitCardTemplate[id];
    if (meta == null) return null;
    return '$_cardTemplateBasePath/${meta.cardClass}/${meta.imageName}.png';
  }

  String? cardTemplatePathForTrait(Trait trait) =>
      cardTemplatePathForId(trait.id);

  ({String cardClass, String imageName})? cardTemplateMetaForId(String id) =>
      _traitCardTemplate[id];

  List<Trait> get allTraits => allTraitIds.map(getById).toList(growable: false);

  // ── Private helpers ────────────────────────────────────────────────────────

  String _targetLabel(String target) => switch (target) {
        'enemy' => 'front enemy',
        'lowest_hp_enemy' => 'weakest enemy (pierces)',
        'back_enemy' => 'back row enemy (pierces)',
        'all_enemies' => 'all enemies',
        'self' => 'self',
        'lowest_hp_ally' => 'the lowest-HP ally',
        'all_allies' => 'all allies',
        _ => target,
      };

  String _buffLabel(TraitEffect e) => switch (e.buffType) {
        BuffType.attackUp => 'Raise Attack +${e.value}',
        BuffType.defenseUp => 'Raise Defense +${e.value}',
        BuffType.speedUp => 'Raise Speed +${e.value}',
        BuffType.energized => 'Gain +${e.value} bonus energy/round',
        BuffType.regen => 'Regenerate ${e.value} HP/round',
        null => 'Apply buff +${e.value}',
      };

  String _debuffLabel(TraitEffect e) => switch (e.debuffType) {
        DebuffType.attackDown => 'Reduce Attack −${e.value}',
        DebuffType.defenseDown => 'Reduce Defense −${e.value}',
        DebuffType.stunned => 'Stun (skip 1 turn)',
        DebuffType.poisoned => 'Inflict Poison (${e.value} dmg/round)',
        DebuffType.burned =>
          'Inflict Burn (${e.value} dmg/round, ignores shield)',
        DebuffType.speedDown => 'Reduce Speed (acts last 1 round)',
        null => 'Apply debuff −${e.value}',
      };
}
