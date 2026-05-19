import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../providers/battle_view_model.dart';
import 'likha_mixer.dart';

class BattleAssetWarmup {
  static const _kRendererTexturePrefix = 'assets/renderer/mixer-stuffs/v3/';
  static const _kFallbackClass = 'beast';
  static const _kValidClasses = {
    'beast',
    'plant',
    'aquatic',
    'reptile',
    'bird',
    'bug',
  };
  static const _kValidVariants = {'02', '04', '06', '08', '10', '12'};
  static const _kVariantsForBody = ['02', '04', '06', '08', '10', '12'];

  static List<String>? _assetManifestList;
  static final Set<String> _warmedKeys = {};

  static Future<void> preload(
    BuildContext context, {
    required Iterable<PetViewModel> pets,
    Iterable<CardViewModel> hand = const [],
  }) async {
    final petList = pets.toList(growable: false);
    if (petList.isEmpty) return;

    final textureDirs = <String>{'body-normal'};
    final imageAssets = <String>{'assets/images/pet-sub-effect/dead_pet.png'};

    for (final pet in petList) {
      final def = pet.creatureDef;
      if (def == null) continue;

      imageAssets.addAll(def.partCardArt.values);

      final bodyClass =
          _kValidClasses.contains(def.bodyClass.name) ? def.bodyClass.name : _kFallbackClass;
      for (final v in _kVariantsForBody) {
        textureDirs.add('$bodyClass-$v');
      }

      textureDirs.add(_sampleForPart(def.horn.cardArtPath, bodyClass));
      textureDirs.add(_sampleForPart(def.back.cardArtPath, bodyClass));
      textureDirs.add(_sampleForPart(def.tail.cardArtPath, bodyClass));
      textureDirs.add(_sampleForPart(def.mouth.cardArtPath, bodyClass));
    }

    for (final card in hand) {
      if (card.cardArtPath case final art?) imageAssets.add(art);
      if (card.cardTemplatePath case final template?) imageAssets.add(template);
    }

    final warmupKey = _buildWarmupKey(textureDirs, imageAssets);
    if (_warmedKeys.contains(warmupKey)) return;

    final imageWarmup = Future.wait([
      for (final imagePath in imageAssets)
        precacheImage(AssetImage(imagePath), context).catchError((_) {}),
    ]);

    final coreLoads = [
      imageWarmup,
      rootBundle.loadString('assets/renderer/renderer.html'),
      rootBundle.loadString('assets/data/creature-samples.json'),
    ];
    await Future.wait(coreLoads);

    _assetManifestList ??=
        (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();
    final allAssets = _assetManifestList!;

    final textureLoads = <Future<void>>[];
    for (final asset in allAssets) {
      if (!asset.startsWith(_kRendererTexturePrefix) || !asset.endsWith('.png')) continue;
      final rel = asset.substring(_kRendererTexturePrefix.length);
      final dir = rel.split('/').first;
      if (!textureDirs.contains(dir)) continue;
      textureLoads.add(rootBundle.load(asset).then((_) {}).catchError((_) {}));
    }
    await Future.wait(textureLoads);

    _warmedKeys.add(warmupKey);
  }

  static String _sampleForPart(String cardArtPath, String bodyClass) {
    try {
      final sample = LikhaMixer.sampleFromCardArt(cardArtPath);
      final parts = sample.split('-');
      if (parts.length == 2 &&
          _kValidClasses.contains(parts[0]) &&
          _kValidVariants.contains(parts[1])) {
        return sample;
      }
    } catch (_) {}
    final cls = _kValidClasses.contains(bodyClass) ? bodyClass : _kFallbackClass;
    return '$cls-04';
  }

  static String _buildWarmupKey(Set<String> textureDirs, Set<String> imageAssets) {
    final dirs = textureDirs.toList()..sort();
    final images = imageAssets.toList()..sort();
    return jsonEncode({'dirs': dirs, 'images': images});
  }
}
