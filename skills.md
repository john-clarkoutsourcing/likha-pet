# Likha Pet — Skill & Battle System Reference

> This file is the authoritative spec for the battle engine algorithm.
> Claude Code reads this to stay consistent across sessions.

---

## 1. Team & Formation

- **3v3** turn-based battle: player team (Team Bayani) vs enemy team (Team Diwata).
- Team list order = formation: **index 0 = FRONT, 1 = MID, 2 = BACK**.
- FRONT pet is the default attack target ("first alive" in the list).
- Back row can only be targeted by skills with the `back_enemy` or `lowest_hp_enemy` target spec.
- All pets share **equal base stats** — no leveling, no items.

### Base Stats
| Stat | Value | Notes |
|---|---|---|
| HP | 150 | `kBaseHp` |
| Attack | 30 | `kBaseAttack` |
| Defense | 30 | `kBaseDefense` |
| Speed | varies | unique per pet, drives turn order |

---

## 2. Turn Order

- Pets act in **descending speed order** each round (higher speed = acts first).
- Tiebreaker: Team A (player) before Team B (enemy).
- Stun skips a pet's turn entirely (stun is consumed after the skip).

---

## 3. Team Energy (Shared Pool)

- **Each team** (player and enemy) has ONE shared energy pool — NOT per pet.
- Starting energy: **3**
- Regen per round: **+2** (added AFTER action resolution, ready for next round)
- Cap: **9**
- **Skill energy costs: 1E (weak/utility) or 2E (strong) — maximum is 2E per skill**

### Energy flow per round
```
Player presses End Turn
  → Actions resolve (spending energy from the pool)
  → Pool regens +2
  → State updates (orb shows new total for next round)
```

### Key rules
- Unassigned pets **do not act** and spend **zero energy**.
- Only explicitly assigned card plays spend energy.
- Energy accumulates across rounds up to cap 9.
- Enemy AI also draws from its own separate pool.

---

## 4. Skill Draw System (Card Deck)

### Deck construction
- Each team has one **18-card deck**: 3 pets × 3 traits × 2 copies.
- Deck is shuffled with a seeded PRNG at battle start (deterministic replay).

### Draw rules
| Phase | Cards drawn |
|---|---|
| Battle start (initial deal) | **6 cards** |
| Each subsequent round | **3 cards** |

- Hand is **not cleared between rounds** — cards accumulate.
- **Hand cap: 10 cards.** When a draw would push the hand over 10:
  - A popup appears: "HAND FULL — Discard N card(s)"
  - Player manually taps cards to discard until hand ≤ 10.
  - End Turn is blocked until discards are complete.
- When draw pile empties, discard pile is reshuffled into a new draw pile (no penalty).

### Pity mechanic
- If a pet has had **0 cards in hand for 2 consecutive turns**, one copy of its cheapest trait is injected to the **top of the draw pile** — guaranteed draw next turn.
- Pity cards are marked with a ★ badge in the UI.

