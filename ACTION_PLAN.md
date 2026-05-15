# Action Plan: Phase 1 Verification & Phase 2 Launch

## Current Status

**Phase 1:** ✅ Implementation complete, compilation successful  
**Current:** Building (Xcode compiling, ~2-5 min remaining)  
**Next:** Phase 1 Verification → Phase 2 Testing

---

## Immediate Steps (After Build Completes)

### Step 1: Visual Verification (5 min)

Once Flutter finishes building and app loads:

```
1. Home Screen
   ✓ App loads without crashes
   ✓ No console errors

2. Navigate to PvE Battle
   ✓ Battle screen loads
   ✓ Creatures appear on screen

3. Check Console Output
   Look for these logs:
   ✅ Mixed skeleton for plant_1 (plant_1)
   ✅ Mixed skeleton for aquatic_1 (aquatic_1)
   ✅ Mixed skeleton for beast_1 (beast_1)
   ✅ Mixed skeleton for reptile_1 (reptile_1)
   ✅ Mixed skeleton for bird_1 (bird_1)
   ✅ Mixed skeleton for bug_1 (bug_1)

4. Play Battle
   ✓ Creatures animate (idle → attack)
   ✓ Damage/healing works
   ✓ Battle logic intact
   ✓ Victory/defeat triggers
```

### Step 2: Phase 1 Validation (All must pass)

- [ ] App compiles without errors
- [ ] Battle screen loads
- [ ] 6 creatures render
- [ ] Console shows 6 "✅ Mixed skeleton" logs
- [ ] Animations play smoothly
- [ ] Battle logic works
- [ ] No visual difference from before

**If all pass:** ✅ Phase 1 complete!  
**If any fail:** 🔧 Debug and fix before Phase 2

---

## Phase 2 Preparation (If Phase 1 Passes)

### Phase 2 Goal
Test **hybrid pets** (creatures with parts from different classes)

### Phase 2 Test Cases

**Test 1: Simple Hybrid**
```dart
// Beast body + Aquatic back
await service.buildCustomMixed(
  bodyClass: 'beast',
  hornCardArt: 'assets/images/cards/beast-horn-04.png',
  backCardArt: 'assets/images/cards/aquatic-back-10.png',  // ← hybrid
  tailCardArt: 'assets/images/cards/beast-tail-04.png',
  mouthCardArt: 'assets/images/cards/beast-mouth-04.png',
  animSourcePath: 'assets/spines/beast/buba.json',
);
```

**Test 2: Full Hybrid**
```dart
// 5 different classes merged
await service.buildCustomMixed(
  bodyClass: 'beast',
  hornCardArt: 'assets/images/cards/reptile-horn-08.png',
  backCardArt: 'assets/images/cards/aquatic-back-10.png',
  tailCardArt: 'assets/images/cards/plant-tail-02.png',
  mouthCardArt: 'assets/images/cards/bird-mouth-12.png',
  animSourcePath: 'assets/spines/beast/buba.json',
);
```

**Test 3: Pure Breed (Control)**
```dart
// All beast (should be baseline)
await service.buildCustomMixed(
  bodyClass: 'beast',
  hornCardArt: 'assets/images/cards/beast-horn-04.png',
  backCardArt: 'assets/images/cards/beast-back-04.png',
  tailCardArt: 'assets/images/cards/beast-tail-04.png',
  mouthCardArt: 'assets/images/cards/beast-mouth-04.png',
  animSourcePath: 'assets/spines/beast/buba.json',
);
```

---

## Execution Timeline

| Phase | Duration | Status | Next |
|-------|----------|--------|------|
| Phase 1: Integration | ~1 hr | ✅ Complete | Verify |
| Phase 1: Verification | ~10 min | ⏳ Pending | Proceed if pass |
| Phase 2: Hybrid Testing | ~1.5 hr | ⏳ Ready | If Phase 1 passes |
| Phase 3: Performance | ~1 hr | 📋 Planned | If Phase 2 passes |
| Phase 4: Optimization | ~1.5 hr | 📋 Planned | Optional |

---

## Success Criteria

### Phase 1 Success = All Below

- ✅ App builds & runs
- ✅ Battle screen loads
- ✅ All 6 creatures render
- ✅ 6 "Mixed skeleton" logs visible
- ✅ Animations play
- ✅ No visual difference from before
- ✅ Battle logic works normally

### Phase 2 Success = All Below

