# CLAUDE.md — Quick Reference

This file provides quick guidance. **For comprehensive documentation, see [AGENTS.md](AGENTS.md).**

## At a Glance

Likha Pet is a **multi-module game engine** combining a Flutter app, pure Dart battle engine, Express API, and Phaser web prototype. Each sub-project is independently managed (no root `package.json`).

**Quickstart:** `./run.sh` (starts Firebase, server, client, battle demo)

## Module Breakdown

| Module | Tech | Role |
|--------|------|------|
| **app/** | Flutter 3.x + Riverpod | Main game (iOS/Android/Web) |
| **battle_engine/** | Pure Dart (CLI) | Deterministic battle simulation, no I/O |
| **server/** | Express + TypeScript | Pet lifecycle API |
| **client/** | Phaser 3 + TypeScript | Web prototype (egg hatching demo) |
| **shared/** | TypeScript | Canonical type definitions |

## Key Architecture

- **Server flow:** `petRoutes` → `HatcheryManager` → `DNADecoder` + `MemoryStore`
- **Client flow:** `HatcheryScene` → `ApiClient` → Express API
- **Battle flow:** `BattleEngine` (pure Dart) runs 3v3 turn-based combat deterministically

**Shared types:** `shared/types.ts` is canonical. Server re-exports from it; client duplicates intentionally (avoids bundling server code).

## API Endpoints (MVP)

| Method | Path | Body | Description |
|--------|------|------|-------------|
| POST | `/api/spawn-egg` | `{ owner }` | New egg with random DNA |
| GET | `/api/inventory` | `?owner=` | All pets for owner |
| POST | `/api/hatch/:id` | `{ owner }` | Hatch egg (if timer elapsed) |

## MVP Limitations

- **30s hatch timer** hardcoded in `HatcheryManager`
- **Owner 'player1'** hardcoded; no JWT auth yet
- **No persistence:** MemoryStore clears on restart
- **Mobile-first:** portrait-forced, 360px+ width target

## Common Commands

```bash
cd server && npm run dev              # Server hot-reload
cd client && npm run dev              # Client :8080 (proxies /api → :3000)
cd app && flutter run                 # Flutter on device/emulator
cd battle_engine && dart run bin/main.dart  # CLI battle demo
npm test                              # Jest tests (server only)
```

## For More Details

👉 **Full architecture, conventions, troubleshooting:** [AGENTS.md](AGENTS.md)  
👉 **Battle system algorithm:** [skills.md](skills.md)  
👉 **Orchestration & port config:** [run.sh](run.sh)
