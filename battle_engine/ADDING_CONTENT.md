# Adding Content to the Battle Engine

Two files own everything card-related:

| File | Owns |
|---|---|
| `lib/classic_card_specs.dart` | Numbers: `attack`, `defense`, `energy`, `name`, `description` |
| `lib/trait.dart` | Semantics: effect type, target, buff/debuff kind, part slot |

`withClassicCardStats` is the bridge — each trait getter in `TraitLibrary` calls it with a `cardId` and a skeleton trait, and the numbers are injected automatically.

---

## 1. Adding a New Card / Skill / Trait

A card always requires two entries: one in each file.

### Step 1 — `classic_card_specs.dart`

Add a row to `kClassicCardSpecs`. The key format is `{class}-{part}-{number}`. Numbers are even and increment in pairs per class+part line (02, 04, 06 …).

```dart
'beast-horn-14': ClassicCardSpec(
  name: 'Thunder Fang',
  attack: 110,
  defense: 25,
  energy: 1,
  description: 'Deal 150% damage if this Axie attacked first.',
),
```

- `attack` → base damage value
- `defense` → selfShield on a damage card; shield value on a pure-shield card
- `energy` → cost to play (0 = free)

### Step 2 — `trait.dart` (inside `TraitLibrary`)

Add a static getter. You only declare semantics — no numbers.

```dart
// ── Beast variant skills ───────────────────────────────
static Trait get beastHorn3 => withClassicCardStats(
      baseTrait: _base(
        id: 'beast_horn_3',
        type: TraitType.offensive,   // offensive / defensive / support / utility
        part: TraitPart.horn,        // horn / back / mouth / tail / body
        effect: const TraitEffect(
          type: EffectType.damage,   // damage / shield / buff / debuff / aoe
          value: 0,                  // placeholder — filled by spec
          target: 'enemy',           // see Target Reference below
        ),
      ),
      traitId: 'beast_horn_3',
      cardId: 'beast-horn-14',       // must match Step 1 exactly
    );
```

### Effect type reference

| `EffectType` | When to use | `value` source |
|---|---|---|
| `damage` | Deals HP damage | spec `attack`; spec `defense` → `selfShield` |
| `shield` | Applies shield only | spec `defense` |
| `buff` | Applies a buff status | spec `defense` → `selfShield`; set `buffType` + `duration` |
| `debuff` | Applies a debuff status | spec `defense` → `selfShield`; set `debuffType` + `duration` |
| `aoe` | Hits all enemies | same as `damage` |
| `shieldBreak` | Destroys enemy shield | `effect.value` = selfShield to self |

### Target reference

| `target` string | Who gets hit |
|---|---|
| `'enemy'` | Front-most alive enemy |
| `'back_enemy'` | Back-most alive enemy (pierces formation) |
| `'self'` | The attacker |
| `'all_enemies'` | Every living enemy |
| `'all_allies'` | Every living ally |
| `'lowest_hp_ally'` | Ally with least HP |
| `'lowest_hp_enemy'` | Enemy with least HP |

### Buff/debuff card example

For a card that applies a status (no raw damage):

```dart
static Trait get reptileMouth2 => withClassicCardStats(
      baseTrait: _base(
        id: 'reptile_mouth_2',
        type: TraitType.support,
        part: TraitPart.mouth,
        effect: const TraitEffect(
          type: EffectType.buff,
          value: 0,
          buffType: BuffType.speedUp,   // attackUp / defenseUp / speedUp / regen
          duration: 2,                  // rounds it lasts
          target: 'self',
        ),
      ),
      traitId: 'reptile_mouth_2',
      cardId: 'reptile-mouth-12',
    );
```

spec.defense automatically becomes `selfShield` — no extra wiring needed.

---

## 2. Adding a New Part Slot

Parts are the physical slots on a pet (`horn`, `back`, etc). Only add one if the game design introduces a genuinely new equip slot.

### `lib/trait.dart`

```dart
enum TraitPart { body, horn, back, mouth, tail, wing }  // ← add here
```

Then search the codebase for any `switch` on `TraitPart` and add the new case.

### Part definitions file (wherever parts are assembled into pets)

Add the new slot to however pets are built — the file that calls `TraitLibrary` getters and assigns them to pets.

---

## 3. Adding a New Creature Class

Classes are `beast`, `bug`, `bird`, `plant`, `aquatic`, `reptile`. Adding one is heavier — it touches the type triangle, base stats, and needs a full set of trait cards.

### `lib/trait.dart` — 4 things to add

**1. Enum value**
```dart
enum CreatureClass { beast, bug, bird, plant, aquatic, reptile, mech }  // ← add
```