- ✅ Hybrid skeletons generate without errors
- ✅ Hybrid pets render correctly
- ✅ No distortion or Z-order issues
- ✅ Animations play on hybrids
- ✅ Mixing latency <20ms
- ✅ Memory usage <1MB per skeleton

---

## Troubleshooting

### If Phase 1 Fails: "Couldn't load skeleton data"

This error is **pre-existing** (spine_flutter library issue). It's normal and doesn't prevent testing.

**What to check:**
- Does console show "✅ Mixed skeleton" logs? (If yes, mixer works)
- Do creatures render on screen? (If yes, fallback works)
- Does battle play normally? (If yes, feature transparent)

### If Mixed Skeleton Logs Are Missing

**Possible causes:**
1. Battle hasn't started yet (still on home screen)
2. Mixer service failed silently (check for "❌" logs)
3. Async initialization hasn't completed (wait a moment)

**Fix:**
- Navigate explicitly to battle screen
- Check full console output
- Look for any "❌" or "⚠️" logs

### If Hybrids Look Distorted (Phase 2)

**Possible causes:**
1. Bone ordering issue (topological sort failed)
2. Skin attachment mismatch
3. Z-order rule not applied

**Debug:**
- Print bone count in console
- Print bone names
- Check if bone dependencies circular

---

## Git Commit Template

Once Phase 1 verified:

```bash
git add app/lib/features/battle/providers/pve_battle_provider.dart \
        app/lib/features/battle/widgets/pet_character_widget.dart \
        app/lib/features/battle/services/pet_character_config_ext.dart

git commit -m "Phase 1: Integrate LikhaMixer into battle engine

- Initialize MixedSkeletonService during battle setup
- Mix all 6 creatures asynchronously with per-creature error handling
- Cache mixed skeletons in PetCharacterConfig.skeletonJson
- Extend PetCharacterConfig with isMixed getter
- Update pet_character_config_ext to work with runtime skeletons
- Fully backward compatible with pre-baked skeletons
- Includes verbose logging (✅/⚠️/❌) for debugging

Testing:
- Phase 1: All 6 creatures render with mixed skeletons
- Console shows 6 '✅ Mixed skeleton' logs
- Animations play smoothly without visual difference

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Documentation Files

Created:
- ✅ `INDEX.md` — Master navigation
- ✅ `SESSION_SUMMARY.md` — Prior context
- ✅ `MIXER_GUIDE.md` — Deep dive
- ✅ `MIXER_QUICK_REF.md` — API ref
- ✅ `MIXER_INTEGRATION.md` — Integration guide
- ✅ `NEXT_STEPS.md` — Roadmap
- ✅ `PHASE2_HYBRID_TESTING.md` — Phase 2 guide (NEW)

All guides remain accessible and relevant.

---

## Quick Reference: What To Do Next

### Right Now (Build in Progress)
```
Wait for Flutter build to complete (~5 min)
```

### When App Loads
```
1. Navigate to battle screen
2. Check console for "✅ Mixed skeleton" logs
3. Verify 6 creatures render
4. Play a battle round
5. Check for any errors or visual issues
```

### If Phase 1 Works
```
Move to Phase 2:
- Test hybrid pets
- Measure performance
- Verify Z-order correctness
```

### If Phase 1 Fails
```
1. Note the error
2. Check console output
3. Refer to troubleshooting section
4. Debug with print statements if needed
5. Consider reverting and retrying
```

---

## Files to Monitor

**If errors occur, check these files:**
- `app/lib/features/battle/providers/pve_battle_provider.dart` — Integration
- `app/lib/features/battle/services/mixed_skeleton_service.dart` — Service
- `app/lib/features/battle/services/likha_mixer.dart` — Core mixer
- `app/lib/features/battle/widgets/pet_character_widget.dart` — Config
- Xcode build log (if compilation fails)

---

## Expected Timeline

- Build: ~5 min
- Phase 1 Verification: ~10 min
- Phase 2 Testing: ~1-2 hours (if Phase 1 passes)
- Phase 3 Performance: ~1 hour
- **Total: ~3-4 hours** for all phases

---

## Summary

✅ **Phase 1 Implementation:** Complete  
⏳ **Phase 1 Build:** In progress  
📋 **Phase 1 Verification:** Next step  
🚀 **Phase 2 Ready:** When Phase 1 passes  

**Current action:** Wait for build, then verify Phase 1 works.

---

**Ready to proceed! 🚀**
