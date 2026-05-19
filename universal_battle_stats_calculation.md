# PET Infinity Classic (V2) — Comprehensive Combat & Stats Engine Specifications

This document serves as the unified system specification manual for the **PET Infinity Classic (V2)** simulation engine. It contains the data structures, mathematical formulas, sorting hierarchies, and state-machine execution rules required to build a deterministic battle simulation layer[cite: 1].

---

## 1. Core Anatomy Point Matrix

A PET's initial performance vectors are determined by its **Base Body Class** aggregated with the structural modifiers of its **6 physical body parts** (Eyes, Ears, Mouth, Horn, Back, Tail)[cite: 1].

### Base Class Allocation Mapping
| Class Categories | Base HP | Base Speed | Base Skill | Base Morale |
| :--- | :---: | :---: | :---: | :---: |
| **Plant / Dusk** | 43 | 31 | 31 | 35 |
| **Aquatic / Reptile** | 39 | 39 | 35 | 27 |
| **Bug / Dawn** | 35 | 31 | 35 | 39 |
| **Mech** | 31 | 39 | 43 | 27 |
| **Beast** | 31 | 35 | 31 | 43 |
| **Bird** | 31 | 43 | 35 | 31 |

### Body Part Modifier Contribution Mapping
Each of the 6 body parts increments the core stat pool based on the part's class category:
| Part Class Family | HP Bonus | Speed Bonus | Skill Bonus | Morale Bonus |
| :--- | :---: | :---: | :---: | :---: |
| **Plant** | +3 | +0 | +0 | +1 |
| **Reptile** | +3 | +1 | +0 | +0 |
| **Aquatic** | +1 | +3 | +0 | +0 |
| **Bird** | +0 | +3 | +1 | +0 |
| **Bug** | +1 | +0 | +3 | +0 |
| **Beast** | +0 | +1 | +0 | +3 |

*Note: Secret/hybrid classes (Mech, Dawn, Dusk) inherit part modifier values from their base archetypes: Mech inherits Beast parts, Dawn inherits Bird parts, and Dusk inherits Reptile parts[cite: 1].*

---

## 2. Universal In-Battle Scaling Formulas

Once the engine aggregates the total stat points (Base Class + Part Modifiers), it applies linear scaling operations to establish the final runtime combat values[cite: 1].

### Hit Points (HP) Scaler
The full size of a PET's active health bar is calculated using the following formula[cite: 1]:

$$\text{Battle HP} = (\text{Total HP Stat} \times 6) + 150$$

$$\text{Battle HP} = 6 \times (\text{Total HP Stat} + 25)$$

### Combat Attributes Scaler (Speed, Skill, Morale)
The metrics for turn frequency, execution precision, and critical strike indicators scale via a universal linear block[cite: 1]:

$$\text{Battle Combat Stat} = (\text{Total Stat Points} \times 4) + 100$$

### Max Stat Archetype Benchmarks (Pure Builds)
Use these exact pure-build configurations to verify data model outputs and factory methods[cite: 1]:

| Pure PET Build Type | Total Core Stats (HP / Spd / Skl / Mor) | Final In-Battle Combat Stats |
| :--- | :---: | :---: |
| **Pure Plant** | 61 / 31 / 31 / 41 | **516 HP / 224 Spd / 224 Skl / 264 Mor** |
| **Pure Reptile** | 57 / 45 / 35 / 27 | **492 HP / 280 Spd / 240 Skl / 208 Mor** |
| **Pure Aquatic** | 45 / 57 / 35 / 27 | **420 HP / 328 Spd / 240 Skl / 208 Mor** |
| **Pure Bird** | 27 / 61 / 41 / 31 | **312 HP / 344 Spd / 264 Skl / 224 Mor** |
| **Pure Beast** | 31 / 41 / 31 / 61 | **336 HP / 264 Spd / 224 Skl / 344 Mor** |
| **Pure Bug** | 41 / 31 / 49 / 39 | **396 HP / 224 Spd / 296 Skl / 256 Mor** |

