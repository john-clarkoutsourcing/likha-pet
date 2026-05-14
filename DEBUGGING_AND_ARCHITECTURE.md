# Likha Pet — Comprehensive Debugging & Architecture Guide

This document provides detailed explanations of all components, how they interact, and how to debug them.

---

## Table of Contents

1. [High-Level Architecture](#high-level-architecture)
2. [Server Components (TypeScript + Express)](#server-components-typescript--express)
3. [Client Components (Phaser 3)](#client-components-phaser-3)
4. [Battle Engine (Pure Dart)](#battle-engine-pure-dart)
5. [Data Flow & Request/Response Cycles](#data-flow--requestresponse-cycles)
6. [How to Debug](#how-to-debug)
7. [Common Issues & Solutions](#common-issues--solutions)

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│  LIKHA PET GAME ENGINE (Multi-Module)               │
└─────────────────────────────────────────────────────┘

Three independent stacks:

1. WEB PROTOTYPE (MVP):
   Phaser 3 Browser Client
        ↓ HTTP/JSON
   Express API Server → In-Memory Pet Store
   
2. MOBILE GAME (In Development):
   Flutter App (iOS/Android/Web)
        ↓ Firebase Firestore + Cloud Functions
   Firebase Backend + Cloud Infrastructure
        ↓ Uses
   Battle Engine (Pure Dart, no I/O)
   
3. BATTLE SIMULATION (Testable):
   Pure Dart library (no Flutter, no Firebase)
   CLI demo executable
```

### Key Principles

- **Independence**: Each module can run standalone (server without client, battle engine standalone)
- **Determinism**: Battle outcomes are reproducible (same input always produces same output)
- **Type Safety**: Shared types in `shared/types.ts`, re-exported or duplicated as needed
- **Ownership**: User/player IDs validate all data access (hardcoded 'player1' in MVP)

---

## Server Components (TypeScript + Express)

### File Structure

```
server/
├── src/
│   ├── index.ts                 ← Express app setup, middleware, port binding
│   ├── routes/
│   │   └── petRoutes.ts         ← HTTP endpoint handlers (/api/spawn-egg, etc.)
│   ├── systems/
│   │   ├── HatcheryManager.ts   ← Domain logic (spawn, hatch, inventory)
│   │   └── DNADecoder.ts        ← Genetic algorithm (deterministic decoding)
│   ├── models/
│   │   ├── BasePet.ts           ← Abstract base, re-exports shared types
│   │   └── Pet.ts               ← Concrete pet model with hatch() method
│   └── store/
│       └── MemoryStore.ts       ← In-memory Map-based storage (no persistence)
├── __tests__/
│   ├── DNADecoder.test.ts       ← Verify determinism, rarity distribution
│   ├── Pet.test.ts              ← State transitions, hatch timer
│   └── routes.test.ts           ← HTTP endpoint validation
├── package.json
├── jest.config.js
└── tsconfig.json
```

### Component Details

#### **1. index.ts (Entry Point)**

```
What it does:
  1. Import Express, middleware (CORS, JSON parser)
  2. Create MemoryStore instance (all pet data lives here)
  3. Create HatcheryManager instance (encapsulates domain logic)
  4. Mount petRoutes on /api prefix
  5. Add /health endpoint for orchestration
  6. Listen on port 3000

Data flow:
  Client HTTP request
    → Express middleware (CORS, JSON parsing)
    → petRoutes handler
    → HatcheryManager method
    → MemoryStore read/write
    → Pet object created/modified
    → Response sent to client

Error handling:
  - All errors from HatcheryManager are HatcheryError(status, msg)
  - Middleware catches and returns HTTP response with correct status code
```

Debugging tips:
- Add `console.log()` after `app.listen()` to confirm port binding
- Add logs in middleware to trace request → response
- Use `curl` to test endpoints: `curl -X POST http://localhost:3000/api/spawn-egg -H "Content-Type: application/json" -d '{"owner":"player1"}'`

---

#### **2. HatcheryManager.ts (Domain Logic)**

```
Responsibilities:
  ✓ Create eggs with random DNA (spawnEgg)
  ✓ Validate ownership (can't hatch others' pets)
  ✓ Check hatch timer expiration
  ✓ Retrieve pet inventory
  ✓ Persist all changes to store
  ✗ NOT responsible for HTTP responses (that's the router)
  ✗ NOT responsible for storage implementation (that's MemoryStore)

Public methods:
  
  spawnEgg(owner: string): Pet
    1. Generate UUID for pet
    2. Generate random 24-hex DNA via DNADecoder.generateDNA()
    3. Decode DNA to get attributes via DNADecoder.decode()
    4. Calculate hatchTime = now + 30 seconds
    5. Create new Pet object
    6. Save to store
    7. Return Pet
  
  getInventory(owner: string): Pet[]
    - Fetch all pets from store where owner matches
    - Return array (no pagination in MVP)
  
  hatchEgg(id: string, requestingOwner: string): Pet
    1. Fetch pet from store
    2. If not found → throw HatcheryError(404, ...)
    3. If owner doesn't match → throw HatcheryError(403, ...)
    4. If already hatched → throw HatcheryError(409, ...)
    5. Call pet.hatch() which:
       - Checks if hatchTime has passed
       - Updates state to HATCHED
       - Sets hatchedAt = now
       - Generates pet name
    6. Save updated pet
    7. Return hatched Pet

Error throwing:
  throw new HatcheryError(status, msg)
  - 404: Pet not found
  - 403: Ownership mismatch
  - 409: Already hatched
  - Caller (petRoutes) catches and returns HTTP response
```

Debugging tips:
- Log at the start of each method: `console.log('spawnEgg called for owner:', owner);`
- Log before throwing errors: `console.log('Pet not found, throwing 404');`
- Verify store integration: `console.log('Saved pet:', pet); console.log('Store size:', store.getAll().length);`
- Test with curl: `curl -X POST http://localhost:3000/api/spawn-egg -d '{"owner":"player1"}' -H "Content-Type: application/json"`

---

#### **3. DNADecoder.ts (Genetic Algorithm)**

```
Purpose:
  Convert random 24-hex DNA into deterministic creature attributes.

Why deterministic?
  - Same DNA always produces the same creature
  - Prevents RNG manipulation in PvP/PvE
  - Cloud Functions can re-run battles to verify outcomes
  - Test battles with known DNA

DNA Format: 24 lowercase hex characters (12 bytes)
  Example: 'a1b2c3d4e5f6a7b8c9d0e1f2'

Decoding Process:
  Each byte (2 hex chars) maps to one attribute:
  
  Byte 0 (hex[0:2]): color
    0xFF % 8 = color index
    → COLORS[0], COLORS[1], ..., COLORS[7]
  
  Byte 1 (hex[2:4]): rarity
    0xAB / 255 = 0.0–1.0
    → 0.0–0.50: Common
    → 0.50–0.75: Uncommon
    → 0.75–0.90: Rare
    → 0.90–0.98: Epic
    → 0.98–1.00: Legendary (rare!)
  
  Bytes 2–3 (hex[4:8]): basePower
    Scale 0xABCD (0–65535) to 1–100
  
  Byte 4 (hex[8:10]): element
    0xFF % 8 = element index
    → ELEMENTS[0], ELEMENTS[1], ..., ELEMENTS[7]
  
  Byte 5 (hex[10:12]): pattern
    0xFF % 6 = pattern index
    → PATTERNS[0], PATTERNS[1], ..., PATTERNS[5]

Public methods:

  static generateDNA(): string
    1. Loop 12 times
    2. Pick random 0–255
    3. Convert to hex (00–ff)
    4. Join: '0fa1b2c3d4e5f6a7b8c9d0'
  
  static decode(dna: string): DNAAttributes
    1. Parse dna string in 2-char hex chunks
    2. Map each chunk via modulo/division to trait
    3. Return { color, rarity, basePower, element, pattern }
  
  static parseRarity(seed: number): Rarity
    Map byte 0–255 to rarity using cumulative distribution
```

Debugging tips:
- Test determinism: `DNADecoder.decode('a1b2c3d4e5f6a7b8c9d0e1f2')` should always return same object
- Generate DNA and decode: `const dna = DNADecoder.generateDNA(); console.log(dna, DNADecoder.decode(dna));`
- Check rarity distribution: Generate 1000 DNAs and tally rarities
- Manually verify example DNA:
  ```
  dna = 'ff0099aabbccddee11223344'
  b(0) = parseInt('ff', 16) = 255
  color = COLORS[255 % 8] = COLORS[7]
  b(2) = parseInt('99', 16) = 153
  rarity = 153/255 = 0.6 → Uncommon
  b(4,4) = parseInt('aabd', 16) = 43709 ← CAREFUL: b(4,4) parses 4 chars
  basePower = floor((43709 / 65535) * 99) + 1 = 66
  etc.
  ```

---

#### **4. Pet.ts (Pet Model)**

```
Class: Pet extends BasePet

Properties:
  id: string (UUID v4)
  dna: string (24-hex, never changes)
  hatchTime: number (ms when hatch timer expires)
  owner: string (player ID, 'player1' in MVP)
  attributes: DNAAttributes (color, rarity, basePower, element, pattern)
  state: PetState (EGG or HATCHED)
  name: string (auto-generated or custom)
  createdAt: number (when egg spawned)
  hatchedAt?: number (when egg hatched)

Key methods:
  
  hatch(): void
    - Validates hatchTime <= now (throws if too early)
    - Sets state = HATCHED
    - Sets hatchedAt = Date.now()
    - Generates auto name: 'Likha #' + id.slice(0, 6).toUpperCase()
    - Modifies this object in place
  
  isReadyToHatch(): boolean
    - Returns hatchTime <= Date.now()
  
  msUntilHatch(): number
    - If ready: returns 0
    - Else: returns hatchTime - Date.now()

Debugging tips:
- Log pet state: `console.log({ state: pet.state, hatchTime: pet.hatchTime, now: Date.now() });`
- Check isReadyToHatch: `console.log('Ready?', pet.isReadyToHatch(), 'ms left:', pet.msUntilHatch());`
- Verify name generation: `console.log('Pet name:', pet.name);` (should be auto-generated)
```

---

#### **5. MemoryStore.ts (In-Memory Storage)**

```
Purpose:
  Simple Map-based store for pet objects.
  No persistence; clears on server restart.

Properties:
  private pets: Map<id, Pet>

Public methods:
  
  save(pet: Pet): void
    - Adds or overwrites pet in map
    - Called after every mutation
  
  findById(id: string): Pet | undefined
    - Fetch pet by UUID
  
  findByOwner(owner: string): Pet[]
    - Return array of all pets with matching owner
  
  getAll(): Pet[]
    - Return all pets (internal use, testing)

Debugging tips:
- Check map size: `console.log('Pets in store:', store.getAll().length);`
- Find a pet: `console.log(store.findById('some-uuid'));`
- List all owner's pets: `console.log(store.findByOwner('player1'));`
- Inspect map directly: `console.log(store);` (not ideal, use methods)
```

---

#### **6. petRoutes.ts (HTTP Endpoints)**

```
Endpoints defined:

  POST /api/spawn-egg
    Body: { owner: string }
    Handler:
      1. Call HatcheryManager.spawnEgg(owner)
      2. If HatcheryError thrown → catch and return { status, error: msg }
      3. Else return Pet object as JSON
  
  GET /api/inventory?owner=player1
    Query: owner=string
    Handler:
      1. Call HatcheryManager.getInventory(owner)
      2. Return array of Pet objects
  
  POST /api/hatch/:id
    Params: id=UUID
    Body: { owner: string }
    Handler:
      1. Call HatcheryManager.hatchEgg(id, owner)
      2. If HatcheryError thrown → catch and return { status, error: msg }
      3. Else return hatched Pet object

Error handling:
  - Use try/catch for HatcheryError
  - Return { status: error.status, error: error.message }
  - Express middleware should catch all errors and log
```

Debugging tips:
- Enable request logging middleware:
  ```
  app.use((req, res, next) => {
    console.log(`${req.method} ${req.path} @ ${new Date().toISOString()}`);
    next();
  });
  ```
- Test with curl or Postman:
  ```
  curl -X POST http://localhost:3000/api/spawn-egg \
    -H "Content-Type: application/json" \
    -d '{"owner":"player1"}' \
    | jq
  ```
- Check response status: `curl -i http://localhost:3000/api/spawn-egg`
- Tail server logs: `npm run dev 2>&1 | grep -i error`

---

## Client Components (Phaser 3)

### File Structure

```
client/
├── src/
│   ├── main.ts                  ← Phaser boot config
│   ├── api/
│   │   └── ApiClient.ts         ← Typed fetch wrapper (PetData types)
│   ├── scenes/
│   │   ├── BootScene.ts         ← Asset loading, scene init
│   │   └── HatcheryScene.ts     ← Egg spawning, countdown, hatch UI
│   └── objects/
│       └── EggSprite.ts         ← Phaser Container (shell + label + glow)
├── public/
│   └── index.html               ← HTML entry point
├── webpack.config.js            ← Webpack dev server (proxies /api → :3000)
├── tsconfig.json
└── package.json
```

### Component Details

#### **1. main.ts (Phaser Boot)**

```
What it does:
  1. Create Phaser Game config
  2. Set up canvas dimensions (800x600)
  3. Configure physics (if used)
  4. Set BootScene as starting scene
  5. Instantiate game

Phaser Game Config:
  - type: AUTO (canvas or WebGL)
  - width: 800, height: 600
  - scene: BootScene (preload → create → update loop)
  - physics: Arcade (for future features)

Debugging tips:
- Check Phaser version: `npm list phaser`
- Log config: `console.log('Phaser config:', config);`
- Monitor FPS: Use Phaser's built-in stats (F12 → DevTools)
- Test rendering: Add a simple rectangle to BootScene and verify it displays
```

---

#### **2. ApiClient.ts (HTTP Wrapper)**

```
Purpose:
  Typed fetch wrapper for /api endpoints.
  Separates API concerns from scene logic.

Types defined (intentionally separate from shared/types.ts):
  PetState = 'Egg' | 'Hatched'
  Rarity = 'Common' | 'Uncommon' | 'Rare' | 'Epic' | 'Legendary'
  PetData = { id, dna, state, hatchTime, owner, attributes, name, createdAt, hatchedAt? }

Function: request<T>(url, options?)
  - Generic fetch wrapper
  - Throws error if !response.ok
  - Returns parsed JSON as type T

Exported methods:

  ApiClient.spawnEgg(owner: string): Promise<PetData>
    POST /api/spawn-egg
    Body: { owner }
    Returns: New Pet with state EGG, hatchTime = now + 30s
  
  ApiClient.getInventory(owner: string): Promise<PetData[]>
    GET /api/inventory?owner=...
    Returns: Array of all pets for owner
  
  ApiClient.hatchEgg(id: string, owner: string): Promise<PetData>
    POST /api/hatch/:id
    Body: { owner }
    Returns: Pet with state HATCHED, hatchedAt set

Debugging tips:
- Enable network tab in F12 → Network
- Log calls: Wrap methods to log params and response
  ```
  const original = ApiClient.spawnEgg;
  ApiClient.spawnEgg = async (owner) => {
    console.log('spawnEgg called:', owner);
    const pet = await original(owner);
    console.log('Got pet:', pet);
    return pet;
  };
  ```
- Test with curl to isolate server issues:
  ```
  curl -X POST http://localhost:3000/api/spawn-egg -d '{"owner":"player1"}' -H "Content-Type: application/json"
  ```
- Webpack proxy check: Inspect webpack.config.js devServer.proxy section
- CORS issues: Check server CORS middleware in index.ts
```

---

#### **3. HatcheryScene.ts (Main Game Scene)**

```
Purpose:
  Render egg list, spawn new eggs, display countdown timers, hatch on click.

Phaser Lifecycle:

  preload()
    - Load images, audio, sprites (from public/ or CDN)
    - Future: Load egg sprite assets
  
  create()
    - Initialize UI (buttons, text labels)
    - Fetch player inventory via ApiClient.getInventory()
    - Create EggSprite for each pet
    - Set up event handlers (click, timer)
  
  update(time, delta)
    - Called every frame (~60 FPS)
    - Tick down countdown timers on each egg
    - Update labels (e.g., "Tap to Hatch!" when ready)
    - Detect hatched eggs and update sprite

Key data:
  eggs: Map<petId, EggSprite>
    - Keep reference to all rendered eggs for update loop
  
  owner: string = 'player1' (MVP, hardcoded)

Event handlers:

  onSpawnClick()
    1. Call ApiClient.spawnEgg(owner)
    2. Create EggSprite for new pet
    3. Add to eggs map
    4. Position on screen
  
  onEggClick(eggSprite, petId)
    1. Check if pet.hatchTime <= now
    2. If ready: Call ApiClient.hatchEgg(petId, owner)
    3. Update EggSprite state (shell color, label)
  
  onUpdate(time, delta)
    1. For each egg in eggs map:
       a. Decrement timer: egg.msRemaining -= delta
       b. Update label text: egg.setTimerLabel(...)
       c. Check if ready (msRemaining <= 0)
       d. If ready, show "Tap to Hatch!" label

Debugging tips:
- Log owner and pet count: `console.log('Owner:', owner, 'Pets:', eggs.size);`
- Log hatch timer math: `console.log('hatchTime:', pet.hatchTime, 'now:', Date.now(), 'ms left:', pet.hatchTime - Date.now());`
- Pause update loop: Add `if (KEY_DOWN) return;` to test static state
- Visual debugging: Add text labels showing timer values in real-time
- Network issues: Check browser Network tab when ApiClient calls are slow
```

---

#### **4. EggSprite.ts (Phaser Container)**

```
Purpose:
  Visual representation of an egg.
  Phaser Container with shell graphic, countdown label, and glow animation.

Structure:
  EggSprite extends Container
    ├─ Shell (Circle or Sprite)
    │  └─ Color determined by pet.attributes.color
    ├─ Label (Text)
    │  └─ Countdown timer or "Tap to Hatch!"
    └─ Glow (Tween animation)
       └─ Alpha fade in/out after hatch

Properties:
  petId: string (pet UUID)
  state: PetState (EGG or HATCHED)
  msRemaining: number (milliseconds until hatch)
  timerLabel: Text (Phaser Text object)
  shell: Sprite or Circle (visual)

Public methods:

  setTimerLabel(msRemaining: number): void
    - Format ms to MM:SS or show "Ready!"
    - Update timerLabel.text
  
  updateState(state: PetState, msRemaining: number): void
    - Transition from EGG to HATCHED
    - Change shell color or outline
    - Play glow animation
  
  onClick(): void (event handler)
    - Emit 'hatch-request' event
    - Scene listens and calls HatcheryScene.onEggClick()

Phaser quirks:
- Containers are invisible by default; set visible = true
- Text objects need font size in setFont() or constructor
- Tweens need to be created before play() is called
- Event listeners: use this.once() or this.on() for click/input

Debugging tips:
- Check visibility: `console.log('Visible?', eggSprite.visible);`
- Check text: `console.log('Label:', eggSprite.timerLabel.text);`
- Check tween: `console.log('Tween running?', eggSprite.tweens.getTweens().length > 0);`
- Position on click: `this.input.on('pointerdown', (pointer) => console.log(pointer.x, pointer.y));`
- Color validation: `console.log('Shell color:', eggSprite.shell.tint);` (Phaser uses 0xRRGGBB format)
```

---

## Battle Engine (Pure Dart)

### File Structure

```
battle_engine/
├── lib/
│   ├── battle_engine.dart        ← Main orchestrator (nextRound(), run())
│   ├── pet.dart                  ← Pet model (hp, buffs, debuffs)
│   ├── trait.dart                ← Trait model & TraitLibrary (20 skills)
│   ├── action_resolver.dart      ← Apply damage, buffs, debuffs
│   ├── turn_manager.dart         ← Turn order (speed-based)
│   ├── ai_controller.dart        ← Enemy AI decision logic
│   ├── battle_state.dart         ← Immutable snapshot for UI
│   ├── battle_logger.dart        ← Human-readable battle log
│   └── energy_pool.dart          ← Shared team energy system
├── bin/main.dart                 ← CLI demo executable
├── pubspec.yaml
└── test/ (minimal)
```

### Component Details

#### **1. BattleEngine.dart (Main Orchestrator)**

```
Purpose:
  Run a complete 3v3 turn-based battle deterministically.

Constructor:
  BattleEngine({
    required List<Pet> teamA,
    required List<Pet> teamB,
    String teamAName = 'Team A',
    String teamBName = 'Team B',
  })
  - Accepts two teams of 3 pets each
  - Initializes internal state (turn manager, AI, logger)

Main method:

  BattleResult run()
    1. Log header and team status
    2. Loop (max 30 rounds):
       a. If all 3 of one team are fainted → declare winner
       b. Get next actor via TurnManager.getNextActor()
       c. Decide action via AI or player input
       d. Apply action via ActionResolver
       e. Update BattleState snapshot
       f. Log round summary
    3. Return BattleResult (outcome, totalRounds, log, events, stateHistory)

Key properties:
  teamA, teamB: Teams
  _logger: BattleLogger (accumulates log)
  _turns: TurnManager (tracks turn order)
  _ai: AiController (enemy AI)
  _history: List<BattleState> (one snapshot per round)

Debugging tips:
- Run CLI demo: `dart run bin/main.dart` → prints trait ref and full battle log
- Check BattleResult: `print(result.log);` to see human-readable transcript
- Inspect events: `for (var e in result.events) print(e);`
- Verify determinism: Run same battle twice with same seed → should be identical
- Track pet HP: Add logs in ActionResolver.applyDamage()
```

---

#### **2. Pet.dart (Pet Model)**

```
Purpose:
  Represent a battle-ready pet with stats, buffs, debuffs, and energy.

Properties:
  id: string (unique identifier)
  name: string (display name)
  traits: List<Trait> (3 trait objects)
  speed: int (determines turn order)
  hp: int (health points, 0 = fainted)
  shield: int (damage absorption)
  isFainted: bool
  debuffs: List<StatusEffect> (poison, burn, stun, etc.)
  buffs: List<BuffEffect> (ATK↑, DEF↑, SPD↑, Regen)
  _pool: EnergyPool? (shared team energy, set via linkPool())

Computed stats (with buffs):
  effectiveAttack = baseAttack + (buffEffect.value if ATK↑ else 0)
  effectiveDefense = baseDefense + (buffEffect.value if DEF↑ else 0)
  effectiveSpeed = baseSpeed + (buffEffect.value if SPD↑ else 0)

Energy system:
  Each pet can link to a shared EnergyPool via linkPool(pool).
  After linking, energy getter returns pool.energy instead of _ownEnergy.
  This allows the team to share energy (3 per round, +2 regen, cap 9).

Key methods:

  applyDamage(raw: int): void
    - Reduce shield first
    - Then reduce hp
    - Set isFainted if hp <= 0
  
  applyBuff(buffType, value, duration): void
    - Add to buffs list with duration
    - Stacks additively
  
  applyStatusEffect(debuffType, value, duration): void
    - Add to debuffs list
    - Poison/Burn ticks each round
    - Stun skips next turn
  
  tickEffects(): void
    - Decrement buff/debuff durations
    - Tick damage effects (poison, burn)
    - Remove expired effects
  
  canAfford(energyCost: int): bool
    - Check if energy >= cost
  
  spendEnergy(cost: int): void
    - Deduct from pool or _ownEnergy
  
  clone(): Pet
    - Deep copy for testing

Debugging tips:
- Log stats: `print('${pet.name}: hp=${pet.hp}, shield=${pet.shield}, speed=${pet.speed}');`
- Check buffs: `for (var b in pet.buffs) print('${b.type}: +${b.value} for ${b.roundsRemaining} more');`
- Check debuffs: `for (var d in pet.debuffs) print('${d.type}: ${d.value} damage/round for ${d.roundsRemaining} more');`
- Verify energy: `print('Energy: ${pet.energy}');`
- Test damage calc: `pet.applyDamage(50); print('New HP: ${pet.hp}');`
```

---

#### **3. Trait.dart (Skills & Abilities)**

```
Purpose:
  Define 20 battle abilities with effects, energy costs, cooldowns, and metadata.

Enums:
  TraitType: offensive, defensive, support, utility
  EffectType: damage, shield, heal, buff, debuff, aoe, shieldBreak
  BuffType: attackUp, defenseUp, speedUp, energized, regen
  DebuffType: attackDown, defenseDown, stunned, poisoned, burned, speedDown
  SkillRarity: common, rare, epic

Class: TraitEffect
  type: EffectType (what happens)
  value: int (damage, heal, buff amount)
  buffType/debuffType: optional (if type is buff/debuff)
  duration: int (rounds the effect lasts; 0 = instant)
  target: string ('enemy', 'ally', 'self', 'all_enemies', 'all_allies', 'lowest_hp_enemy', etc.)

Class: Trait
  id: string (unique ID)
  name: string (display name)
  type: TraitType
  energyCost: int (team energy required)
  cooldownMax: int (turns until usable again)
  effect: TraitEffect
  description: string (human-readable)
  rarity: SkillRarity
  tags: List<string> ('damage', 'aoe', 'heal', etc.)
  cooldownRemaining: int (mutable, decremented each turn)

Public methods:

  isReady: bool
    - Returns cooldownRemaining == 0
  
  triggerCooldown(): void
    - Set cooldownRemaining = cooldownMax
  
  tickCooldown(): void
    - Decrement cooldownRemaining if > 0
  
  clone(): Trait
    - Deep copy (preserves cooldownRemaining)

TraitLibrary (20 predefined traits):
  bakunawaSwallow ✓ Offensive: 50 dmg to lowest-HP enemy
  lakanCounter ✓ Defensive: +15 DEF for 2 rounds
  amihanVeil ✓ Defensive: 40 damage shield
  sarimanokAura ✓ Support: Heal 35 HP to lowest-HP ally
  tikbalangCharge ✓ Offensive: 30 dmg to single enemy
  manananggalDrain ✓ Offensive: Poison (8 dmg/rd × 3 rounds)
  anakngLupaSlam ✓ Offensive: 25 dmg AoE to all enemies
  diwataBlessing ✓ Support: 20 HP heal to all allies
  bayanihanShield ✓ Support: +15 DEF to all allies for 2 rounds
  kapreSmoke ✓ Utility: -10 ATK to all enemies for 2 rounds
  enkantoFlash ✓ Utility: Stun 1 enemy for 1 round
  aswangFang ✓ Offensive: 45 dmg to single enemy
  tikbalangSnipe ✓ Offensive: 35 dmg to back-row enemy
  sigbinShadow ✓ Utility: -10 DEF + SPD↓ to front enemy for 2 rounds
  nunoRegen ✓ Support: Regen 15 HP/round to self for 3 rounds
  perlasStrike ✓ Offensive: 20 AoE dmg + shield break
  bathalaWrath ✓ Offensive: 60 dmg (+20 if poisoned)
  agimatWard ✓ Defensive: Remove enemy shield + 30 shield to self
  lambanaDance ✓ Support: 25 heal + cleanse 1 debuff
  kulamCurse ✓ Utility: Poison + Burn stacked

Debugging tips:
- Check trait exists: `print(TraitLibrary.bakunawaSwallow);`
- Verify costs: `for (var t in traits) print('${t.name}: energy=${t.energyCost}, cd=${t.cooldownMax}');`
- Test trait clone: `var t1 = TraitLibrary.bakunawaSwallow; var t2 = t1.clone(); t2.cooldownRemaining = 2; print(t1.cooldownRemaining); // should be 0`
- Check effect target: `print('Target: ${effect.target}');` (should be specific for selector)
```

---

#### **4. ActionResolver.dart (Action Application)**

```
Purpose:
  Apply a trait action to targets, updating pet stats, effects, etc.

Main method:

  static void resolveAction(actor: Pet, trait: Trait, targets: List<Pet>, teamEnergyPool: EnergyPool)
    1. Validate energy: actor.canAfford(trait.energyCost)
    2. Spend energy: teamEnergyPool.spend(trait.energyCost)
    3. Trigger cooldown: trait.triggerCooldown()
    4. Apply effect based on trait.effect.type:
       a. DAMAGE: Calculate netDmg = max(1, raw - defense), apply shield then hp
       b. SHIELD: Add to target shield
       c. HEAL: Increase target hp, cap at max
       d. BUFF: Add to buffs, set duration
       e. DEBUFF: Add to debuffs, set duration
       f. AOE: Apply damage to all targets (capped 30 per target)
       g. SHIELDBREAK: Remove target shield + apply shield to actor
    5. Select targets based on effect.target:
       - 'enemy': one random enemy
       - 'all_enemies': all enemies
       - 'lowest_hp_enemy': enemy with min hp
       - 'lowest_hp_ally': ally with min hp
       - etc.

Damage calculation:
  raw = trait.effect.value
  defense = target.effectiveDefense (includes buffs)
  netDmg = max(1, raw - defense)
  
  Single-target cap: min(netDmg, 90)
  AoE cap: min(netDmg, 30) per target

Status effect ticks:
  Poison: value damage per round, duration rounds
  Burn: value damage per round, duration rounds
  Stun: target skips next turn
  Buffs: stacks additively (e.g., +15 DEF + +15 DEF = +30 DEF)
  Debuffs: reduce stat based on type (ATK↓, DEF↓, SPD↓)

Debugging tips:
- Log damage calc: `print('raw=$raw, defense=${target.effectiveDefense}, net=$netDmg');`
- Log energy spend: `print('Energy before: ${pool.energy}'); pool.spend(cost); print('After: ${pool.energy}');`
- Log target selection: `print('Targets: ${targets.map((t) => t.name).join(', ')}');`
- Test with specific traits: Run battle with known team, log each action
- Verify caps: Test 100 dmg vs 10 DEF → should be capped at 90
```

---

#### **5. TurnManager.dart (Turn Order)**

```
Purpose:
  Maintain turn order based on pet speed, reset each round, track whose turn it is.

Turn order algorithm:
  1. At start of round: Get all alive pets from both teams
  2. Sort by speed descending (higher speed acts first)
  3. Break ties consistently (by ID or insertion order)
  4. Return next actor from sorted list

Key methods:

  void resetRound(teamA: List<Pet>, teamB: List<Pet>)
    1. Gather all alive pets
    2. Sort by speed
    3. Reset current actor index to 0
  
  Pet getNextActor(): Pet
    1. If no more actors this round → return null (round ends)
    2. Return next pet from sorted list
    3. Increment index
  
  bool hasMoreActors(): bool
    - Check if current index < sorted list length

Debugging tips:
- Log turn order: `for (var p in actors) print('${p.name} (speed=${p.speed})');`
- Verify speed buffs affect order: Apply SPD↑, resetRound() again, log new order
- Check roundsReset: Verify actors list is rebuilt each round (speed changes should matter)
```

---

#### **6. AiController.dart (Enemy AI)**

```
Purpose:
  Decide what trait an enemy pet should use (greedy heuristic).

Decision priority:

  1. If self.hp < 30% → use healing trait (highest value)
  2. If enemy.hp > 70% → use stun trait (Enkanto Flash)
  3. If self.shield < 10 AND cooldown ready → use shield trait
  4. If all enemies alive → use AoE trait
  5. If team has no buffs → use team buff trait (Bayanihan Shield)
  6. Else → use best single-target damage

Public method:

  Trait decideAction(actor: Pet, allies: List<Pet>, enemies: List<Pet>)
    1. Filter traits: only isReady and can afford
    2. Evaluate each trait against heuristics above
    3. Return highest-priority matching trait
    4. If none: return basic attack (lowest cost, highest dmg)

Debugging tips:
- Log decision: `print('AI choosing: ${chosen.name} for ${actor.name}');`
- Log evaluation: `for (var t in candidates) print('${t.name}: priority=${priority(t)}');`
- Test with specific scenarios: Create team, set low HP, call decideAction(), verify heal chosen
- Verify energy check: Try to choose expensive trait without energy → should skip
```

---

#### **7. BattleState.dart (UI Snapshot)**

```
Purpose:
  Immutable snapshot of battle state after each action, used for UI rendering.

Properties:
  teamASnapshot: List<PetSnapshot> (one per pet)
  teamBSnapshot: List<PetSnapshot>
  
  PetSnapshot contains:
    - hp, maxHp
    - shield
    - isFainted
    - name, rarity color
    - buffs, debuffs (with duration remaining)
    - activeTraits (ready vs on cooldown)

Usage:
  1. After each action, create BattleState snapshot
  2. Pass to Flutter UI for rendering
  3. UI doesn't need to know battle logic, just display snapshot
  4. State history allows "rewind" feature in future

Debugging tips:
- Log snapshot: `print(state.teamASnapshot[0]);`
- Verify updates: Action → create snapshot → check hp/shield changed
- Test immutability: Snapshot shouldn't affect live battle state
```

---

#### **8. bin/main.dart (CLI Demo)**

```
Purpose:
  Executable demonstration of BattleEngine.

What it does:
  1. Create 2 teams of 3 pets with random traits
  2. Instantiate BattleEngine
  3. Call run()
  4. Print battle log to stdout
  5. Report outcome

Output:
  LIKHA PET BATTLE
  Team A vs Team B
  ================================================
  [Round 1]
    [Actor] Aquatic A uses Bakunawa Swallow
    [Target] Beast B takes 45 damage
  ...
  Team A wins in 8 rounds!

Usage:
  dart run bin/main.dart
  dart run bin/main.dart > battle.log 2>&1

Debugging:
  - Inspect generated teams: Add logging before run()
  - Verify traits: Check TraitLibrary is accessible
  - Check determinism: Run twice, save logs, diff them (should be identical if no randomness in AI)
```

---

## Data Flow & Request/Response Cycles

### Web Prototype Flow (MVP)

```
USER ACTION: "Spawn Egg" button clicked

1. CLIENT
   HatcheryScene.onSpawnClick()
   → ApiClient.spawnEgg('player1')
   → fetch(POST, '/api/spawn-egg', body='{"owner":"player1"}')

2. WEBPACK (dev mode)
   → Intercept /api/* prefix
   → Proxy to http://localhost:3000/api/spawn-egg

3. SERVER
   express.json() middleware
   → parses body to JSON
   → petRoutes handler for POST /api/spawn-egg
   → HatcheryManager.spawnEgg('player1')
   → DNADecoder.generateDNA() = 'a1b2c3d4e5f6a7b8c9d0e1f2'
   → DNADecoder.decode('a1b2...') = {color: '#2ECC71', rarity: 'Uncommon', ...}
   → new Pet(uuid, dna, hatchTime, owner='player1', attributes)
   → MemoryStore.save(pet)
   → return pet object to client

4. CLIENT (async/await resolves)
   ApiClient returns PetData
   → HatcheryScene receives egg
   → Create EggSprite(egg)
   → Add to eggs map
   → Render on screen

5. UI LOOP (every frame)
   → HatcheryScene.update(time, delta)
   → For each egg: decrement timer, update label
   → When msRemaining <= 0: show "Tap to Hatch!"

6. USER ACTION: "Tap to Hatch" on ready egg

7. CLIENT
   EggSprite.onClick()
   → HatcheryScene.onEggClick(eggSprite, petId)
   → ApiClient.hatchEgg(petId, 'player1')
   → fetch(POST, '/api/hatch/:id', body='{"owner":"player1"}')

8. SERVER
   petRoutes handler for POST /api/hatch/:id
   → HatcheryManager.hatchEgg(id, 'player1')
   → Fetch from MemoryStore
   → Validate ownership, check timer
   → pet.hatch() → state=HATCHED, hatchedAt=now, name='Likha #...'
   → MemoryStore.save(pet)
   → return hatched pet

9. CLIENT (async resolves)
   → Update EggSprite.state = HATCHED
   → Change shell color (rarity-based)
   → Play glow animation
   → Update label to pet name

Done!
```

### Mobile Game Flow (Future)

```
USER ACTION: "Battle" button

1. APP
   BattlePage
   → Fetch team from Firebase
   → Fetch enemy team from Firebase
   → BattleEngine engine = new(...teams)
   → result = engine.run()

2. BATTLE ENGINE (pure Dart, no I/O)
   → 30 rounds max
   → Each round:
     - TurnManager picks next actor
     - AiController or player chooses trait
     - ActionResolver applies damage/effects
     - BattleState snapshot for UI
   → Return BattleResult (outcome, log, events, history)

3. APP
   → Display BattleResult events with animations
   → user.stats.update(win/loss)
   → POST /validatePvE (Cloud Function)
   → Cloud Function re-runs battle, verifies outcome
   → Grant rewards

Cloud Function (server-side):
   1. Receive battleResult from app
   2. Fetch team snapshots from Firestore (match player IDs)
   3. Re-run BattleEngine (same inputs)
   4. Compare outcomes
   5. If match: approve and grant rewards
   6. Else: reject (anti-cheat)
```

---

## How to Debug

### 1. Server-Side Debugging

#### Option A: Console logs

```typescript
// In HatcheryManager.spawnEgg()
console.log('spawnEgg called for owner:', owner);
const dna = DNADecoder.generateDNA();
console.log('Generated DNA:', dna);
const attributes = DNADecoder.decode(dna);
console.log('Decoded attributes:', attributes);
const pet = new Pet(id, dna, hatchTime, owner, attributes);
console.log('Created pet:', pet);
this.store.save(pet);
console.log('Saved pet to store');
```

Run: `npm run dev` (logs appear in terminal)

#### Option B: VSCode debugger

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Launch Server",
      "program": "${workspaceFolder}/server/src/index.ts",
      "preLaunchTask": "npm: dev",
      "outFiles": ["${workspaceFolder}/server/dist/**/*.js"]
    }
  ]
}
```

Set breakpoints, step through code, inspect variables.

#### Option C: API testing with curl

```bash
# Spawn egg
curl -X POST http://localhost:3000/api/spawn-egg \
  -H "Content-Type: application/json" \
  -d '{"owner":"player1"}' \
  | jq .

# Get inventory
curl http://localhost:3000/api/inventory?owner=player1 | jq .

# Hatch (replace UUID with real pet id)
curl -X POST http://localhost:3000/api/hatch/[uuid] \
  -H "Content-Type: application/json" \
  -d '{"owner":"player1"}' \
  | jq .
```

---

### 2. Client-Side Debugging

#### Option A: Browser DevTools (F12)

- **Console:** Log ApiClient calls
  ```javascript
  // Override methods to log
  const origSpawn = window.ApiClient?.spawnEgg;
  window.ApiClient.spawnEgg = async (owner) => {
    console.log('spawnEgg called:', owner);
    const result = await origSpawn(owner);
    console.log('Got pet:', result);
    return result;
  };
  ```

- **Network tab:** Inspect HTTP requests/responses
  - POST /api/spawn-egg → check status, body, response
  - GET /api/inventory → verify array of pets

- **Application tab:** Check Local Storage, Session Storage (if used)

#### Option B: Phaser debug mode

```typescript
// In main.ts
const config = {
  debug: true,
  physics: {
    arcade: {
      debug: true,  // show collision bounds
    }
  }
};
```

#### Option C: Scene logs

```typescript
// In HatcheryScene.create()
console.log('Creating HatcheryScene');
const pets = await ApiClient.getInventory('player1');
console.log('Fetched pets:', pets);
pets.forEach((pet) => {
  console.log(`Creating egg: ${pet.name}, hatchTime=${pet.hatchTime}, now=${Date.now()}, ms left=${pet.hatchTime - Date.now()}`);
  const egg = new EggSprite(this, pet);
  this.eggs.set(pet.id, egg);
});
```

---

### 3. Battle Engine Debugging

#### Option A: CLI demo with logging

```dart
// In bin/main.dart, modify _runBattle()
final engine = BattleEngine(teamA: teamA, teamB: teamB);
int round = 1;
while (!engine.isComplete && round <= 30) {
  print('=== ROUND $round ===');
  print('Before:');
  for (var p in [...engine.teamA, ...engine.teamB]) {
    if (!p.isFainted) {
      print('  ${p.name}: hp=${p.hp}, shield=${p.shield}, energy=${p.energy}');
    }
  }
  
  engine.nextRound();
  
  print('After:');
  for (var p in [...engine.teamA, ...engine.teamB]) {
    if (!p.isFainted) {
      print('  ${p.name}: hp=${p.hp}, shield=${p.shield}');
    }
  }
  round++;
}
final result = engine.run();
print('\n=== BATTLE LOG ===');
print(result.log);
```

Run: `dart run bin/main.dart`

#### Option B: Dart test suite

```dart
// test/battle_engine_test.dart
test('determinism: same inputs produce same outcome', () {
  final team1 = [Pet(...), Pet(...), Pet(...)];
  final team2 = [Pet(...), Pet(...), Pet(...)];
  
  final engine1 = BattleEngine(teamA: team1.map((p) => p.clone()).toList(), ...);
  final result1 = engine1.run();
  
  final engine2 = BattleEngine(teamA: team1.map((p) => p.clone()).toList(), ...);
  final result2 = engine2.run();
  
  expect(result1.outcome, result2.outcome);
  expect(result1.totalRounds, result2.totalRounds);
});
```

Run: `dart test`

#### Option C: Inspect BattleState

```dart
// In BattleEngine.nextRound()
final state = BattleState.from(teamA, teamB);
print('State after action:');
print('Team A:');
for (var snap in state.teamASnapshot) {
  print('  ${snap.name}: hp=${snap.hp}, shield=${snap.shield}');
}
```

---

### 4. Type Safety Debugging

#### TypeScript/JavaScript

```typescript
// Check PetData type at runtime
function logPet(pet: PetData) {
  if (!pet.id || !pet.dna) {
    throw new Error('Invalid pet: missing id or dna');
  }
  console.log(`Pet ${pet.name} (${pet.state}): rarity=${pet.attributes.rarity}`);
}
```

#### Dart

```dart
// Check Pet type at runtime
void logPet(Pet pet) {
  assert(pet.id.isNotEmpty, 'Pet id cannot be empty');
  assert(pet.hp >= 0 && pet.hp <= 150, 'Pet hp out of range');
  print('Pet ${pet.name}: hp=${pet.hp}');
}
```

---

## Common Issues & Solutions

### Server Issues

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| Port 3000 already in use | `lsof -i :3000` | `kill -9 [PID]` or change PORT env var |
| "Cannot find module" | Missing `npm install` | `cd server && npm install` |
| Fetch returns 404 | URL wrong or endpoint not registered | Check `petRoutes.ts`, verify path |
| Ownership validation fails | Wrong owner in request | Use 'player1' (hardcoded in MVP) |
| DNA decode always same | Not random | Check `DNADecoder.generateDNA()` uses `Math.random()` |
| HatcheryError not caught | Middleware not set up | Add error handler before `app.listen()` |

### Client Issues

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| Network requests hanging | Webpack proxy misconfigured | Check `webpack.config.js` devServer.proxy |
| 404 on /api call | Server not running | `npm run dev` in server/ first |
| CORS error | Missing CORS middleware | Check `index.ts` has `app.use(cors())` |
| Phaser scene blank | Scene not visible | Check `create()` calls `this.add.` and `visible=true` |
| Timer not counting down | `update()` not calling | Check Phaser lifecycle, verify `delta` parameter |
| Egg not clickable | Missing input event | Check `EggSprite` registers click listener |

### Battle Engine Issues

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| CLI hangs | Infinite loop in AI | Add round counter, max 30 rounds |
| Team fainted too fast | Damage calc wrong | Verify damage formula: `max(1, raw - def)` |
| Traits not available | Traits not cloned for battle | Clone traits when creating pet |
| Energy depleted too fast | Shared pool bug | Verify `linkPool()` called for all pets |
| Turn order wrong | Speed not considered | Verify `TurnManager.resetRound()` sorts by speed |

---

## Debugging Checklist

- [ ] Server running: `npm run dev` in `server/` directory
- [ ] Client running: `npm run dev` in `client/` directory (should open http://localhost:8080)
- [ ] Network tab: Monitor requests/responses (F12 → Network)
- [ ] Console logs: Check both server terminal and browser console
- [ ] Ownership: Ensure requests use 'player1' (hardcoded)
- [ ] Timestamps: Verify hatchTime math (now + 30000ms)
- [ ] DNA: Test determinism with multiple generations
- [ ] Hatch timer: Check if msUntilHatch() decreases over time
- [ ] Battle: Run `dart run bin/main.dart` to test determinism
- [ ] Types: Verify PetData matches in client and server

---

**For more details, see [AGENTS.md](AGENTS.md) and [skills.md](skills.md).**

