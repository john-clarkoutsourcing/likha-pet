import 'package:likha_pet_battle_engine/trait.dart';
import 'package:likha_pet_battle_engine/trait_system.dart';
import 'origins_card_data.dart';

export 'origins_card_data.dart' show OriginsCardEntry;

/// A unified catalog entry that merges Origins card data with optional engine
/// Trait metadata (only available for the ~24 battle-engine-mapped cards).
class TraitCardCatalogEntry {
  final OriginsCardEntry card;

  /// Non-null only for cards that also have a full engine [Trait] definition.
  final Trait? trait;

  /// Engine trait ID, e.g. `'beast_horn'`. Null for display-only cards.
  final String? traitId;

  const TraitCardCatalogEntry({
    required this.card,
    this.trait,
    this.traitId,
  });

  String get cardClass => card.cardClass;
  String get imageName => card.imageName;
  String get templatePath => card.templatePath;
}

class TraitCardCatalog {
  static final TraitSystem _traitSystem = TraitSystem();

  /// Builds the full catalog from all 205 Origins-matched card PNGs.
  /// Cards that also have engine [Trait] definitions are enriched with them.
  static List<TraitCardCatalogEntry> build() {
    // Build a lookup: imageName → (traitId, Trait) for engine-mapped cards.
    final engineByImage = <String, ({String id, Trait trait})>{};
    for (final id in _traitSystem.allTraitIds) {
      final meta = _traitSystem.cardTemplateMetaForId(id);
      if (meta == null) continue;
      engineByImage[meta.imageName] = (id: id, trait: _traitSystem.getById(id));
    }

    final entries = kOriginsCards.map((card) {
      final eng = engineByImage[card.imageName];
      return TraitCardCatalogEntry(
        card: card,
        trait: eng?.trait,
        traitId: eng?.id,
      );
    }).toList(growable: false);

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
