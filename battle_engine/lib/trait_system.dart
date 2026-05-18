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
    // Vegetal Bite (plant-mouth-02) — energy steal, must be explicit so the
    // regex fallback never uses plantMouth (lifesteal) as the wrong base.
    'plant_mouth_vegetal_bite': () => TraitLibrary.plantMouthVegetalBite,
    'plant_mouth_02': () => TraitLibrary.plantMouthVegetalBite,
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
    // Blood Taste (bug-mouth-02) — must be registered explicitly so the regex
    // fallback never strips lifeSteal by using bugMouth as the base trait.
    'bug_mouth_blood_taste': () => TraitLibrary.bugMouthBloodTaste,
    'bug_mouth_02': () => TraitLibrary.bugMouthBloodTaste,
    'reptile_horn': () => TraitLibrary.reptileHorn,
    'reptile_back': () => TraitLibrary.reptileBack,
    'reptile_tail': () => TraitLibrary.reptileTail,
    'reptile_mouth': () => TraitLibrary.reptileMouth,
  };

  /// Returns a fresh [Trait] instance for the given [id].
  /// Throws [ArgumentError] if the ID is not registered.
  Trait getById(String id) {
    final factory = _registry[id];
    if (factory != null) {
      final baseTrait = factory();
      final cardId = _traitCardTemplate[id];
      if (cardId == null) return baseTrait;
      return TraitLibrary.withClassicCardStats(
        baseTrait: _withPartClassFromCardId(baseTrait, cardId),
        traitId: id,
        cardId: cardId,
      );
    }

    final m = RegExp(
      r'^(beast|bug|bird|plant|aquatic|reptile)_(horn|back|tail|mouth)_(\d{2})$',
    ).firstMatch(id);
    if (m != null) {
      final cls = m.group(1)!;
      final slot = m.group(2)!;
      final variant = m.group(3)!;
      final baseId = '${cls}_$slot';
      final baseFactory = _registry[baseId];
      if (baseFactory != null) {
        final classEnum = CreatureClass.values.firstWhere((c) => c.name == cls);
        final baseTrait = baseFactory().withPartClass(classEnum);
        return TraitLibrary.withClassicCardStats(
          baseTrait: baseTrait,
          traitId: id,
          cardId: '$cls-$slot-$variant',
        );
      }
    }

    throw ArgumentError('Unknown trait id: "$id"');
  }

  bool isRegistered(String id) =>
      _registry.containsKey(id) ||
      RegExp(
        r'^(beast|bug|bird|plant|aquatic|reptile)_(horn|back|tail|mouth)_(\d{2})$',
      ).hasMatch(id);

  List<String> get allTraitIds => List.unmodifiable(_registry.keys);

  /// Build a full trait list from a list of IDs.
  /// Used by MonsterFactory and Firebase pet snapshot reconstruction.
  List<Trait> buildTraitList(List<String> ids) => ids.map(getById).toList();

  // ── Card template metadata ─────────────────────────────────────────────────
  // Assets live under:
  //   assets/images/classic-cards/<class>-<part>-<variant>.png
  static const String _cardTemplateBasePath = 'assets/images/classic-cards';

  static const Map<String, String> _traitCardTemplate = {
    'beast_horn': 'beast-horn-04',
    'beast_back': 'beast-back-04',
    'beast_tail': 'beast-tail-04',
    'beast_mouth': 'beast-mouth-04',
    'plant_horn': 'plant-horn-04',
    'plant_back': 'plant-back-04',
    'plant_tail': 'plant-tail-04',
    'plant_mouth': 'plant-mouth-04',
    'aquatic_horn': 'aquatic-horn-04',
    'aquatic_back': 'aquatic-back-04',
    'aquatic_tail': 'aquatic-tail-04',
    'aquatic_mouth': 'aquatic-mouth-04',
    'bird_horn': 'bird-horn-04',
    'bird_back': 'bird-back-04',
    'bird_tail': 'bird-tail-04',
    'bird_mouth': 'bird-mouth-04',
    'bug_horn': 'bug-horn-04',
    'bug_back': 'bug-back-04',
    'bug_tail': 'bug-tail-04',
    'bug_mouth': 'bug-mouth-04',
    'reptile_horn': 'reptile-horn-04',
    'reptile_back': 'reptile-back-04',
    'reptile_tail': 'reptile-tail-04',
    'reptile_mouth': 'reptile-mouth-04',
    // Tier-2 trait IDs map to the class' 06 variant cards.
    'beast_horn_2': 'beast-horn-06',
    'beast_back_2': 'beast-back-06',
    'plant_horn_2': 'plant-horn-06',
    'plant_back_2': 'plant-back-06',
    'aquatic_horn_2': 'aquatic-horn-06',
    'aquatic_back_2': 'aquatic-back-06',
    'bird_horn_2': 'bird-horn-06',
    'bird_back_2': 'bird-back-06',
    'bug_horn_2': 'bug-horn-06',
    'bug_back_2': 'bug-back-06',
    'reptile_horn_2': 'reptile-horn-06',
    'reptile_back_2': 'reptile-back-06',
  };

  String? cardTemplatePathForId(String id) {
    final cardId = _traitCardTemplate[id];
    if (cardId != null) return '$_cardTemplateBasePath/$cardId.png';

    final m = RegExp(
            r'^(beast|bug|bird|plant|aquatic|reptile)_(horn|back|tail|mouth)_(\d{2})$')
        .firstMatch(id);
    if (m == null) return null;
    final cls = m.group(1)!;
    final part = m.group(2)!;
    final variant = m.group(3)!;
    return '$_cardTemplateBasePath/$cls-$part-$variant.png';
  }

  String? cardTemplatePathForTrait(Trait trait) =>
      cardTemplatePathForId(trait.id);

  ({String cardClass, String imageName})? cardTemplateMetaForId(String id) {
    final cardId = _traitCardTemplate[id];
    if (cardId == null) return null;
    final parts = cardId.split('-');
    if (parts.length < 3) return null;
    return (cardClass: parts[0], imageName: cardId);
  }

  List<Trait> get allTraits => allTraitIds.map(getById).toList(growable: false);

  Trait _withPartClassFromCardId(Trait trait, String cardId) {
    final parts = cardId.split('-');
    if (parts.isEmpty) return trait;
    final cls = parts.first;
    final classEnum = CreatureClass.values.firstWhere(
      (c) => c.name == cls,
      orElse: () => CreatureClass.beast,
    );
    return trait.withPartClass(classEnum);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _targetLabel(String target) => switch (target) {
        'enemy'          => 'front enemy',
        'lowest_hp_enemy'=> 'weakest enemy (pierces)',
        'back_enemy'     => 'back row enemy (pierces)',
        'all_enemies'    => 'all enemies',
        'self'           => 'self',
        'lowest_hp_ally' => 'the lowest-HP ally',
        'all_allies'     => 'all allies',
        'front_ally'     => 'frontline ally',
        _                => target,
      };

  String _buffLabel(TraitEffect e) => switch (e.buffType) {
        BuffType.attackUp => 'Raise Attack +${e.value}',
        BuffType.defenseUp => 'Raise Defense +${e.value}',
        BuffType.speedUp => 'Raise Speed +${e.value}',
        BuffType.moraleUp => 'Morale Up (higher crit chance)',
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
        DebuffType.sleep => 'Sleep (next hit ignores shield)',
        DebuffType.fear => 'Fear (skip an attack)',
        DebuffType.aroma => 'Aroma (forced target)',
        DebuffType.chill => 'Chill (no last stand)',
        DebuffType.jinx => 'Jinx (no crit)',
        DebuffType.healBlocked => 'Heal Block',
        DebuffType.critBlocked => 'Crit Block',
        DebuffType.disabled => 'Disabled',
        DebuffType.reflect => 'Reflect',
        DebuffType.stench => 'Inflict Stench (${e.duration} rounds)',
        DebuffType.speedDown => 'Reduce Speed (acts last 1 round)',
        DebuffType.isolate => 'Isolate (cannot target allies)',
        DebuffType.moraleDown => 'Morale Down (lower crit chance)',
        DebuffType.fragile => 'Fragile (−25% effective defense)',
        DebuffType.lethal => 'Lethal (bypasses Last Stand)',
        null => 'Apply debuff −${e.value}',
      };
}
