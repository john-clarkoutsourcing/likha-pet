# Documentation Index

## Quick Navigation

### 📋 For This Session (You Are Here)
- **[SESSION_SUMMARY.md](SESSION_SUMMARY.md)** — What was accomplished, files changed, status
- **[NEXT_STEPS.md](NEXT_STEPS.md)** — Exactly what to do in the next session (with code)

### 🎮 For Using the Mixer
- **[MIXER_QUICK_REF.md](MIXER_QUICK_REF.md)** — One-page cheat sheet (start here)
- **[MIXER_INTEGRATION.md](MIXER_INTEGRATION.md)** — Full integration guide with examples
- **[MIXER_GUIDE.md](MIXER_GUIDE.md)** — Comprehensive reference (bone combos, API, troubleshooting)

### 📖 Project Reference
- **[CLAUDE.md](CLAUDE.md)** — Original quick reference (superseded by this index, kept for history)
- **[AGENTS.md](AGENTS.md)** — Full project architecture and conventions
- **[skills.md](skills.md)** — Battle system algorithm spec

---

## Document Purposes

### SESSION_SUMMARY.md
**Purpose:** Capture everything accomplished in this session  
**Audience:** Future you, context recovery, progress tracking  
**Key sections:**
- Work completed (sprite fixes, mixer investigation, integration)
- Files modified (before/after)
- Files created (new services, guides)
- Technical architecture
- Integration patterns

**Read if:** You return to this project after a break

---

### NEXT_STEPS.md
**Purpose:** Exact implementation roadmap for the next 2-3 sessions  
**Audience:** You, next session  
**Key sections:**
- Quick win (verify fixes work)
- Phase 1: Core integration (step-by-step with code)
- Phase 2: Hybrid pet testing
- Phase 3: Performance profiling
- Troubleshooting with solutions
- Testing checklist
- Success criteria

**Read before:** Starting Phase 1 integration

---

### MIXER_QUICK_REF.md
**Purpose:** 1-page quick lookup for LikhaMixer API  
**Audience:** Developers integrating the mixer  
**Key sections:**
- TL;DR code snippet
- Why it matters (assets/variety/implementation comparison)
- API cheat sheet (LikhaMixer, MixedSkeletonService, PetCharacterConfig)
- Bone combo format
- Common patterns
- Performance metrics
- Troubleshooting table

**Read if:** You need to quickly look up method signatures or see an example

---

### MIXER_INTEGRATION.md
**Purpose:** Comprehensive guide to integrating mixer with battle engine  
**Audience:** Implementers, architects  
**Key sections:**
- Architecture diagram (data flow)
- 5-step integration process
- Option A vs Option B (eager vs lazy mixing)
- Complete PetVisualProvider example
- Performance tips
- Troubleshooting
- API reference

**Read if:** You're building the integration and want full context

---

### MIXER_GUIDE.md
**Purpose:** Authoritative reference on LikhaMixer internals  
**Audience:** Deep dives, troubleshooting, algorithm understanding  
**Key sections:**
- How the mixer works (7-element bone combo, topological sort, sorting rules)
- API reference (all public methods)
- Bone combo format and available samples
- Available skeleton samples (all 67 variants)
- Performance considerations
- Troubleshooting (detailed)
- Integrating with Flutter battle engine (incomplete, see MIXER_INTEGRATION.md instead)

**Read if:** You need to understand how the mixer works internally or debug mixing issues

---

### CLAUDE.md
**Purpose:** Legacy quick reference (kept for history)  
**Status:** Superseded by this index and specific guides  
**Note:** Contains outdated task instructions; refer to newer docs instead

---

### AGENTS.md
**Purpose:** Complete project architecture, conventions, and procedures  
**Audience:** All contributors  
**Key sections:**
- Quick start & commands
- Project structure (all 5 modules)
- Architecture & data flow
- Shared types & conventions
- Battle system algorithm (link to skills.md)
- Development workflow
- Common tasks (recipes)
- MVP limitations
- Troubleshooting

**Read if:** You're unfamiliar with the project structure or need a convention

---

### skills.md
**Purpose:** Authoritative specification of battle system mechanics  
**Audience:** Battle system implementers  
**Key sections:**
- 3v3 formation and positioning
- Turn-based action system
- Damage calculation and status effects
- Trait definitions and effects
- AI controller behavior
- Win conditions

**Read if:** You're implementing battle mechanics or checking a specific rule

---

## Recommended Reading Order

### For Next Session (Phase 1 Integration)
1. **NEXT_STEPS.md** — Read the "Quick Win" and "Phase 1" sections
2. **MIXER_QUICK_REF.md** — Reference while coding (copy code snippets)
3. **MIXER_INTEGRATION.md** — Consult for full context on integration patterns

### For Understanding the Mixer
1. **MIXER_QUICK_REF.md** — Start here (1 page, overview)
2. **MIXER_INTEGRATION.md** — For implementation examples
3. **MIXER_GUIDE.md** — For deep dives and all 67 skeleton samples