---

## 3. Layer 1: Unit Roster Turn Order Loop

At the beginning of each combat round, the battle engine parses all living units into a sorted execution timeline array using a deterministic multi-stage tie-breaker hierarchy[cite: 1]. 

When sorting priority, the system processes parameters in order; if any property results in a tie, the system drops down to evaluate the next nested condition[cite: 1]:

[Highest Current Battle Speed]
|
+---> (If Identical) ---> [Lowest Current Hit Points]
|
+---> (If Identical) ---> [Highest Skill Battle Stat]
|
+---> (If Identical) ---> [Highest Morale Battle Stat]
|
+---> (If Identical) ---> [Lowest Database Unit ID]


> **Fidelity Warning:** The sorting processes must evaluate the fully scaled, active **In-Battle Stats** (inclusive of round-by-round status modifications, buffs, and debuffs), never the static underlying genome point matrix[cite: 1].

---

## 4. Layer 2: Individual Unit Skill Execution Pipeline

When a unit's dynamic turn triggers, its queued actions resolve sequentially through a localized FIFO queue framework coupled with multi-card combo evaluation rules[cite: 1].

### The Skill Combo Modifier Application
If a single active entity initiates an action string containing **2 or more cards simultaneously**, a flat computational damage addition applies to each individual strike[cite: 1]:

$$\text{Final Inflicted Damage} = (\text{Base Damage} \times \mathcal{P} \times \mathcal{R} \times \mathcal{M}_{\text{cond}} \times \mathcal{M}_{\text{crit}}) + \mathcal{S}_{\text{combo}}$$

Where the structural skill combo bonus ($\mathcal{S}_{\text{combo}}$) is resolved as[cite: 1]:

$$\mathcal{S}_{\text{combo}} = \frac{\text{Base Card Damage} \times \text{Skill Battle Stat}}{500}$$

*Note: The flat $\mathcal{S}_{\text{combo}}$ asset modifier is appended **after** all standard multiplier layers, purity tracking, or critical coefficients have completely computed. It cannot be doubled by critical status events[cite: 1].*

### Mid-Queue Target Realignment Rule
* **Target Coordinates Lock:** A unit calculates and locks its spatial target alignment coordinates right at the execution startup boundary of its action phase.
* **Casualty Redirect:** If a unit launches a queued combo payload, and the initial skill components successfully drop the targeted enemy's health pool to 0, the engine's targeting system **must run lane lookups instantly mid-turn** before executing any subsequent skills remaining in the queue[cite: 1]. This redirects remaining moves onto the next valid survival entity instead of missing the targeted space[cite: 1].

---

## 5. Reference Implementation Blueprint

