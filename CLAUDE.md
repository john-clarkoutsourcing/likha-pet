# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Likha Pet is a browser-based virtual pet game. Players spawn eggs with randomly generated DNA, wait for a countdown timer, then hatch them to reveal their creature's attributes. The repo has three top-level directories with no root `package.json` — each sub-project is managed independently.

## Commands

### Server (`cd server`)
```bash
npm run dev        # start with ts-node-dev (hot-reload)
npm run build      # compile TypeScript → dist/
npm start          # run compiled output
npm test           # run all Jest tests
npx jest --testPathPattern=DNADecoder  # run a single test file
```

### Client (`cd client`)
```bash
npm run dev        # webpack-dev-server on http://localhost:8080 (proxies /api → :3000)
npm run build      # production bundle → dist/
```

Tests only exist in `server/`. The client has no test suite.

## Architecture

```
shared/types.ts          ← canonical TypeScript types (PetDTO, DNAAttributes, Rarity, PetState)
server/src/              ← Express + TypeScript API
client/src/              ← Phaser 3 + TypeScript game
```

### Server data flow

`petRoutes` → `HatcheryManager` → `DNADecoder` + `MemoryStore`

- **`DNADecoder`** — static class; `generateDNA()` produces a 24-char hex string (12 bytes); `decode(dna)` maps each hex-pair deterministically to a trait (color@0, rarity@2, basePower@4–7, element@8, pattern@10). Same DNA always yields the same creature.
- **`HatcheryManager`** — orchestrates all pet lifecycle operations; throws `HatcheryError(status, message)` for domain errors so the router can return typed HTTP status codes.
- **`MemoryStore`** — an in-memory `Map`. All data is lost on server restart; there is no persistence layer yet.
- **`BasePet`** — abstract class that re-exports shared types and provides `isReadyToHatch()` / `msUntilHatch()`. `Pet` extends it and adds `name` and `hatch()`.

### Client data flow

`HatcheryScene` → `ApiClient` → Express API  
`HatcheryScene` creates `EggSprite` objects and drives a 500ms tick loop to update countdown timers.

- **`ApiClient`** — thin typed `fetch` wrapper; uses relative `/api` path (webpack-dev-server proxies to `:3000`).
- **`EggSprite`** — Phaser `Container` that renders the egg shell (color + rarity outline), countdown or "Tap to Hatch!" label, and a glow tween after hatching. Fires `onHatchRequest(id)` when clicked while ready.
- **`BootScene`** — currently a passthrough to `HatcheryScene`; reserved for asset loading.

### Shared types

`shared/types.ts` is the source of truth. `server/src/models/BasePet.ts` re-exports from it. The client's `ApiClient.ts` defines its own parallel type aliases (`PetData`) rather than importing from `shared/` — this is intentional to avoid bundling server-side code into the webpack build.

## Platform Target

The game must be **mobile-capable**. All UI, layouts, and interactions must work on mobile screen sizes and touch input. Design decisions should prioritize mobile-first; desktop support is secondary.

- Touch targets: minimum 44×44px interactive areas
- Layouts: responsive to portrait orientation on small screens (360px width minimum)
- Input: assume tap/swipe as primary interaction; mouse/keyboard as fallback
- The Phaser client should use `scale.mode: Phaser.Scale.FIT` or equivalent to adapt to device screen dimensions

## Key Constants and MVP Limitations

- Hatch duration is hardcoded to `30_000 ms` in `HatcheryManager`.
- Owner identity is hardcoded to `'player1'` in `HatcheryScene` — no auth system exists yet.
- No persistence: restarting the server clears all pets.

## API Endpoints

| Method | Path | Body / Query | Description |
|--------|------|-------------|-------------|
| POST | `/api/spawn-egg` | `{ owner }` | Creates a new egg with random DNA |
| GET | `/api/inventory` | `?owner=` | Returns all pets for an owner |
| POST | `/api/hatch/:id` | `{ owner }` | Hatches an egg (if timer has elapsed) |
| GET | `/health` | — | Server liveness check |
