# Battle Alignment Plan

## Objective
Align the current game implementation with:
- `layout_design_battle.md` (battle UI/UX layout and art direction)
- `battle_game_mechanics.md` (Axie Classic mechanics baseline)

This document is the execution baseline. Implementation starts only after approval.

---

## Priority Order
1. Core battle rules parity (highest impact, correctness)
2. Targeting and chain behavior parity
3. Top HUD and battlefield structure parity
4. Bottom card/action UI parity
5. Motion/VFX polish

---

## Phase 1: Core Rules Lock-In

### Scope
- Update energy cap from 9 to 10
- Remove hand cap for Classic mode
- Preserve dead-card behavior in deck cycle (do not auto-filter dead-owner cards from hand draws)
- Fix turn tie-break logic order to:
  1. Speed (higher first)
  2. Current HP (lower first)
  3. Skill (higher first)
  4. Morale (higher first)
- Align deck construction to 24-card classic cycle model (3 Axies x 4 parts x 2 copies)

### Expected Impact
- Immediate mechanics parity improvements
- More authentic energy/card economy
- Deterministic turn order consistent with Classic rules

### Risk Notes
- PvP sync assumptions rely on deterministic deck/turn order. Any logic changes must keep deterministic seeds and ordering intact.

---

## Phase 2: Targeting and Chain Logic

### Scope
- Implement lane-aware closest-target behavior:
  - Standard closest targeting
  - Split-path behavior for symmetric front options
  - Mid-lane 50/50 in symmetric split case
- Add first-class chain detection across different Axies by class type
- Apply generic chain effects and chain-required card conditions where applicable

### Expected Impact
- Tactical behavior matches described lane/selection dynamics
- Better parity with card text requiring chain conditions

### Risk Notes
- Must maintain predictable target resolution in PvP for server/client parity.

---

## Phase 3: Top HUD and Battlefield Layout Parity

### Scope
- Top HUD restyle and structure alignment:
  - Left player info panel (wood signboard style)
  - Center initiative timeline emphasis
  - Right utility icon cluster (settings/deck)
- Keep current readability and responsive behavior in landscape
- Ensure layering order remains:
  Background -> Ground -> Shadows -> Characters -> Unit HUD -> Top HUD -> Bottom Panel

### Expected Impact
- Stronger visual alignment with `layout_design_battle.md`
- Better hierarchy and player eye flow

---

## Phase 4: Bottom Action Area Parity

### Scope
- Energy orb visual treatment update (classic-style circular indicator)
- Card frame readability and type framing polish
- End Turn CTA redesign (high-contrast orange/yellow, stronger emphasis)
- Maintain existing interaction behavior and card assignment logic

### Expected Impact
- Improved legibility and interaction clarity
- Better style parity with target layout

---

## Phase 5: Animation and FX Polish

### Scope
- Unit idle micro-motion tuning (bounce/squash subtle pass)
- HP drain smoothness and active turn pulse emphasis
- Hit shake and class particle consistency pass

### Expected Impact
- Better battle feel without changing rules

---

## Missing Assets Plan (Temporary Placeholders)

If any required assets are missing, create temporary files using final target filenames so they can be replaced later without code changes.

### Planned Placeholder Filenames
1. `assets/images/ui/battle_v2/top_panel_wood_left.png`
2. `assets/images/ui/battle_v2/top_panel_wood_right.png`
3. `assets/images/ui/battle_v2/top_panel_wood_center.png`
4. `assets/images/ui/battle_v2/utility_btn_circle.png`
5. `assets/images/ui/battle_v2/icon_settings.png`
6. `assets/images/ui/battle_v2/icon_deck.png`
7. `assets/images/ui/battle_v2/energy_orb_frame.png`
8. `assets/images/ui/battle_v2/end_turn_btn_orange.png`
9. `assets/images/ui/battle_v2/card_frame_attack.png`
10. `assets/images/ui/battle_v2/card_frame_support.png`
11. `assets/images/ui/battle_v2/card_frame_debuff.png`
12. `assets/images/ui/battle_v2/class_badge_bg.png`

### Optional Battleground Placeholders
1. `assets/images/bg2/battleground-ruins-day.jpg`
2. `assets/images/bg2/battleground-ruins-bloodmoon.jpg`

---

## Execution Sequence
1. Phase 1
2. Phase 2
3. Phase 3 and Phase 4 (parallelizable)
4. Phase 5

---

## Done Criteria
- Rules parity for core mechanics reflected in battle outcomes and turn logs
- UI structure and hierarchy visibly aligned to layout reference
- Analyzer clean on touched files
- PvP deterministic behavior preserved
