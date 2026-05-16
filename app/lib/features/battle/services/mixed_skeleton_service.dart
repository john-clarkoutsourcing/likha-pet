import 'dart:convert';
import 'package:flutter/services.dart';
import '../data/creature_registry.dart';
import 'likha_mixer.dart';

// ── MixedSkeletonService ───────────────────────────────────────────────────────
//
// Bridges LikhaMixer with the battle engine: takes creature definitions,
// generates bone combos, mixes skeletons, and merges animations.
//
// Usage:
//   final service = MixedSkeletonService.instance();
//   final skelJson = await service.buildMixedSkeleton(creatureDef);

class MixedSkeletonService {
  final LikhaMixer mixer;
  final Map<String, Map<String, dynamic>> _animationCache;

  MixedSkeletonService._(this.mixer)
      : _animationCache = <String, Map<String, dynamic>>{};

  // ── Singleton ──────────────────────────────────────────────────────────────

  static MixedSkeletonService? _instance;

  static Future<MixedSkeletonService> instance() async {
    if (_instance != null) return _instance!;
    final mixer = await LikhaMixer.instance();
    _instance = MixedSkeletonService._(mixer);
    return _instance!;
  }

  // ── Public: Build mixed skeleton for a creature ────────────────────────────

  /// Generate a mixed Spine skeleton for the given creature definition.
  ///
  /// This is the main entry point:
  /// 1. Extracts the 4 card art paths from the creature's parts
  /// 2. Builds a 7-element bone combo
  /// 3. Mixes the skeleton topologically
  /// 4. Loads and merges animations from the body's source skeleton
  ///
  /// Result: A complete Spine 3.8 JSON ready for animation playback.
  Future<Map<String, dynamic>> buildMixedSkeleton(
    CreatureDefinition def,
  ) async {
    // 1. Extract card art paths (4 parts)
    final cardArts = def.partCardArt;
    final hornArt = cardArts['horn'] ?? '';
    final backArt = cardArts['back'] ?? '';
    final tailArt = cardArts['tail'] ?? '';
    final mouthArt = cardArts['mouth'] ?? '';

    // 2. Build bone combo from body class + 4 part variants
    final combo = mixer.comboFor(
      bodyClass: def.bodyClass.name,
      hornCardArt: hornArt,
      backCardArt: backArt,
      tailCardArt: tailArt,
      mouthCardArt: mouthArt,
    );

    // 3. Mix the skeleton
    final mixedJson = mixer.mix(combo);

    // 4. Load animations from the body's source skeleton
    final animSourceJson =
        await _loadAnimations(def.body.spineConfig.spineSkeletonPath);
    if (animSourceJson != null) {
      LikhaMixer.mergeAnimations(mixedJson, animSourceJson);
    }

    return mixedJson;
  }

  /// Generate a mixed skeleton for a creature with custom part variants.
  ///
  /// Useful for testing or one-off custom pets:
  ///   final mixed = await service.buildCustomMixed(
  ///     bodyClass: 'beast',
  ///     hornCardArt: 'assets/images/part-cards/beast-horn-04.png',
  ///     backCardArt: 'assets/images/part-cards/plant-back-06.png',  // hybrid
  ///     tailCardArt: 'assets/images/part-cards/aquatic-tail-08.png', // hybrid
  ///     mouthCardArt: 'assets/images/part-cards/beast-mouth-04.png',
  ///     animSourcePath: 'assets/spines/beast/buba.json',
  ///   );
  Future<Map<String, dynamic>> buildCustomMixed({
    required String bodyClass,
    required String hornCardArt,
    required String backCardArt,
    required String tailCardArt,
    required String mouthCardArt,
    required String animSourcePath,
  }) async {
    final combo = mixer.comboFor(
      bodyClass: bodyClass,
      hornCardArt: hornCardArt,
      backCardArt: backCardArt,
      tailCardArt: tailCardArt,
      mouthCardArt: mouthCardArt,
    );

    final mixedJson = mixer.mix(combo);

    final animSourceJson = await _loadAnimations(animSourcePath);
    if (animSourceJson != null) {
      LikhaMixer.mergeAnimations(mixedJson, animSourceJson);
    }

    return mixedJson;
  }

  // ── Private ────────────────────────────────────────────────────────────────

  /// Load animation JSON from a Spine skeleton file, with caching.
  /// Returns null if the file cannot be loaded.
  Future<Map<String, dynamic>?> _loadAnimations(String? skeletonPath) async {
    if (skeletonPath == null) return null;
    if (_animationCache.containsKey(skeletonPath)) {
      return _animationCache[skeletonPath];
    }

    try {
      final json = jsonDecode(
        await rootBundle.loadString(skeletonPath),
      ) as Map<String, dynamic>;
      _animationCache[skeletonPath] = json;
      return json;
    } catch (e) {
      print('Failed to load animations from $skeletonPath: $e');
      return null;
    }
  }
}
