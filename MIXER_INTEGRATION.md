# LikhaMixer Integration Guide

## Overview

This guide shows how to integrate **LikhaMixer** into your battle engine for **dynamic skeleton generation** of hybrid/custom pets.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Battle Engine / Creature Definition                      │
│  └─ CreatureDefinition (body + 4 parts)                 │
└────────────┬────────────────────────────────────────────┘
             │
             │ Extract card art paths
             ▼
┌─────────────────────────────────────────────────────────┐
│ LikhaMixer                                              │
│  ├─ comboFor(class, horn, back, tail, mouth)           │
│  ├─ mix(combo) → Spine JSON (no animations)            │
│  └─ mergeAnimations(mixed, source) → Complete skeleton │
└────────────┬────────────────────────────────────────────┘
             │
             │ Spine JSON + Atlas
             ▼
┌─────────────────────────────────────────────────────────┐
│ SpineWidget / PetCharacterWidget                        │
│  └─ Display animated skeleton on battlefield           │
└─────────────────────────────────────────────────────────┘
```

---

## Step 1: Initialize the Mixer

At app startup, initialize the mixer singleton:

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Preload the mixer early to avoid startup jank
  await LikhaMixer.instance();
  
  runApp(const MyApp());
}
```

---

## Step 2: Use the MixedSkeletonService

Create a service that bridges creatures and the mixer:

```dart
import 'services/mixed_skeleton_service.dart';

// Example: Build a mixed skeleton for a creature
final service = await MixedSkeletonService.instance();
final creature = kCreatureRegistry['beast_1']!;

final skeletonJson = await service.buildMixedSkeleton(creature);
// skeletonJson is now a complete Spine 3.8 JSON with:
//   - Mixed bones/slots from the creature's 4 parts
//   - All animations from the body's source skeleton
```

---

## Step 3: Create a PetCharacterWidget

Modify `PetCharacterWidget` to support mixed skeletons:

```dart
// In pet_character_widget.dart

class PetCharacterConfig {
  final String texturePath;
  final String? spineAtlasPath;
  final String? spineSkeletonPath;
  
  // NEW: Support for pre-built mixed skeleton JSON
  final Map<String, dynamic>? skeletonJson;

  const PetCharacterConfig({
    required this.texturePath,
    this.spineAtlasPath,
    this.spineSkeletonPath,
    this.skeletonJson,  // ← NEW
  });

  bool get hasSpine => 
      (spineAtlasPath != null && spineSkeletonPath != null) ||
      skeletonJson != null;  // ← Check for mixed skeleton
      
  bool get isMixed => skeletonJson != null;  // ← Is this a mixed skeleton?
}
```

Then in the SpineWidget initialization:

```dart
@override
Widget build(BuildContext context) {
  Widget child;
  
  if (!kIsWeb && widget.config.hasSpine) {
    Widget spine;
    
    if (widget.config.isMixed) {
      // Use the pre-built mixed skeleton JSON
      spine = SpineWidget.fromJson(
        widget.config.skeletonJson!,
        widget.config.spineAtlasPath!,
        widget.config.texturePath,
        _spineController,
        fit: BoxFit.contain,
      );
    } else {
      // Load from asset files (original behavior)
      spine = SpineWidget.fromAsset(
        widget.config.spineAtlasPath!,
        widget.config.spineSkeletonPath!,
        _spineController,
        fit: BoxFit.contain,
      );
    }
    
    child = Stack(
      fit: StackFit.expand,
      children: [
        if (!_spineReady) GameWidget(game: _game),
        spine,
      ],
    );
  } else {
    child = GameWidget(game: _game);
  }
  
  // ... rest of build method
}
```

---

## Step 4: Integrate into Battle System

### Option A: At Battle Start

Mix the skeleton once when initializing the battle:

```dart
// In pve_battle_provider.dart or battle initialization code

Future<void> initBattle() async {
  final mixerService = await MixedSkeletonService.instance();
  
  for (final petDef in playerCreatures) {
    // Generate mixed skeleton for this creature
    final skeletonJson = await mixerService.buildMixedSkeleton(petDef);
    
    // Store or pass to widget
    petVisuals[petDef.id] = PetCharacterConfig(
      texturePath: 'assets/spines/mixer/likha-2d-v3-all.png',
      spineAtlasPath: 'assets/spines/mixer/likha-2d-v3-all.atlas',
      skeletonJson: skeletonJson,  // ← Use the mixed skeleton
    );
  }
}
```

