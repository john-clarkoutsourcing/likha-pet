import 'package:likha_pet_battle_engine/trait.dart';
import 'package:likha_pet_battle_engine/trait_system.dart';
import 'creature_registry.dart';

/// Card catalog entry built from current Classic part cards.
class TraitCardCatalogEntry {
  final String cardClass;
  final String imageName; // e.g. beast-horn-04
  final String templatePath;
  final String partType; // Horn|Back|Tail|Mouth
  final int energy;
  final int attack;
  final int defense;
  final int healing;
  final String abilityType;
  final String description;
  final Trait trait;
  final String traitId;

  const TraitCardCatalogEntry({
    required this.cardClass,
    required this.imageName,
    required this.templatePath,
    required this.partType,
    required this.energy,
    required this.attack,
    required this.defense,
    required this.healing,
    required this.abilityType,
    required this.description,
    required this.trait,
    required this.traitId,
  });
}

class TraitCardCatalog {
  static final TraitSystem _traitSystem = TraitSystem();

  static const _kClassicBasePath = 'assets/images/classic-cards';

  /// Builds the catalog from current part definitions (Classic card assets).
  static List<TraitCardCatalogEntry> build() {
    final entries = <TraitCardCatalogEntry>[];
    final seen = <String>{};

    for (final part in kPartCatalogue.values) {
      final file = part.cardArtPath.split('/').last.replaceAll('.png', '');
      final tokens = file.split('-');
      if (tokens.length != 3) continue;
      final cardId = '${tokens[0]}-${tokens[1]}-${tokens[2]}';
      if (!seen.add(cardId)) continue;

      final trait = part.buildTrait();
      final effect = trait.effect;

      final attack =
          (effect.type == EffectType.damage || effect.type == EffectType.aoe)
              ? effect.value
              : 0;
      final defense =
          effect.type == EffectType.shield ? effect.value : effect.selfShield;
      final healing = effect.type == EffectType.heal ||
              (effect.type == EffectType.buff &&
                  effect.buffType == BuffType.regen)
          ? effect.value
          : 0;
      final abilityType = () {
        if (effect.type == EffectType.damage) {
          return (effect.target == 'back_enemy' ||
                  effect.target == 'lowest_hp_enemy')
              ? 'AttackRanged'
              : 'AttackMelee';
        }
        if (effect.type == EffectType.aoe) return 'AttackAoE';
        if (effect.type == EffectType.heal ||
            effect.type == EffectType.shield ||
            effect.type == EffectType.buff) {
          return 'Support';
        }
        return 'Utility';
      }();

      entries.add(
        TraitCardCatalogEntry(
          cardClass: tokens[0],
          imageName: cardId,
          templatePath: '$_kClassicBasePath/$cardId.png',
          partType: '${tokens[1][0].toUpperCase()}${tokens[1].substring(1)}',
          energy: trait.energyCost,
          attack: attack,
          defense: defense,
          healing: healing,
          abilityType: abilityType,
          description: trait.description,
          trait: trait,
          traitId: trait.id,
        ),
      );
    }

    entries.sort((a, b) {
      final classCmp = a.cardClass.compareTo(b.cardClass);
      if (classCmp != 0) return classCmp;
      return a.imageName.compareTo(b.imageName);
    });
    return entries;
  }

  static String? templatePathForTrait(Trait trait) =>
      _traitSystem.cardTemplatePathForTrait(trait);
}
