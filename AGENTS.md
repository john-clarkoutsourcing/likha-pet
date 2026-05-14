# LIKHA PET — AI Agent Guide

Likha Pet is a **multi-module Dart + TypeScript game engine** combining a Flutter mobile/web game (`app/`), a pure Dart battle simulation engine (`battle_engine/`), and a web prototype (`client/`) backed by an Express API (`server/`).

Each sub-project is **independently managed** — no root `package.json`. Shared types live in `shared/types.ts`.

---

## Quick Start & Commands

### **Master Startup (Recommended)**
```bash
./run.sh                # Start everything (Firebase, server, client, battle engine demo)
./run.sh --no-client    # Skip webpack dev server
./run.sh --engine-only  # Test battle engine CLI demo only
```

**What it does:** Orchestrates Java 21+ resolution, Firebase Emulator Suite (port 4000), Express API (:3000), Webpack dev server (:8080), and optional Dart demo.

### **Per-Module Commands**

| Module | Dev | Build | Test |
|--------|-----|-------|------|
| **server/** | `npm run dev` (ts-node-dev, watch) | `npm run build` → `dist/` | `npm test` (Jest) |
| **client/** | `npm run dev` (:8080, proxies `/api` → :3000) | `npm run build` → `dist/bundle.js` | No test suite |
| **app/** | `flutter run` (device/emulator) | `flutter build apk/ios` | Minimal tests |
| **battle_engine/** | `dart run bin/main.dart` (CLI demo) | (no build needed) | `dart test` |

### **Individual Test Patterns**
```bash
cd server && npx jest --testPathPattern=DNADecoder  # Single test file
cd battle_engine && dart test                        # All Dart tests
```

---

## Project Structure & Module Roles

```
likha-pet/
├── app/                    ← Flutter game (iOS/Android/Web, Riverpod, go_router)
│   ├── lib/
│   │   ├── app.dart
│   │   ├── core/            (router, theme, constants)
│   │   ├── features/        (battle, home, pets, pve)
│   │   ├── models/          (local DTOs, no import of shared)
│   │   └── services/        (Firebase, auth, real-time listeners)
│   └── pubspec.yaml         (imports battle_engine via path: ../battle_engine)
│
├── battle_engine/          ← Pure Dart battle sim (CLI, no Flutter, no Firebase)
│   ├── lib/
│   │   ├── battle_engine.dart (main BattleEngine class, round loop)
│   │   ├── pet.dart           (Pet, status effects, damage calc)
│   │   ├── trait.dart         (Trait, TraitEffect, TraitLibrary with 20 skills)
│   │   ├── action_resolver.dart (apply damage, shield, poison, etc.)
│   │   ├── turn_manager.dart  (speed-based turn order, energy regen)
│   │   ├── ai_controller.dart (enemy AI: heal → stun → shield → AoE)
│   │   └── battle_state.dart  (immutable snapshots for UI rendering)
│   ├── bin/main.dart        (CLI demo: prints trait ref, runs 3v3 battle)
│   └── pubspec.yaml
│
├── server/                 ← Express API (Node 20, TypeScript, in-memory store)
│   ├── src/
│   │   ├── index.ts         (app setup, middleware, error handler)
│   │   ├── routes/
│   │   │   └── petRoutes.ts (POST /api/spawn-egg, GET /api/inventory, POST /api/hatch/:id)
│   │   ├── systems/
│   │   │   ├── HatcheryManager.ts  (pet lifecycle, ownership validation)
│   │   │   └── DNADecoder.ts       (24-hex DNA → DNAAttributes, deterministic)
│   │   ├── models/
│   │   │   ├── BasePet.ts          (abstract, re-exports shared types)
│   │   │   └── Pet.ts              (name, hatch() method)
│   │   └── store/
│   │       └── MemoryStore.ts      (Map-based, no persistence)
│   ├── __tests__/           (Jest suite)
│   │   ├── DNADecoder.test.ts
│   │   ├── Pet.test.ts
│   │   └── routes.test.ts
│   ├── package.json
│   └── jest.config.js
│
├── client/                 ← Phaser 3 web prototype (TypeScript, Webpack)
│   ├── src/
│   │   ├── main.ts          (Phaser boot)
│   │   ├── scenes/
│   │   │   ├── BootScene.ts  (placeholder for asset loading)
│   │   │   └── HatcheryScene.ts (egg spawn, countdown timers, hatch UI)
│   │   ├── objects/
│   │   │   └── EggSprite.ts  (Phaser Container: shell + label + glow tween)
│   │   └── api/
│   │       └── ApiClient.ts  (typed fetch wrapper, parallel PetData types)
│   ├── public/index.html
│   ├── webpack.config.js
│   ├── package.json
│   └── tsconfig.json
│
├── shared/                 ← Canonical TypeScript type definitions
│   └── types.ts            (PetState, Rarity, DNAAttributes, PetDTO)
│
├── assets/                 ← Art & audio for Flutter app
│   ├── images/bg2/, cards/, ui/, sprites/
│   ├── spines/             (skeleton rigs: aquatic, plant, beast, bug, reptile, bird)
│   └── audio/
│
├── CLAUDE.md               ← Legacy guidance (now superseded by this file)
├── skills.md               ← Authoritative battle system algorithm spec
├── run.sh                  ← Master orchestration script
└── firebase.json, firestore.rules, firestore.indexes.json  ← Firebase config
```

---

## Architecture & Data Flow

### **Web Prototype Flow** (client ↔ server)
```
Client (Phaser 3)
  └─ HatcheryScene
     ├─ ApiClient.post('/api/spawn-egg', { owner }) → egg sprite with countdown
     ├─ 500ms tick loop: update timers, show "Tap to Hatch!" when ready
     └─ EggSprite.onClick → ApiClient.post('/api/hatch/:id') → re-render as hatched
        ↑
        └─ Express API (server/)
           ├─ POST /api/spawn-egg → HatcheryManager.spawnEgg()
           │  └─ DNADecoder.generateDNA() → 24-char hex
           ├─ POST /api/hatch/:id → HatcheryManager.hatchPet()
           │  └─ Validates timer elapsed, ownership
           └─ GET /api/inventory?owner=player1 → all pets for owner
```

### **Mobile Game Flow** (app ↔ Firebase + battle_engine)
```
Flutter App (app/)
  ├─ Home screen: list pets from Firestore
  │  └─ services/firebase_service.dart: real-time listener
  ├─ Battle screen: initiate PvE battle
  │  └─ Import battle_engine package (local path)
  │  └─ Instantiate BattleEngine(myTeam, enemyTeam)
  │  └─ Call engine.nextRound() in loop, snapshot UI after each
  └─ Victory/defeat screen: Cloud Function validates outcome, updates Firestore
     └─ server-side battle runs again (anti-cheat)
```

### **Pure Battle Engine** (battle_engine/)
**Fully deterministic, no I/O.** Takes two teams of 3 pets, outputs winner.

```
BattleEngine
  ├─ constructor(myTeam: List<Pet>, enemyTeam: List<Pet>)
  ├─ nextRound() → BattleState snapshot
  │  ├─ TurnManager.getNextActor() → speed-based priority
  │  ├─ ActionResolver.resolveAction(actor, trait)
  │  │  ├─ Consume energy, check cooldown
  │  │  ├─ Calculate damage = max(1, raw_dmg - def), capped at 90 (single) or 30 (AoE)
  │  │  ├─ Apply status (poison 8/rd ×3 rounds, burn, stun, buffs, shield)
  │  │  └─ Remove fainted pets
  │  ├─ Update UI via BattleState snapshot
  │  └─ Check win condition (all 3 enemy fainted) or max 30 rounds (draw)
  └─ isComplete: bool
```

**Team structure:** 3-pet formation (Front/Mid/Back). Traits target by role.

---

## Shared Types & Type Safety

**Canonical source:** [`shared/types.ts`](shared/types.ts)

```typescript
export enum PetState { EGG = 'Egg', HATCHED = 'Hatched' }
export type Rarity = 'Common' | 'Uncommon' | 'Rare' | 'Epic' | 'Legendary'
export interface DNAAttributes {
  color: string
  rarity: Rarity
  basePower: number
  element: string
  pattern: string
}
export interface PetDTO {
  id: string; dna: string; state: PetState; hatchTime: number
  owner: string; attributes: DNAAttributes; name: string
  createdAt: number; hatchedAt?: number
}
```

**Server:** [`server/src/models/BasePet.ts`](server/src/models/BasePet.ts) re-exports these.

**Client:** [`client/src/api/ApiClient.ts`](client/src/api/ApiClient.ts) defines **parallel types** intentionally (avoids bundling server code into browser).

**App:** [`app/lib/models/`](app/lib/models) uses local DTOs, fetched from Firebase/API.

---

## Battle System Algorithm

Full specification in [`skills.md`](skills.md).

**Key mechanics:**
- **3v3 formation** (Front/Mid/Back rows)
- **Shared team energy pool:** start 3, regen +2/round, cap 9
- **18-card deck** (3 pets × 3 traits × 2 copies), 6-card hand, draw 3/round
- **20 total traits:** Offensive (damage, AoE), Defensive (shield, buff), Support (heal), Utility (debuff, stun)
- **Status effects:** Poison (DoT), Burn (DoT), Stun (skip turn), Buffs (ATK/DEF/SPD/Regen), Debuffs (ATK↓/DEF↓)
- **Damage formula:** `net = max(1, raw_dmg - defender_def)`, capped 90 single or 30 per-target AoE
- **AI priority:** Heal critical → Stun → Shield self → AoE → Team buff → Best damage
- **Win condition:** Faint all 3 enemies (or draw after 30 rounds)

Traits are defined in [`battle_engine/lib/trait.dart`](battle_engine/lib/trait.dart) via `TraitLibrary`.

---

## Firebase & Cloud Infrastructure

**Dev emulator stack** (started by `run.sh`):
- Firestore (port 8090): Pet data, battle history, users, real-time listeners
- Authentication (port 9099): Sign-up, login (emulated, no real Google/email setup)
- Cloud Functions (port 5001): PvE battle validation, stat updates
- Emulator UI (port 4000): Console for inspecting Firestore state

**Security rules** ([`firestore.rules`](firestore.rules)):
- User docs (pets, battles) locked to `request.auth.uid`
- Read-only catalogs (traits, monsters, stages, bosses, chapters)
- Cloud Function validation for high-stakes operations

---

## Development Workflow & Conventions

### **1. Project Conventions**

| Aspect | Convention |
|--------|-----------|
| **Pet naming** | Auto: `Likha #${petId.slice(0, 6).toUpperCase()}` |
| **DNA** | 24-char lowercase hex (`0-9a-f`); deterministic decoding |
| **Hatch timer** | Hardcoded 30s in `HatcheryManager` (MVP) |
| **Ownership** | Owner param in request; no JWT yet (hardcoded 'player1' in prototype) |
| **Timestamps** | `Date.now()` (milliseconds); `hatchTime = now + 30_000` |
| **Mobile layout** | Portrait-forced, responsive (target 360px+ width) |
| **Error handling** | Server throws `HatcheryError(status, msg)` caught by middleware |

### **2. Testing Patterns**

**Server (Jest):**
- Mock MemoryStore to avoid side effects
- Validate HTTP status codes via HatcheryError
- Test DNA determinism & rarity distribution
- Verify ownership checks & ownership-based filtering

**Battle Engine (Dart):**
- Test BattleEngine.nextRound() determinism
- Verify damage caps, status effect duration, AI decision logic
- Mock Pet teams to test specific scenarios

**Client (Phaser):**
- Not automated yet; manual/visual testing

**App (Flutter):**
- Minimal test coverage; focus on critical screens (battle, pet list)

### **3. Common Tasks & Recipes**

| Task | Steps |
|------|-------|
| **Add a new trait** | Edit [`battle_engine/lib/trait.dart`](battle_engine/lib/trait.dart): add static getter to `TraitLibrary`, define `TraitEffect`. Update [`skills.md`](skills.md) if needed. |
| **Add a new API endpoint** | Edit [`server/src/routes/petRoutes.ts`](server/src/routes/petRoutes.ts). Call `HatcheryManager` methods. Add test to `__tests__/routes.test.ts`. |
| **Update shared types** | Edit [`shared/types.ts`](shared/types.ts). Update server [`BasePet.ts`](server/src/models/BasePet.ts) re-export. Update client [`ApiClient.ts`](client/src/api/ApiClient.ts) parallel types if interface changed. |
| **Debug battle** | Run `./run.sh --engine-only` to see CLI output. Inspect `BattleState` snapshot. Verify pet stats & trait targeting. |
| **Test auth flow** | Use Firebase Emulator UI (port 4000) to create test users, inspect Firestore rules enforcement. |
| **Profile Phaser perf** | Use browser DevTools; check texture cache, canvas render time. |

---

## MVP Limitations & Known Issues

1. **No persistence:** MemoryStore clears on server restart. Consider SQLite or PostgreSQL for production.
2. **No real auth:** Owner hardcoded in prototype; Firebase rules not enforced locally.
3. **Single hatch time:** 30 seconds hardcoded. Future: rarity-based or user customization.
4. **Client types duplicated:** Web client re-defines shared types to avoid bundling server code. Keep in sync manually.
5. **No pagination:** inventory endpoint returns all pets; would scale badly.
6. **No emulator persistence:** Firebase emulator data reset on restart.
7. **Battle UI incomplete:** client/ only shows egg hatching; no battle view yet (use app/ for that).

---

## Useful Links & References

| File | Purpose |
|------|---------|
| [CLAUDE.md](CLAUDE.md) | Legacy guidance (superseded by this file) |
| [skills.md](skills.md) | Authoritative battle algorithm spec |
| [server/package.json](server/package.json) | Dependencies, npm scripts |
| [client/webpack.config.js](client/webpack.config.js) | Dev server proxy config |
| [app/lib/main.dart](app/lib/main.dart) | Flutter app entry point |
| [battle_engine/bin/main.dart](battle_engine/bin/main.dart) | CLI demo; good reference for BattleEngine usage |
| [shared/types.ts](shared/types.ts) | Canonical type definitions |
| [firestore.rules](firestore.rules) | Security rules (read/write policies) |
| [run.sh](run.sh) | Master orchestration; see comments for port allocation & troubleshooting |

---

## Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| **"Port 3000 already in use"** | `kill -9 $(lsof -t -i:3000)` or `./run.sh` auto-detects |
| **"Webpack dev server not proxying /api"** | Check [`client/webpack.config.js`](client/webpack.config.js) proxy target |
| **"Jest tests fail with 'Cannot find module'"** | Run `cd server && npm install`, verify `jest.config.js` has `preset: 'ts-jest'` |
| **"BattleEngine crashes on nextRound()"** | Check team size (must be exactly 3 pets), verify all pets have traits in TraitLibrary |
| **"Flutter app crashes on Firebase setup"** | Delete `build/`, re-run `flutter pub get`, check `google-services.json` path |
| **"Dart battle demo hangs"** | Check AI controller; infinite loop possible if no valid actions. Inspect `ai_controller.dart` |

---

## Next Steps for Contributors

1. **Understand the triple architecture:** app (Flutter), battle_engine (Dart), server + client (TypeScript).
2. **Run `./run.sh`** to verify the whole stack boots.
3. **Pick a module** to focus on—each has independent test suite and build process.
4. **Consult [`skills.md`](skills.md)** if touching battle logic.
5. **Keep types in sync:** If editing `shared/types.ts`, update server re-export and client parallel definitions.
6. **Test locally before pushing:** Jest for server, `dart test` for battle_engine, manual for Phaser.

