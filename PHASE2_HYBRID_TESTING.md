# Phase 2: Hybrid Pet Testing

## Overview

Once Phase 1 is verified (mixed skeletons working), Phase 2 tests **hybrid pets** — creatures with body from one class and parts from others.

Example: **Beast body + Aquatic back + Plant tail + Reptile horn**

---

## Test Strategy

### Test Case 1: Simple Hybrid (Beast + Aquatic)

```dart
// In pve_battle_provider.dart or a dedicated test method:

Future<void> testHybridBeastAquatic() async {
  final service = await MixedSkeletonService.instance();
  
  final hybrid = await service.buildCustomMixed(
    bodyClass: 'beast',
    hornCardArt: 'assets/images/cards/beast-horn-04.png',      // Beast horn
    backCardArt: 'assets/images/cards/aquatic-back-10.png',    // ← AQUATIC!
    tailCardArt: 'assets/images/cards/beast-tail-04.png',      // Beast tail
    mouthCardArt: 'assets/images/cards/beast-mouth-04.png',    // Beast mouth
    animSourcePath: 'assets/spines/beast/buba.json',           // Use beast animations
  );
  
  // Verify it worked
  print('Hybrid bones: ${(hybrid["bones"] as List).length}');
  print('Hybrid slots: ${(hybrid["slots"] as List).length}');
  print('Hybrid animations: ${(hybrid["animations"] as Map).keys.length}');
  
  // Expected: More bones (merged from beast + aquatic), same animations
}
```

### Test Case 2: Full Hybrid (All Different Classes)

```dart
Future<void> testFullHybrid() async {
  final service = await MixedSkeletonService.instance();
  
  final hybrid = await service.buildCustomMixed(
    bodyClass: 'beast',                                         // Body
    hornCardArt: 'assets/images/cards/reptile-horn-08.png',   // Reptile ← different
    backCardArt: 'assets/images/cards/aquatic-back-10.png',   // Aquatic ← different
    tailCardArt: 'assets/images/cards/plant-tail-02.png',     // Plant    ← different
    mouthCardArt: 'assets/images/cards/bird-mouth-12.png',    // Bird     ← different
    animSourcePath: 'assets/spines/beast/buba.json',          // Beast animations
  );
  
  print('Full hybrid bones: ${(hybrid["bones"] as List).length}');
  // Expected: Max possible bones (5 classes merged)
}
```

### Test Case 3: Same-Class (Pure Breed)

```dart
Future<void> testPureBreed() async {
  final service = await MixedSkeletonService.instance();
  
  final pure = await service.buildCustomMixed(
    bodyClass: 'beast',
    hornCardArt: 'assets/images/cards/beast-horn-04.png',      // All beast
    backCardArt: 'assets/images/cards/beast-back-04.png',
    tailCardArt: 'assets/images/cards/beast-tail-04.png',
    mouthCardArt: 'assets/images/cards/beast-mouth-04.png',
    animSourcePath: 'assets/spines/beast/buba.json',
  );
  
  print('Pure breed bones: ${(pure["bones"] as List).length}');
  // Expected: Least bones (only beast)
}
```

---

## Visual Verification Checklist

### For Each Hybrid Test:

- [ ] **Skeleton loads** — No "Couldn't load skeleton data" errors
- [ ] **Bones present** — Bone count > 20
- [ ] **Slots correct** — All 7 slots (body, back, ear, eyes, horn, tail, mouth)
- [ ] **Animations merge** — 5+ animations (idle, attack, defend, heal, stun)
- [ ] **Z-order correct** — Body behind, mouth forward (no distortion)
- [ ] **Animation plays** — Idle animation loops smoothly
- [ ] **60 FPS** — No stuttering, smooth playback
- [ ] **Memory reasonable** — <500KB per skeleton JSON

---

## Performance Metrics to Measure

| Metric | Target | Method |
|--------|--------|--------|
| **Mix latency** | <20ms | Time from `buildMixedSkeleton()` call to return |
| **Skeleton size** | <500KB | Check JSON string length |
| **Animation merge time** | <10ms | Time inside `mergeAnimations()` |
| **Memory per skeleton** | <1MB | Process memory before/after loading |
| **FPS** | 60 | Use DevTools performance profiler |
| **Texture atlas memory** | <5MB | Check GPU texture cache |

### Quick Profiling Command:

```dart
Future<void> profileMixing() async {
  final service = await MixedSkeletonService.instance();
  
  final stopwatch = Stopwatch()..start();
  final skeleton = await service.buildMixedSkeleton(
    kCreatureRegistry['beast_1']!,
  );
  stopwatch.stop();
  
  print('✅ Mixed in ${stopwatch.elapsedMilliseconds}ms');
  print('   Skeleton size: ${jsonEncode(skeleton).length} bytes');
  print('   Bones: ${(skeleton["bones"] as List).length}');
  print('   Animations: ${(skeleton["animations"] as Map).length}');
}
```