**2. `displayName`**
```dart
CreatureClass.mech => 'Mech',
```

**3. `advantageGroup` — decide which group it belongs to**

The triangle has three groups:
- Tank (Plant, Reptile) beats Speed
- Speed (Aquatic, Bird) beats Burst
- Burst (Beast, Bug) beats Tank

Assign the new class to one group and update the classes it beats:
```dart
// Mech is a Tank-group class that beats Aquatic and Bird
CreatureClass.mech => [CreatureClass.aquatic, CreatureClass.bird],
// Also update aquatic and bird to include mech in their advantageGroup
CreatureClass.aquatic => [CreatureClass.beast, CreatureClass.bug, CreatureClass.mech],
CreatureClass.bird    => [CreatureClass.beast, CreatureClass.bug, CreatureClass.mech],
```

**4. `baseBodyStats` and `partStatBonus`**
```dart
// baseBodyStats — body HP/speed/skill/morale before part contributions
CreatureClass.mech => (hp: 170, speed: 29, skill: 22, morale: 20),

// partStatBonus — added per equipped part of this class
CreatureClass.mech => (hp: 2, speed: 0, skill: 1, morale: 0),
```

**5. Add cards for the new class**

Follow the same two-step process from Section 1 for each part slot (horn, back, mouth, tail).

---

## 4. Blood Taste — Lifesteal / Heal-on-Damage

Blood Taste (`bug-mouth-02`) says:
> "Heal this Axie by the damage inflicted with this card."

Cards like Swallow (`aquatic-mouth-04`) and Drain Bite (`plant-mouth-04`) share this mechanic.

### Current state (gap)

Right now these cards are added as plain damage cards. The `defense` value from the spec becomes `selfShield` — a fixed shield amount — **not** a heal proportional to damage dealt. The lifesteal mechanic does not exist in the engine yet.

In `ActionResolver.resolve()`:
```dart
case EffectType.damage:
  final actual = target.takeDamage(dmg);   // actual HP removed — captured but unused
  log.damage(target.name, actual, target.hp, isCrit: isCrit);
  // ← lifesteal would go here
```

### How to implement it

**Step 1 — Add a `lifeSteal` flag to `TraitEffect`**

```dart
// lib/trait.dart — TraitEffect class
class TraitEffect {
  // ... existing fields ...
  final bool lifeSteal;   // ← add this

  const TraitEffect({
    // ... existing params ...
    this.lifeSteal = false,
  });
}
```

**Step 2 — Apply the heal in `ActionResolver`**

```dart
// lib/action_resolver.dart — inside case EffectType.damage
case EffectType.damage:
  final target = ...;
  final net = _computeDamage(...);
  final isCrit = _rollCrit(actor, target);
  final dmg = _clamp(isCrit ? net * 2 : net, kMaxSingleHitDamage);
  final actual = target.takeDamage(dmg);
  log.damage(target.name, actual, target.hp, isCrit: isCrit);
  if (target.isFainted) log.fainted(target.name);

  // Lifesteal — heal attacker by actual damage dealt
  if (trait.effect.lifeSteal && actual > 0) {
    final heal = actual.clamp(0, kMaxFlatHealing);
    actor.receiveHealing(heal);
    log.heal(actor.name, heal, actor.hp);
  }
```

**Step 3 — Tag the cards in `trait.dart`**

```dart
static Trait get bugMouth2 => withClassicCardStats(
      baseTrait: _base(
        id: 'bug_mouth_2',
        type: TraitType.offensive,
        part: TraitPart.mouth,
        effect: const TraitEffect(
          type: EffectType.damage,
          value: 0,
          target: 'enemy',
          lifeSteal: true,    // ← this flag triggers the heal
        ),
      ),
      traitId: 'bug_mouth_2',
      cardId: 'bug-mouth-02',
    );
```

Do the same for Swallow (`aquatic-mouth-04`) and Drain Bite (`plant-mouth-04`).

### Balance note

`kMaxFlatHealing = 50` (defined in `action_resolver.dart`) caps every single heal. A lifesteal card that deals 80 damage will heal at most 50 HP — keeps it from becoming a sustain loop.

---

## Quick checklist for any new card

- [ ] Entry added to `kClassicCardSpecs` with correct `{class}-{part}-{number}` key
- [ ] Static getter added to `TraitLibrary` pointing at that key via `cardId`
- [ ] `effect.target` set correctly (check the target table above)
- [ ] If buff/debuff: `buffType`/`debuffType` and `duration` set
- [ ] If lifesteal: `lifeSteal: true` set and the engine flag implemented (Section 4)
- [ ] Pet part definition wired up to the new trait getter