### Card assignment
- Player **taps a card** → assigns it to its owner pet (shown by pet initial dot).
- Tapping an **already-assigned card** → **deselects it** (toggle).
- Only one card per pet per round (you choose WHICH of that pet's drawn cards to use).
- Unassigned pets wait — no action, no energy spent.

---

## 5. Damage Formula

```
raw    = attacker.effectiveAttack + trait.baseValue
net    = max(1, raw - defender.effectiveDefense)
actual = clamp(net, 1, cap)   ← cap: 90 single-target, 30 per-target AoE
```

- Defense is subtracted in `ActionResolver`, NOT in `Pet.takeDamage`.
- `Pet.takeDamage` only handles shield absorption.
- Minimum damage is always 1.

---

## 6. Status Effects

### Debuffs
| Effect | Behavior |
|---|---|
| `poisoned` | X dmg/round at start of round, goes through shield |
| `burned` | X dmg/round, **ignores shield** |
| `stunned` | Skip turn, consumed after skip |
| `attackDown` | Reduces `effectiveAttack` |
| `defenseDown` | Reduces `effectiveDefense` |
| `speedDown` | Acts last this round (overrides speed sort) |

### Buffs
| Effect | Behavior |
|---|---|
| `attackUp` | Boosts `effectiveAttack` |
| `defenseUp` | Boosts `effectiveDefense` |
| `speedUp` | Boosts speed |
| `regen` | Heals X HP at start of each round |
| `energized` | +X energy per round |

### Stacking rules
- Poison + burn can coexist (different types).
- Multiple `attackDown` stacks additively.
- Two `stunned` applications refresh duration (don't double-stack).
- `regen` buffs stack — all are applied each round.
- Shield hard cap: 40.

### Status tick order (start of each round, before actions)
1. Poison tick
2. Burn tick
3. Regen tick
4. Expire effects with 0 rounds remaining
5. Tick trait cooldowns

---

## 7. Skill Library (20 skills)

### Original 13
| Name | Type | Cost | CD | Effect | Target |
|---|---|---|---|---|---|
| Bakunawa Swallow | Offensive | 2E | CD1 | 50 DMG | Lowest HP enemy |
| Lakan Counter | Defensive | 1E | CD2 | DEF +15 (2r) | Self |
| Amihan Veil | Defensive | 2E | CD3 | SHIELD 40 | Self |
| Sarimanok Aura | Support | 2E | CD3 | HEAL 35 | Lowest HP ally |
| Tikbalang Charge | Offensive | 1E | CD0 | 30 DMG | Front enemy |
| Manananggal Drain | Offensive | 2E | CD2 | POISON 8×3r | Front enemy |
| Anak ng Lupa Slam | Offensive | 2E | CD2 | 25 AoE DMG | All enemies |
| Diwata Blessing | Support | 2E | CD3 | HEAL 20 | All allies |
| Bayanihan Shield | Support | 2E | CD3 | DEF +15 (2r) | All allies |
| Kapre Smoke | Utility | 2E | CD3 | ATK -10 (2r) | All enemies |
| Enkanto Flash | Utility | 2E | CD3 | STUN 1r | Front enemy |
| Aswang Fang | Offensive | 2E | CD2 | 45 DMG | Front enemy |
| Tikbalang Snipe | Offensive | 2E | CD2 | 35 DMG (PIERCE) | Back enemy |

### Phase 2 — 7 new skills
| Name | Type | Cost | CD | Effect | Target |
|---|---|---|---|---|---|
| Sigbin Shadow | Utility | 2E | CD3 | SPEED DOWN + DEF -10 (2r) | Front enemy |
| Nuno sa Punso | Support | 1E | CD2 | REGEN 15/r (3r) | Self |
| Perlas ni Marikit | Offensive | 2E | CD3 | 20 AoE + remove shields | All enemies |
| Bathala's Wrath | Offensive | 2E | CD4 | 60 DMG (+20 if poisoned) | Front enemy |
| Agimat Ward | Defensive | 2E | CD3 | SHIELD BREAK enemy + SHIELD 30 self | Front enemy |
| Lambana Dance | Support | 2E | CD4 | HEAL 25 + cleanse 1 debuff | Lowest HP ally |
| Kulam Curse | Utility | 2E | CD4 | BURN 5×3r + POISON 8×2r | Front enemy |

---

## 8. AI Skill Selection Priority (Enemy)

Enemy AI evaluates drawn cards in this priority order:
1. **Heal** a critical ally (< 40% HP) — score 90
2. **Stun** an unstunned enemy — score 80
3. **Shield self** at critical HP (< 40%) — score 75
4. **AoE** when 2+ enemies alive — score 65
5. **Team buff** when team is unbuffed — score 55
6. **Best damage** single-target — score = trait.value
7. **Fallback** — any affordable ready trait from `pet.traits` (ignores hand)

Enemy AI uses its own shared energy pool (same rules as player).

---

## 9. Battle Outcome

- Win: all 3 enemy pets fainted.
- Lose: all 3 player pets fainted.
- Draw: both teams faint simultaneously, or max rounds (30) reached.
- Outcome checked after status phase AND after action phase each round.

---

## 10. File Map

```
battle_engine/lib/
  pet.dart              ← Pet class, EnergyPool linking, status processing
  trait.dart            ← Trait, TraitEffect, TraitLibrary (20 skills)
  energy_pool.dart      ← EnergyPool (shared team energy)
  skill_card.dart       ← SkillCard (one drawn card instance)
  skill_deck.dart       ← SkillDeck (draw/play/recycle, kHandLimit=10, kDrawPerTurn=3)
  pity_sentinel.dart    ← Pity guarantee after 2 dry turns
  action_resolver.dart  ← Damage formula, effect application
  ai_controller.dart    ← Enemy AI priority logic
  turn_manager.dart     ← Speed-sorted action order
  battle_logger.dart    ← Transcript + typed event stream
  battle_state.dart     ← PetSnapshot, BattleState (serialization)
  battle_engine.dart    ← Full auto-run engine (PvP / validation)
  trait_system.dart     ← Trait registry (ID → factory)

app/lib/features/battle/
  engine/interactive_battle_engine.dart  ← One-round-at-a-time engine with deck
  providers/battle_view_model.dart       ← CardViewModel, PveBattleViewModel
  providers/pve_battle_provider.dart     ← StateNotifier, assignSkill, discardCard
  screens/battle_screen.dart             ← Landscape battle UI
```