```typescript
interface BodyPart {
  slot: 'eyes' | 'ears' | 'mouth' | 'horn' | 'back' | 'tail';
  classType: string;
}

interface PETConfig {
  id: string;
  bodyClass: string;
  parts: BodyPart[]; // Exactly 6 elements
}

interface QueuedSkill {
  id: string;
  baseDamage: number;
  partClassMatchesBody: boolean;
}

interface CombatUnit {
  id: string;
  currentHp: number;
  maxHp: number;
  speed: number;   // Scaled In-Battle Value
  skill: number;   // Scaled In-Battle Value
  morale: number;  // Scaled In-Battle Value
  queuedSkills: QueuedSkill[];
  isDead: boolean;
}

class PETBattleEngineCore {
  
  /**
   * Evaluates config strings to establish initial base stats and scaled runtime pools
   */
  public static initializePET(config: PETConfig): CombatUnit {
    const coreStats = this.getBaseClassStats(config.bodyClass);

    for (const part of config.parts) {
      const modifiers = this.getPartModifiers(part.classType);
      coreStats.hp += modifiers.hp;
      coreStats.speed += modifiers.speed;
      coreStats.skill += modifiers.skill;
      coreStats.morale += modifiers.morale;
    }

    const calculatedMaxHp = (coreStats.hp * 6) + 150;

    return {
      id: config.id,
      maxHp: calculatedMaxHp,
      currentHp: calculatedMaxHp,
      speed: (coreStats.speed * 4) + 100,
      skill: (coreStats.skill * 4) + 100,
      morale: (coreStats.morale * 4) + 100,
      queuedSkills: [],
      isDead: false
    };
  }

  /**
   * Sorts the global timeline layout using the deterministic multi-stage tie-breaker hierarchy
   */
  public static sortRosterTurnOrder(units: CombatUnit[]): CombatUnit[] {
    return [...units].filter(u => !u.isDead).sort((a, b) => {
      if (b.speed !== a.speed) return b.speed - a.speed;
      if (a.currentHp !== b.currentHp) return a.currentHp - b.currentHp;
      if (b.skill !== a.skill) return b.skill - a.skill;
      if (b.morale !== a.morale) return b.morale - a.morale;
      return a.id.localeCompare(b.id);
    });
  }

  /**
   * Executes the individual skill queue of a single entity with dynamic targeted realignments
   */
  public static executeUnitSkillQueue(attacker: CombatUnit, locateTarget: (act: CombatUnit) => CombatUnit | null): void {
    if (attacker.queuedSkills.length === 0 || attacker.isDead) return;

    const isComboActive = attacker.queuedSkills.length >= 2;

    for (let i = 0; i < attacker.queuedSkills.length; i++) {
      // Dynamic realignment pass checks target context mid-turn
      const target = locateTarget(attacker);
      if (!target) break; 

      const skill = attacker.queuedSkills[i];
      const purityMultiplier = skill.partClassMatchesBody ? 1.10 : 1.00;
      
      let finalDamage = skill.baseDamage * purityMultiplier;
      
      if (isComboActive) {
        const comboBonus = (skill.baseDamage * attacker.skill) / 500;
        finalDamage += comboBonus;
      }

      target.currentHp = Math.max(0, target.currentHp - Math.floor(finalDamage));
      if (target.currentHp === 0) {
        target.isDead = true;
      }
    }
    
    attacker.queuedSkills = []; // Flush action pipeline
  }

  private static getBaseClassStats(bodyClass: string) {
    switch(bodyClass.toLowerCase()) {
      case 'plant': case 'dusk':    return { hp: 43, speed: 31, skill: 31, morale: 35 };
      case 'aquatic': case 'reptile': return { hp: 39, speed: 39, skill: 35, morale: 27 };
      case 'bug': case 'dawn':      return { hp: 35, speed: 31, skill: 35, morale: 39 };
      case 'mech':                  return { hp: 31, speed: 39, skill: 43, morale: 27 };
      case 'beast':                 return { hp: 31, speed: 35, skill: 31, morale: 43 };
      case 'bird':                  return { hp: 31, speed: 43, skill: 35, morale: 31 };
      default:                      return { hp: 31, speed: 31, skill: 31, morale: 31 };
    }
  }

  private static getPartModifiers(partClass: string) {
    switch(partClass.toLowerCase()) {
      case 'plant':   return { hp: 3, speed: 0, skill: 0, morale: 1 };
      case 'reptile': return { hp: 3, speed: 1, skill: 0, morale: 0 };
      case 'aquatic': return { hp: 1, speed: 3, skill: 0, morale: 0 };
      case 'bird':    return { hp: 0, speed: 3, skill: 1, morale: 0 };
      case 'bug':     return { hp: 1, speed: 0, skill: 3, morale: 0 };
      case 'beast':   return { hp: 0, speed: 1, skill: 0, morale: 3 };
      default:        return { hp: 0, speed: 0, skill: 0, morale: 0 };
    }
  }
}