### Option B: Lazily (On Demand)

Mix skeletons only when they're needed:

```dart
// Create a provider that lazily mixes skeletons
final petSkeletonProvider = FutureProvider.family<PetCharacterConfig, String>(
  (ref, petId) async {
    final mixerService = await MixedSkeletonService.instance();
    final creature = kCreatureRegistry[petId]!;
    final skeletonJson = await mixerService.buildMixedSkeleton(creature);
    
    return PetCharacterConfig(
      texturePath: 'assets/spines/mixer/likha-2d-v3-all.png',
      spineAtlasPath: 'assets/spines/mixer/likha-2d-v3-all.atlas',
      skeletonJson: skeletonJson,
    );
  },
);

// In a widget:
@override
Widget build(BuildContext context, WidgetRef ref) {
  final configAsync = ref.watch(petSkeletonProvider('beast_1'));
  
  return configAsync.when(
    data: (config) => PetCharacterWidget(
      config: config,
      size: 200,
      animState: PetCharacterAnimState.idle,
    ),
    loading: () => const CircularProgressIndicator(),
    error: (err, st) => Text('Error loading skeleton: $err'),
  );
}
```

---

## Step 5: Test with Different Creatures

```dart
// Test hybrid pets with mixed classes

Future<void> testHybridPets() async {
  final service = await MixedSkeletonService.instance();
  
  // Pure-breed beast
  final pureBeast = await service.buildCustomMixed(
    bodyClass: 'beast',
    hornCardArt: 'assets/images/cards/beast-horn-04.png',
    backCardArt: 'assets/images/cards/beast-back-04.png',
    tailCardArt: 'assets/images/cards/beast-tail-04.png',
    mouthCardArt: 'assets/images/cards/beast-mouth-04.png',
    animSourcePath: 'assets/spines/beast/buba.json',
  );
  print('Pure beast: ${(pureBeast['bones'] as List).length} bones');
  // Output: Pure beast: 28 bones

  // Hybrid: beast body with aquatic back + plant tail
  final hybrid = await service.buildCustomMixed(
    bodyClass: 'beast',
    hornCardArt: 'assets/images/cards/beast-horn-04.png',
    backCardArt: 'assets/images/cards/aquatic-back-10.png',  // ← aquatic
    tailCardArt: 'assets/images/cards/plant-tail-04.png',   // ← plant
    mouthCardArt: 'assets/images/cards/beast-mouth-04.png',
    animSourcePath: 'assets/spines/beast/buba.json',
  );
  print('Hybrid: ${(hybrid['bones'] as List).length} bones');
  // Output: Hybrid: 30 bones (more parts merged)
}
```

---

## Complete Example: PetVisualProvider

Here's a complete provider that handles both pre-baked and mixed skeletons:

```dart
// providers/pet_visual_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/mixed_skeleton_service.dart';
import '../data/creature_registry.dart';

/// Pet visual configuration — uses mixer for dynamic skeletons or
/// falls back to pre-baked configs.
final petVisualProvider = FutureProvider.family<PetCharacterConfig, String>(
  (ref, petId) async {
    final creature = kCreatureRegistry[petId];
    if (creature == null) {
      throw Exception('Unknown creature: $petId');
    }

    // Option 1: Use pre-baked skeleton (fast, pre-defined)
    if (creature.body.spineConfig.hasSpine && _isPureBread(creature)) {
      // Pure-breed: use the original skeleton file
      return creature.body.spineConfig;
    }

    // Option 2: Use mixer (dynamic, supports hybrids)
    final service = await MixedSkeletonService.instance();
    final skeletonJson = await service.buildMixedSkeleton(creature);

    return PetCharacterConfig(
      texturePath: 'assets/spines/mixer/likha-2d-v3-all.png',
      spineAtlasPath: 'assets/spines/mixer/likha-2d-v3-all.atlas',
      skeletonJson: skeletonJson,
    );
  },
);

bool _isPureBread(CreatureDefinition creature) {
  final cls = creature.bodyClass;
  return creature.parts.every((p) => p.partClass == cls);
}

// Usage in a widget:
class PetVisualWidget extends ConsumerWidget {
  final String petId;

  const PetVisualWidget({required this.petId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(petVisualProvider(petId));

    return configAsync.when(
      data: (config) => PetCharacterWidget(
        config: config,
        size: 200,
        animState: PetCharacterAnimState.idle,
      ),
      loading: () => const SizedBox(
        width: 200,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => SizedBox(
        width: 200,
        height: 200,
        child: Center(child: Text('Error: $err')),
      ),
    );
  }
}
```

