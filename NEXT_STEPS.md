# Next Session: Integration Checklist

## Current Status
- ✅ Sprite rendering fixed (Buba, shadow, card images)
- ✅ LikhaMixer validated and fully documented
- ✅ Integration layer created (MixedSkeletonService)
- ✅ Two usage guides written (detailed + quick ref)
- ⏳ **NOT YET:** Hooked into battle system

---

## What to Do Next Session

### Quick Win: Verify the Fixes Still Work

```bash
cd /Users/anthony/Desktop/Projects/likha-pet
flutter run
# Check:
# 1. Buba appears correctly (not distorted)
# 2. Pet shadow is visible (larger than before)
# 3. No crashes on missing card images
```

**Expected:** All three fixes should be visibly working.

---

### Phase 1: Integrate Mixer into Battle Screen (2 hours)

#### Step 1: Test MixedSkeletonService in Isolation
```dart
// Quick test to verify service works
void testMixedSkeletonService() async {
  final service = await MixedSkeletonService.instance();
  final creature = kCreatureRegistry['beast_1']!;
  
  final skeleton = await service.buildMixedSkeleton(creature);
  
  // Verify output
  print('Bones: ${(skeleton['bones'] as List).length}');  // Should be 20+
  print('Slots: ${(skeleton['slots'] as List).length}');  // Should be 20+
  print('Skins: ${(skeleton['skins'] as Map).length}');   // Should be 5+
  print('Animations: ${(skeleton['animations'] as Map).keys.toList().take(5)}');  // Should see anim names
  
  assert(skeleton['bones'] != null, 'No bones!');
  assert(skeleton['animations'] != null, 'No animations!');
  
  print('✅ MixedSkeletonService works!');
}
```

**Where:** Add to `test/` or just run interactively in main.dart

#### Step 2: Hook into Battle Initialization
```dart
// In pve_battle_provider.dart or wherever you init battles

@override
Future<BattleState> build() async {
  final mixerService = await MixedSkeletonService.instance();
  
  // For each creature on both sides
  final playerConfigs = <String, PetCharacterConfig>{};
  for (final creatureDef in playerCreatures) {
    final skeleton = await mixerService.buildMixedSkeleton(creatureDef);
    playerConfigs[creatureDef.id] = PetCharacterConfig(
      texturePath: 'assets/spines/mixer/likha-2d-v3-all.png',
      spineAtlasPath: 'assets/spines/mixer/likha-2d-v3-all.atlas',
      skeletonJson: skeleton,
    );
  }
  
  // Do the same for enemy
  final enemyConfigs = <String, PetCharacterConfig>{};
  // ... same loop for enemy team
  
  // Now pass these to your BattleState
  return BattleState(
    playerPetConfigs: playerConfigs,
    enemyPetConfigs: enemyConfigs,
    // ... rest of state
  );
}
```

**Where:** The provider that initializes battles (likely `lib/providers/` or battle notifier)

#### Step 3: Use in PetCharacterWidget
```dart
// In pet_character_widget.dart build()

// OLD (pre-baked):
// final config = creature.body.spineConfig;

// NEW (mixed):
// final config = playerConfigs[creature.id]!;

// Then render as before
PetCharacterWidget(
  config: config,
  size: 200,
  animState: petAnimState,
)
```

#### Step 4: Test in Battle Screen
```bash
flutter run
# Start a battle
# Verify:
# 1. Pets load (no blank screens)
# 2. Pets animate (idle, attack, defend)
# 3. No error messages about skeletons
# 4. Smooth 60 FPS
```

