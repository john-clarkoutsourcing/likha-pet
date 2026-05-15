# LikhaMixer Usage Guide

## Overview

**LikhaMixer** is a Dart port of the Axie Infinity skeleton mixing system. It enables **dynamic, runtime assembly of Spine skeletal animations** by combining multiple body part samples into a single coherent skeleton.

Instead of pre-baking thousands of animation variants (one per pet combination), the mixer creates custom skeletons at runtime from a shared 67-sample library and a unified 4096×4096 atlas. This approach:
- ✅ Eliminates asset bloat
- ✅ Supports unlimited pet variety
- ✅ Works with any compatible Spine 3.8+ animation

---

## How It Works

### The Problem
A pet can have 6 body classes × many variant choices (horn, back, tail, mouth) = thousands of animation combinations. Pre-baking each is infeasible.

### The Solution: Topological Bone Merging
1. **One shared atlas** (`assets/spines/mixer/likha-2d-v3-all.png`, 4096×4096)  
   Contains every body part for every class variant — like a font file holds all glyphs.

2. **67 mini-skeletons** (`assets/data/creature-samples.json`)  
   One per class×variant (e.g., `beast-04`, `aquatic-10`). Each knows only about its own bones/slots/skins.

3. **Mix algorithm** at runtime:
   - Takes 7 sample names (body, back, horn, tail, mouth, ears, eyes)
   - Topologically merges their bones, slots, and skins
   - Remaps weighted mesh indices
   - Returns a complete Spine 3.8 JSON
   - Caller provides animations from a full-body skeleton

4. **Result**: One coherent skeleton that can play any animation from the source.

---

## API Reference

### Initialization

```dart
final mixer = await LikhaMixer.instance();
```

Loads and caches the singleton mixer. Safe to call multiple times.

---

### Building a Bone Combo

```dart
final combo = mixer.comboFor(
  bodyClass:    'beast',
  hornCardArt:  'assets/images/cards/beast-horn-04.png',
  backCardArt:  'assets/images/cards/beast-back-04.png',
  tailCardArt:  'assets/images/cards/beast-tail-04.png',
  mouthCardArt: 'assets/images/cards/beast-mouth-04.png',
);
// Result: ['body-normal', 'beast-04', 'beast-04', 'beast-04', 'beast-04', 'beast-04', 'beast-04']
// Order:  [body,        back,       ear,       eyes,      horn,       tail,       mouth]
```

**Arguments:**
- `bodyClass`: One of `'plant'`, `'aquatic'`, `'beast'`, `'reptile'`, `'bird'`, `'bug'`
- `*CardArt`: Paths to card images (e.g., `assets/images/cards/beast-horn-04.png`)