---

## Performance Tips

### 1. Pre-load the Mixer
```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LikhaMixer.instance(); // Pre-cache
  runApp(const MyApp());
}
```

### 2. Cache Mixed Skeletons
```dart
final _skeletonCache = <String, Future<Map<String, dynamic>>>{};

Future<Map<String, dynamic>> getMixed(CreatureDefinition def) {
  final key = def.id;
  return _skeletonCache.putIfAbsent(
    key,
    () async {
      final service = await MixedSkeletonService.instance();
      return service.buildMixedSkeleton(def);
    },
  );
}
```

### 3. Lazy-Load Only When Visible
```dart
// Use `ref.watch()` in widgets only when the pet is on screen
// Use `ref.read()` when you need the skeleton out of context
final config = await ref.read(petVisualProvider('beast_1').future);
```

---

## Troubleshooting

### "Cannot load skeleton data" error
**Cause:** `SpineWidget.fromJson()` may not be available in your version of `spine_flutter`.

**Solution:** Check your pubspec.yaml and update `spine_flutter`:
```yaml
dependencies:
  spine_flutter: ^2.0.0  # Ensure version supports fromJson
```

Or use `spine_flutter`'s custom data loader instead:
```dart
// Custom loader approach
final loader = SkeletonDataLoader();
final skelData = loader.load(jsonString: jsonEncode(skeletonJson));
```

### Animations don't play on mixed skeleton
**Cause:** Animation source didn't merge correctly, or bone names don't match.

**Solution:**
```dart
// Verify animations were merged
print('Animations in mixed: ${(mixedJson['animations'] as Map).length}');

// Verify bone names
final boneNames = (mixedJson['bones'] as List)
    .map((b) => (b as Map)['name'])
    .toList();
print('Bone names: $boneNames');
```

### Performance is slow
**Cause:** Mixing happens on every frame.

**Solution:** Cache the result:
```dart
final service = await MixedSkeletonService.instance();
final mixed = await service.buildMixedSkeleton(creature);
// Now reuse `mixed` for all instances of this creature
```

---

## API Reference

### MixedSkeletonService

```dart
class MixedSkeletonService {
  /// Initialize the service singleton
  static Future<MixedSkeletonService> instance()

  /// Build a mixed skeleton from a creature definition
  Future<Map<String, dynamic>> buildMixedSkeleton(CreatureDefinition def)

  /// Build a mixed skeleton from custom part variants
  Future<Map<String, dynamic>> buildCustomMixed({
    required String bodyClass,
    required String hornCardArt,
    required String backCardArt,
    required String tailCardArt,
    required String mouthCardArt,
    required String animSourcePath,
  })
}
```

### PetCharacterConfig (Extended)

```dart
class PetCharacterConfig {
  final String texturePath;
  final String? spineAtlasPath;
  final String? spineSkeletonPath;
  final Map<String, dynamic>? skeletonJson;  // ← NEW: mixed skeleton

  bool get hasSpine;
  bool get isMixed;  // ← NEW
}
```

---

## Summary

With LikhaMixer integration:

1. ✅ **Dynamic skeleton generation** for any creature combo
2. ✅ **Hybrid pets** (mixed classes) without asset bloat
3. ✅ **Single animation set** shared across all skeletons
4. ✅ **Performance optimized** with caching and lazy-loading
5. ✅ **Backward compatible** with pre-baked skeletons

The mixer enables **unlimited pet variety** with a fixed asset footprint—the same approach used by Axie Infinity to serve millions of players.