**Expected result:** Pets render with mixed skeletons, animations play, no visible difference from pre-baked (except now they're dynamic).

---

### Phase 2: Test Hybrid Pets (1 hour)

Once Phase 1 works, try mixing parts from different classes:

```dart
// Create a hybrid creature for testing
final hybrid = await mixerService.buildCustomMixed(
  bodyClass: 'beast',
  hornCardArt: 'assets/images/cards/reptile-horn-08.png',  // ← reptile horn!
  backCardArt: 'assets/images/cards/aquatic-back-10.png',  // ← aquatic back!
  tailCardArt: 'assets/images/cards/plant-tail-02.png',    // ← plant tail!
  mouthCardArt: 'assets/images/cards/beast-mouth-04.png',
  animSourcePath: 'assets/spines/beast/buba.json',
);

// Test rendering
final config = PetCharacterConfig(
  texturePath: 'assets/spines/mixer/likha-2d-v3-all.png',
  spineAtlasPath: 'assets/spines/mixer/likha-2d-v3-all.atlas',
  skeletonJson: hybrid,
);

PetCharacterWidget(config: config, size: 200, animState: idle);
```

**Expected:** Hybrid pet renders with body from one class + parts from others. No distortion or z-order issues.

---

### Phase 3: Performance Check (30 min)

Use DevTools to profile:

```bash
flutter run --profile
# In DevTools:
# 1. Timeline → check mixing latency
# 2. Memory → check skeletonJson size
# 3. GPU → check texture cache
```

**Targets:**
- Mixing latency: <20 ms per pet
- Memory per skeleton: <500 KB
- Total atlas memory: <5 MB
- GPU texture cache: no thrashing

---

## Potential Issues & Fixes

### Issue 1: "SpineWidget.fromJson() doesn't exist"
**Cause:** spine_flutter may only support `fromAsset()`, not `fromJson()`.

**Fix Option A:** Serialize to temp file
```dart
// In mixed_skeleton_service.dart
final tmpDir = await getTemporaryDirectory();
final tmpFile = File('${tmpDir.path}/skeleton_$petId.json');
await tmpFile.writeAsString(jsonEncode(skeletonJson));

// Then use fromAsset
final config = PetCharacterConfig(
  spineSkeletonPath: tmpFile.path,
  // ...
);
```

**Fix Option B:** Check spine_flutter version
```yaml
# pubspec.yaml
spine_flutter: ^2.0.0  # Ensure latest version
```

**Fix Option C:** Custom JSON loader
```dart
// If spine_flutter supports custom loaders
final customLoader = SkeletonJsonLoader(jsonData);
final spinData = await customLoader.load();
```

### Issue 2: "Animations don't play"
**Cause:** Animation merge failed or bone names don't match.

**Debug:**
```dart
// Check animations were merged
print('Animations: ${(skeleton['animations'] as Map).keys.toList()}');
// Should see: ['idle', 'attack', 'defend', 'faint', etc.]

// Check bone count
print('Bones: ${(skeleton['bones'] as List).length}');
// Should be 20+ for hybrid pets
```

**Fix:** Verify animation source file has `animations` key:
```dart
final sourceJson = jsonDecode(await rootBundle.loadString(animPath));
assert(sourceJson['animations'] != null, 'Source has no animations!');
```

### Issue 3: "Hybrid pets distorted or z-order wrong"
**Cause:** Sorting rules not applied or bone remap failed.

**Debug:**
```dart
// Check sorting rules were applied
final skin = skeleton['skins']['default'];
print('Skin attachments: ${(skin as Map).keys.toList()}');
// Should see parts in correct order (body, back, eyes, horn, tail, mouth)
```

**Fix:** Re-run mixer with debug output:
```dart
// In likha_mixer.dart, add debug prints
print('Applying sorting rule for mouth...');
print('Bone indices remapped: $oldIndex → $newIndex');
```

---

## Testing Checklist

- [ ] Sprite fixes still visible (Buba, shadow, cards)
- [ ] MixedSkeletonService can instantiate
- [ ] Battle initializes with mixed configs
- [ ] Pure-breed pet renders (beast with beast parts)
- [ ] Hybrid pet renders (beast with mixed parts)
- [ ] Animations play (idle, attack, defend)
- [ ] No console errors about skeletons
- [ ] Performance acceptable (60 FPS, <20 ms mix time)
- [ ] Memory usage reasonable (<100 MB for full battle)

---

## Files to Review

Before starting Phase 1:
1. **MIXER_INTEGRATION.md** — Full integration guide
2. **MIXER_QUICK_REF.md** — Quick API reference
3. **mixed_skeleton_service.dart** — The service you'll use
4. **likha_mixer.dart** — Core algorithm (read if curious about topological sort)

---

## Estimated Timeline

- **Phase 1 (Core Integration):** 1-2 hours
- **Phase 2 (Hybrid Testing):** 30 min
- **Phase 3 (Performance):** 30 min
- **Total:** 2-3 hours

---

## Questions to Answer

Before Phase 2, clarify:
1. **Should hybrid pets be allowed in normal battles?** (Or only in special modes?)
2. **Should players be able to create custom hybrids?** (Or only pre-made combos?)
3. **Should animations vary by body class?** (Or always use body's animation set?)
4. **Should we cache mixed skeletons?** (Probably yes, but how many?)

---

## Success Criteria

✅ **Phase 1 done when:**
- Pets render from mixed skeletons in battle
- No visual difference from pre-baked (user shouldn't notice)
- Animations play smoothly
- No console errors

✅ **Phase 2 done when:**
- Hybrid pets render without distortion
- Bone z-order is correct (body behind, horn forward)
- Animations play on hybrids

✅ **Phase 3 done when:**
- Mixing takes <20 ms per pet
- Total memory <100 MB per battle
- 60 FPS maintained throughout

---

**Ready when you are. Start with Phase 1 setup!**