**Returns:** 7-element list of sample names, indexed as:
- `[0]` body
- `[1]` back  
- `[2]` ear (ears default to body class's "-04" standard look)
- `[3]` eyes (eyes default to body class's "-04")
- `[4]` horn
- `[5]` tail
- `[6]` mouth

---

### Mixing the Skeleton

```dart
final mixedJson = mixer.mix(combo);
// Result: Map<String, dynamic> with structure:
//   {
//     'skeleton': {'spine': '3.8.79'},
//     'bones': [...],
//     'slots': [...],
//     'ik': [...],
//     'skins': [{
//       'name': 'default',
//       'attachments': { 'slot-name': {...}, ... }
//     }],
//     'events': {...},
//     'animations': {}  ← empty; will be populated by mergeAnimations
//   }
```

This creates a complete Spine skeleton with all bones, slots, and skins merged topologically. **No animations yet** — the skeleton is a template.

---

### Merging Animations

```dart
// 1. Load a full-body Spine JSON (e.g., buba.json, aquatic.json)
final animSourceJson = jsonDecode(await rootBundle.loadString(
  'assets/spines/beast/buba.json',
));

// 2. Copy all animations into the mixed skeleton
LikhaMixer.mergeAnimations(mixedJson, animSourceJson);

// 3. mixedJson now has all animations from the source
// (both share the same bone-naming convention, so they transfer directly)
```

**Key insight:** Because all skeletons follow the same bone-naming convention (e.g., `horn`, `body`, `mouth-bite`), animations from any full-body skeleton work on any mixed skeleton.

---

### Deriving Sample Names from Card Art

```dart
final sample = LikhaMixer.sampleFromCardArt(
  'assets/images/cards/beast-horn-04.png'
);
// Result: 'beast-04'
```

Extracts `{class}-{variant}` from a card-art path.

---

## Complete Example

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'services/likha_mixer.dart';

Future<Map<String, dynamic>> createCustomPetSkeleton() async {
  // 1. Initialize mixer
  final mixer = await LikhaMixer.instance();

  // 2. Define the pet's parts via card art
  final combo = mixer.comboFor(
    bodyClass:    'beast',
    hornCardArt:  'assets/images/cards/beast-horn-04.png',
    backCardArt:  'assets/images/cards/beast-back-06.png',  // hybrid
    tailCardArt:  'assets/images/cards/plant-tail-04.png',  // hybrid
    mouthCardArt: 'assets/images/cards/beast-mouth-04.png',
  );
  print('Bone combo: $combo');
  // Output: [body-normal, beast-06, beast-04, beast-04, beast-04, plant-04, beast-04]

  // 3. Mix the skeleton (without animations)
  final mixedJson = mixer.mix(combo);
  print('Mixed skeleton bones: ${(mixedJson['bones'] as List).length}');
  // Output: Mixed skeleton bones: 28

  // 4. Load full-body animations from a source Spine file
  final animSourceJson = jsonDecode(
    await rootBundle.loadString('assets/spines/beast/buba.json'),
  );

  // 5. Copy animations into the mixed skeleton
  LikhaMixer.mergeAnimations(mixedJson, animSourceJson);

  // 6. mixedJson is now a complete, animated Spine skeleton
  return mixedJson;
}
```

---

## Bone Combo Format

The 7-element list represents a pet's topology:

```dart
[
  'body-normal',        // [0] Body base (always 'body-normal' for Likha)
  'beast-04',           // [1] Back part (e.g., shield, armor)
  'beast-04',           // [2] Ears (usually body class "-04" standard)
  'beast-04',           // [3] Eyes (usually body class "-04" standard)
  'beast-04',           // [4] Horn (offensive part)
  'plant-04',           // [5] Tail (support part—can be different class!)
  'beast-04',           // [6] Mouth (utility part)
]
```

**Key points:**
- Each element is a valid sample name from `creature-samples.json`
- Sample names follow format: `{class}-{variant}` (e.g., `aquatic-10`, `bird-12`)
- Hybrid pets mix classes (back/horn/tail/mouth can be from any class)
- Ears and eyes default to the body's "-04" standard look
- All samples must exist (null values default to body class "-04")

---

## Available Samples

The mixer includes 67 pre-made samples across 6 creature classes:

### Beast
- `beast-02`, `beast-04`, `beast-06`, `beast-08`, `beast-10`, `beast-12`
- `beast-mystic-02`, `beast-mystic-04`, etc.

### Aquatic
- `aquatic-02`, `aquatic-04`, `aquatic-06`, `aquatic-08`, `aquatic-10`, `aquatic-12`
- `aquatic-mystic-02`, `aquatic-mystic-04`, etc.

### Plant
- `plant-02`, `plant-04`, `plant-06`, `plant-08`, `plant-10`, `plant-12`
- `plant-mystic-02`, `plant-mystic-04`, etc.

### Bird
- `bird-02`, `bird-04`, `bird-06`, `bird-08`, `bird-10`, `bird-12`

### Reptile
- `reptile-02`, `reptile-04`, `reptile-06`, `reptile-08`, `reptile-10`, `reptile-12`

### Bug
- `bug-02`, `bug-04`, `bug-06`, `bug-08`, `bug-10`, `bug-12`

### Special
- `body-normal` — universal body base (always used as [0])
- `agamo-00`, `agamo-01` — special variants

---

## Sorting Rules

Complex body parts (mouth, horn, horn-accessory, etc.) have **custom depth ordering** to ensure visual correctness. These are defined in `creature-samples.json['sortingRules']`.

**Example:**
```json
{
  "mouth": ["eyes", "eyes-upper"],
  "horn": ["body-mfuzzy", "body-class", "ear-left", "ear-right", ...],
  "mouth-accessory": ["eyes", "eyes-upper", "mouth"]
}
```

The mixer applies these rules during topological sort to ensure parts render in the correct order, even when bones would otherwise suggest a different depth.

---

## Performance Considerations

### Caching
The mixer is a singleton — call `LikhaMixer.instance()` once at app startup:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LikhaMixer.instance(); // Cache it early
  runApp(const MyApp());
}
```

### Memoization
If you're mixing the same bone combo repeatedly (e.g., for multiple pets with identical parts), consider caching the result:

```dart
final _mixCache = <List<String?>, Map<String, dynamic>>{};

Future<Map<String, dynamic>> getMixedSkeleton(List<String?> combo) async {
  if (_mixCache.containsKey(combo)) {
    return _mixCache[combo]!;
  }
  final mixer = await LikhaMixer.instance();
  final mixed = mixer.mix(combo);
  _mixCache[combo] = mixed;
  return mixed;
}
```

### Atlas & Animation Source
Load these once and reuse:

```dart
late final String _mixerAtlasPath = 'assets/spines/mixer/likha-2d-v3-all.atlas';
late final String _mixerPngPath = 'assets/spines/mixer/likha-2d-v3-all.png';
late final Map<String, dynamic> _beastAnimations; // cache from buba.json

void init() async {
  _beastAnimations = jsonDecode(
    await rootBundle.loadString('assets/spines/beast/buba.json'),
  );
}
```

---

## Integration with Spine Widget

Once you have a mixed skeleton JSON and animations, use it with Flutter's `spine_flutter` widget:

```dart
import 'package:spine_flutter/spine_flutter.dart';

class MixedPetSprite extends StatelessWidget {
  final Map<String, dynamic> skeletonJson;
  final String atlasPath;
  final String pngPath;

  const MixedPetSprite({
    required this.skeletonJson,
    required this.atlasPath,
    required this.pngPath,
  });

  @override
  Widget build(BuildContext context) {
    return SpineWidget.fromJson(
      skeletonJson,
      atlasPath,
      pngPath,
      fit: BoxFit.contain,
    );
  }
}
```

---

## Troubleshooting

### "Couldn't load skeleton data"
- Check that all samples in the bone combo exist in `creature-samples.json`
- Verify JSON format is valid (use a JSON validator)
- Ensure the mixer atlas path is correct

### Bones appear in wrong order
- This is handled by `_correctBones()` — ensure it ran successfully
- Check if a sorting rule should be applied

### Animations don't play
- Verify animations were copied with `mergeAnimations()`
- Check bone names match between mixed skeleton and animation source
- Ensure the animation clip exists in the source JSON

### Weighted meshes distorted
- Check that bone indices were remapped correctly in `_transformSlot()`
- Verify all bones in the mesh weights exist in the merged skeleton

---

## Advanced: Custom Bone Combos

If you want fine-grained control, build the combo manually:

```dart
final customCombo = [
  'body-normal',        // [0] Body
  'beast-04',           // [1] Back
  'beast-04',           // [2] Ear
  'aquatic-06',         // [3] Eyes (hybrid!)
  'reptile-08',         // [4] Horn (hybrid!)
  'bird-10',            // [5] Tail (hybrid!)
  'plant-02',           // [6] Mouth (hybrid!)
];

final mixed = mixer.mix(customCombo);
```

This creates an exotic 6-class hybrid pet (if all samples are available).

---

## Data Files

- **creature-samples.json** (1.8 MB)  
  67 mini-skeletons with bones, slots, skins, IK chains, and sorting rules

- **likha-2d-v3-all.png** (≈2 MB)  
  4096×4096 shared atlas with all body parts

- **likha-2d-v3-all.atlas**  
  Spine atlas metadata (region definitions)

All files are included in `assets/spines/mixer/` and `assets/data/`.

---

## References

- **Original implementation:** [@axieinfinity/mixer](https://github.com/axieinfinity)
- **Spine runtime:** [spine-runtime](https://github.com/esotericsoftware/spine-runtimes)
- **Spine 3.8 format:** [Spine docs](http://esotericsoftware.com)

---

## Summary

LikhaMixer enables **unlimited pet customization** with a fixed animation set:

1. **Initialize** the mixer singleton once
2. **Build** a bone combo from body class + card art paths
3. **Mix** the skeleton (topologically merges 7 samples)
4. **Merge** animations from a source skeleton
5. **Render** with Flutter's `SpineWidget` using the mixer atlas

The approach is proven at scale by Axie Infinity, supporting millions of unique pets with a tiny asset footprint.
