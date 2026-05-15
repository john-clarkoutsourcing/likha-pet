import 'package:flutter/material.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../data/creature_registry.dart';
import '../services/atlas_renderer.dart';
import '../../pets/models/owned_pet.dart';

// ── PetAssembledWidget ────────────────────────────────────────────────────────
//
// Renders a pet by drawing individual body-part regions from the shared atlas
// at the correct bone positions from the skeleton's setup pose.
//
// Each pet gets a unique visual because the horn/back/tail/mouth atlas regions
// are derived from the pet's DNA gene sample names (e.g., 'beast-04', 'bird-06').
//
// The shared atlas is likha-2d-v3-all.png (4096×4096) which contains every
// body part for every class variant.  The skeleton JSON (3.8.79 per class)
// provides bone positions and attachment offsets.

class PetAssembledWidget extends StatelessWidget {
  final CreatureDefinition def;
  final double size;
  final bool flipHorizontal;

  const PetAssembledWidget({
    super.key,
    required this.def,
    this.size = 140,
    this.flipHorizontal = false,
  });

  static PetAssembledWidget fromOwned(OwnedPet pet, {double size = 140}) =>
      PetAssembledWidget(def: pet.toCreatureDefinition(), size: size);

  @override
  Widget build(BuildContext context) {
    final skeletonPath = def.body.spineConfig.spineSkeletonPath;
    if (skeletonPath == null) return _fallback();

    // Map slot name → atlas region name based on pet's part samples
    final overrides = _buildSlotOverrides();

    Widget w = PetAtlasWidget(
      atlasImagePath: 'assets/spines/mixer/likha-2d-v3-all.png',
      atlasDataPath:  'assets/spines/mixer/likha-2d-v3-all.atlas',
      skeletonPath:   skeletonPath,
      slotOverrides:  overrides,
      size:           size,
      scale:          size / 1800,   // Spine world is ~1800 units wide
      offsetX:        size * 0.05,
      offsetY:        -size * 0.10,
    );

    if (flipHorizontal) {
      w = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: w,
      );
    }
    return w;
  }

  /// Map each Spine slot to the correct atlas region for this pet's DNA.
  ///
  /// The slot name in the skeleton ('horn', 'back', 'tail', 'mouth') maps to
  /// an atlas region like 'beast-04.horn', 'aquatic-06.back', etc.
  Map<String, String> _buildSlotOverrides() {
    return {
      'horn':  '${_sample(def.horn)}.horn',
      'back':  '${_sample(def.back)}.back',
      'tail':  '${_sample(def.tail)}.tail',
      'mouth': '${_sample(def.mouth)}.mouth',
      // Body always uses the body-normal silhouette
      'body':  'body-normal.body',
    };
  }

  /// Derive the Axie sample name from a PartDefinition's card art path.
  /// 'assets/images/cards/beast-horn-04.png' → 'beast-04'
  static String _sample(PartDefinition part) {
    final file  = part.cardArtPath.split('/').last.replaceAll('.png', '');
    final parts = file.split('-');
    if (parts.length >= 3) return '${parts[0]}-${parts[2]}';
    return '${part.partClass.name}-04'; // fallback
  }

  Widget _fallback() => SizedBox(
    width: size, height: size,
    child: Center(child: Icon(Icons.pets, size: size * 0.5,
        color: _classColor(def.bodyClass).withValues(alpha: 0.5))),
  );

  static Color _classColor(CreatureClass cls) => switch (cls) {
    CreatureClass.plant   => const Color(0xFF4CAF50),
    CreatureClass.aquatic => const Color(0xFF29B6F6),
    CreatureClass.beast   => const Color(0xFFFF9800),
    CreatureClass.reptile => const Color(0xFF66BB6A),
    CreatureClass.bird    => const Color(0xFFFF80AB),
    CreatureClass.bug     => const Color(0xFFFF5252),
  };
}
