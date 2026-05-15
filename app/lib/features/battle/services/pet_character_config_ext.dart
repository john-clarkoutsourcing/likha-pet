import 'dart:convert';
import 'package:flutter/services.dart';
import '../data/creature_registry.dart';
import '../widgets/pet_character_widget.dart' show PetCharacterConfig;
import 'likha_mixer.dart';

// ── PetCharacterConfigExt ──────────────────────────────────────────────────────
//
// Extensions to enable dynamic skeleton generation for hybrid/custom pets.

extension PetCharacterConfigExt on PetCharacterConfig {
  /// Create a Spine config from a pre-built mixed skeleton JSON.
  ///
  /// Used when the skeleton is dynamically generated at runtime.
  static PetCharacterConfig fromMixedSkeleton(
    Map<String, dynamic> skeletonJson, {
    required String atlasPath,
    required String texturePath,
  }) {
    return PetCharacterConfig(
      texturePath: texturePath,
      spineAtlasPath: atlasPath,
      skeletonJson: skeletonJson,  // Store the mixed skeleton
    );
  }

  /// Build a mixed spine config for a creature definition.
  ///
  /// This fetches the creature's parts, generates a bone combo, mixes the
  /// skeleton, and returns a config ready for SpineWidget.
  static Future<PetCharacterConfig> forCreature(
    CreatureDefinition def,
    LikhaMixer mixer,
  ) async {
    // 1. Extract card arts
    final cardArts = def.partCardArt;

    // 2. Build bone combo
    final combo = mixer.comboFor(
      bodyClass: def.bodyClass.name,
      hornCardArt: cardArts['horn'] ?? '',
      backCardArt: cardArts['back'] ?? '',
      tailCardArt: cardArts['tail'] ?? '',
      mouthCardArt: cardArts['mouth'] ?? '',
    );

    // 3. Mix skeleton
    final mixedJson = mixer.mix(combo);

    // 4. Load and merge animations
    final animSourcePath = def.body.spineConfig.spineSkeletonPath;
    if (animSourcePath != null) {
      try {
        final animJson = jsonDecode(
          await rootBundle.loadString(animSourcePath),
        ) as Map<String, dynamic>;
        LikhaMixer.mergeAnimations(mixedJson, animJson);
      } catch (e) {
        print('⚠️  Failed to load animations: $e');
      }
    }

    // 5. Return a config with the mixed skeleton JSON
    return PetCharacterConfig(
      texturePath: 'assets/spines/mixer/likha-2d-v3-all.png',
      spineAtlasPath: 'assets/spines/mixer/likha-2d-v3-all.atlas',
      skeletonJson: mixedJson,  // Store the generated skeleton
    );
  }
}