---

## Expected Results

### Pure-Breed Skeleton
- **Bones:** ~20-25
- **Slots:** 7
- **Animations:** 5-7 (idle, attack, defend, heal, etc.)
- **File size:** ~150-200KB

### Hybrid Skeleton (2-3 Classes)
- **Bones:** ~25-30
- **Slots:** 7
- **Animations:** 5-7 (same as body)
- **File size:** ~200-300KB

### Full Hybrid (5 Classes)
- **Bones:** ~30-40
- **Slots:** 7
- **Animations:** 5-7 (same as body)
- **File size:** ~300-400KB

---

## Success Criteria

✅ **All test cases pass without errors**
✅ **Hybrid pets render without distortion**
✅ **Z-order (depth) is correct for all hybrids**
✅ **Animations play smoothly**
✅ **Mixing latency <20ms**
✅ **No visual artifacts or clipping**
✅ **Memory usage reasonable (<1MB per skeleton)**

---

## Failure Scenarios & Fixes

### Scenario 1: "Bones in wrong order" (distortion)
**Cause:** Topological sort failed  
**Check:** Verify `_mixEntries()` in likha_mixer.dart runs DFS correctly  
**Fix:** Debug print bone dependency graph in mixer

### Scenario 2: "Animations don't play"
**Cause:** Bone name mismatch in animation target  
**Check:** Print animation names and bone names, compare  
**Fix:** Verify all animations reference valid bones (no orphans)

### Scenario 3: "Mixing too slow" (>50ms)
**Cause:** Large skeleton or many dependencies  
**Check:** Count bones and dependencies in combo  
**Fix:** Consider caching or splitting mixing into background task

### Scenario 4: "Memory explosion" (>2MB per skeleton)
**Cause:** Duplicate skin attachment or oversized animations  
**Check:** Inspect skeleton JSON structure in debugger  
**Fix:** Optimize attachment sizes or consider lazy-loading

---

## Testing Checklist

- [ ] Phase 1 verified (mixed skeletons work)
- [ ] Test Case 1 (Simple Hybrid) passes
- [ ] Test Case 2 (Full Hybrid) passes
- [ ] Test Case 3 (Pure Breed) passes
- [ ] Performance profiling completed
- [ ] Visual inspection (no distortion)
- [ ] Z-order verified (correct depth)
- [ ] Memory acceptable (<1MB per skeleton)
- [ ] Animations play smoothly (60 FPS)
- [ ] Error handling works (graceful fallback)

---

## Next Steps After Phase 2

If Phase 2 passes:

### Phase 3: Performance Optimization
- Add skeleton caching by bone combo
- Profile on actual device (not simulator)
- Measure impact of preloading
- Consider lazy-mixing strategy

### Phase 4: Custom Pet Support
- Design user-generated pet system
- Add UI for picking parts
- Store custom definitions in Firestore
- Test with player-created hybrids

### Phase 5: Advanced Features
- Support 6+ part slots (if desired)
- Weighted part selection (rare variants)
- Color/pattern variations
- Dynamic stat modifiers based on parts

---

## Code Integration Point

To add Phase 2 tests to the codebase:

```dart
// In app/lib/features/battle/providers/pve_battle_provider.dart

// Add this method to PveBattleNotifier:
Future<void> _runHybridTests() async {
  print('🧪 Running hybrid pet tests...');
  
  final service = await MixedSkeletonService.instance();
  
  // Test 1: Simple hybrid
  try {
    final hybrid = await service.buildCustomMixed(
      bodyClass: 'beast',
      hornCardArt: 'assets/images/cards/beast-horn-04.png',
      backCardArt: 'assets/images/cards/aquatic-back-10.png',
      tailCardArt: 'assets/images/cards/beast-tail-04.png',
      mouthCardArt: 'assets/images/cards/beast-mouth-04.png',
      animSourcePath: 'assets/spines/beast/buba.json',
    );
    print('✅ Test 1 (Simple Hybrid): PASS');
  } catch (e) {
    print('❌ Test 1 (Simple Hybrid): FAIL - $e');
  }
  
  // Test 2, 3... (similar structure)
}
```

---

## Timeline

- **Phase 2 Start:** After Phase 1 verification
- **Test Cases:** 30 min
- **Profiling:** 15 min
- **Visual Verification:** 20 min
- **Total:** ~1-1.5 hours

---

## Resources

- **LikhaMixer:** `app/lib/features/battle/services/likha_mixer.dart`
- **Service:** `app/lib/features/battle/services/mixed_skeleton_service.dart`
- **Samples:** `app/assets/data/creature-samples.json`
- **Atlas:** `app/assets/spines/mixer/likha-2d-v3-all.png`
- **Reference:** `MIXER_GUIDE.md`, `MIXER_QUICK_REF.md`

---

**Phase 2 ready when Phase 1 passes! 🚀**