### For Understanding the Project
1. **AGENTS.md** — Full architecture overview
2. **CLAUDE.md** — Quick reference (supplementary)
3. **skills.md** — If working on battle system

---

## File Locations

```
likha-pet/
├── SESSION_SUMMARY.md              ← What was done
├── NEXT_STEPS.md                   ← What to do next
├── MIXER_QUICK_REF.md              ← 1-page cheat sheet
├── MIXER_INTEGRATION.md            ← Full integration guide
├── MIXER_GUIDE.md                  ← Comprehensive reference
├── AGENTS.md                       ← Project architecture
├── CLAUDE.md                       ← Legacy quick ref (optional)
├── skills.md                       ← Battle algorithm spec
├── run.sh                          ← Master orchestration script
│
└── app/lib/features/battle/
    ├── services/
    │   ├── likha_mixer.dart                  ← Core mixer (358 lines)
    │   ├── mixed_skeleton_service.dart       ← NEW: Convenience service
    │   └── pet_character_config_ext.dart     ← NEW: Extension methods
    │
    ├── data/
    │   ├── creature_registry.dart            ← MODIFIED: Buba skeleton refs
    │   └── creature_samples.json             ← Mixer data (1.8 MB, 67 samples)
    │
    ├── screens/
    │   └── battle_screen.dart                ← MODIFIED: Shadow + card errors
    │
    └── spines/mixer/
        ├── likha-2d-v3-all.png              ← Shared atlas (2 MB)
        └── likha-2d-v3-all.atlas            ← Atlas metadata
```

---

## Key Decisions Documented

### Why LikhaMixer Instead of Pre-Baking?
See **MIXER_INTEGRATION.md** → "Why It Matters" table
- Pre-baking: 6+ GB assets, limited variety, slow iteration
- LikhaMixer: 200 MB total, unlimited variety, proven at scale (Axie Infinity)

### Why Eager vs Lazy Mixing?
See **MIXER_INTEGRATION.md** → "Step 4: Integrate into Battle System"
- **Eager:** Mix at battle start (Phase 1 recommended)
- **Lazy:** Mix on-demand (lower initial load, higher responsiveness)

### Why Extension Layer?
See **NEXT_STEPS.md** → "Phase 1: Step 3"
- Decouples PetCharacterConfig from SpineWidget
- Supports both pre-baked and mixed skeletons transparently

---

## Quick Lookups

### "I need to mix a skeleton quickly"
→ **MIXER_QUICK_REF.md** → Copy the TL;DR code snippet

### "What exactly does `comboFor()` do?"
→ **MIXER_QUICK_REF.md** → API Cheat Sheet section

### "I'm getting 'Couldn't load skeleton data' error"
→ **MIXER_INTEGRATION.md** → Troubleshooting section

### "What are all 67 skeleton samples?"
→ **MIXER_GUIDE.md** → "Available Skeleton Samples" section

### "How do I cache mixed skeletons?"
→ **MIXER_INTEGRATION.md** → "Performance Tips" section

### "What's the complete integration example?"
→ **MIXER_INTEGRATION.md** → "Complete Example: PetVisualProvider"

### "I want to understand topological sorting"
→ **MIXER_GUIDE.md** → "How It Works" section + likha_mixer.dart line 157-241

### "What was fixed in sprite rendering?"
→ **SESSION_SUMMARY.md** → "Work Completed" section

---

## Changes Made This Session

### Code Changes
- `creature_registry.dart` — Buba skeleton refs (lines 179-190)
- `battle_screen.dart` — Shadow size + card error handling (lines 1035-1046, 1706-1711)

### New Files
- `mixed_skeleton_service.dart` — Singleton service wrapper
- `pet_character_config_ext.dart` — Extension methods

### Documentation
- `SESSION_SUMMARY.md` — Session summary
- `NEXT_STEPS.md` — Integration roadmap
- `MIXER_QUICK_REF.md` — 1-page reference
- `MIXER_INTEGRATION.md` — Full integration guide
- This file — Documentation index

---

## Getting Started

**If you're jumping in next session:**

1. Read [NEXT_STEPS.md](NEXT_STEPS.md) (5 min)
2. Run the "Quick Win" section to verify fixes (5 min)
3. Start Phase 1 with [MIXER_QUICK_REF.md](MIXER_QUICK_REF.md) as reference (2-3 hours)
4. Consult [MIXER_INTEGRATION.md](MIXER_INTEGRATION.md) for detailed examples

**If you're implementing the mixer:**

1. Start with [MIXER_QUICK_REF.md](MIXER_QUICK_REF.md) for overview
2. Use [MIXER_INTEGRATION.md](MIXER_INTEGRATION.md) for step-by-step examples
3. Reference [MIXER_GUIDE.md](MIXER_GUIDE.md) for API details and troubleshooting

**If you're onboarding to the project:**

1. Read [AGENTS.md](AGENTS.md) for full architecture
2. Skim [skills.md](skills.md) for battle mechanics overview
3. Then follow mixer documentation as needed

---

**Status:** ✅ Complete. All documentation in place. Ready for Phase 1 integration.
