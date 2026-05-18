# Axie Infinity Classic (V2) — Comprehensive Battle Mechanics

In **Axie Infinity Classic (V2)**, battles are strategic, turn-based card duels played with a team of three Axies. The gameplay revolves around careful resource management, card counting, and positioning. 

---

## 1. Team Positioning & Lanes
Before a match starts, you position your three Axies on a $3 \times 3$ grid. This positioning determines the default **Targeting Order** in battle.

* **The Lane Rule:** By default, an Axie will always target the **closest enemy**. 
* **Split Paths:** If an enemy Axie is placed dead-center in the front row, all your Axies will target it. However, if the enemy has two Axies placed parallel in the upper and lower rows at an equal distance, your Axie will attack the one in its own horizontal lane. If it is in the middle lane, it has a 50/50 chance to hit either.
* **Standard Archetype (ABP / BAP):** Players typically place a high-HP **Plant** in the front row to absorb damage (the Tank), a **Beast or Bug** in the middle row to generate energy/deal damage (the Midliner), and a high-speed **Bird or Aquatic** in the back row to clean up the match (the Backliner).

---

## 2. Resource Management: Energy & Cards
Every battle is dictated by two strict pools of resources: **Energy** and your **Card Deck**.

* **The Starting Hand:** In Round 1, you begin with **3 Energy** and draw **6 Cards**.
* **The Round Income:** At the start of every subsequent round, you gain **+2 Energy** and draw **3 Cards**. There is no cap on how many cards you can hold in your hand, but Energy maximum is capped at 10.
* **The 24-Card Deck Cycle:** Your deck consists of exactly **24 cards** ($3 \text{ Axies} \times 4 \text{ body parts} \times 2 \text{ copies}$). When an Axie dies, its cards **remain** in the deck cycle; drawing them results in "dead cards" you cannot play. Once all 24 cards are drawn, the discard pile reshuffles back into the draw deck.

---

## 3. The Turn Structure
Each round in Axie Classic is split into two distinct phases: **The Selection Phase** and **The Battle Phase**.

### Phase A: Selection (Tactical)
Players look at their current hand and Energy pool. You select which cards to play and in what exact sequence. 
* **Combos:** Playing multiple cards on a *single* Axie. Combos trigger special card effects (like Ronin's guaranteed critical strike) and add extra damage scaling based on the Axie's **Skill** stat.
* **Chains:** Playing cards of the *same class type* across *different* Axies in the same round (e.g., your Plant plays a Plant card and your Reptile plays a Plant card). Chains give a percentage boost to those Axies' shield values and trigger specific card requirements.

### Phase B: Battle (Automated Execution)
Once both players hit "End Turn," the round plays out automatically based entirely on **Speed**. 
* The fastest Axie on the field takes its turn first, executing all its queued cards in the exact order you selected them.
* The game calculates damage, applies shields, and processes debuffs before moving to the next fastest Axie.

---

## 4. Stat & Class Mathematics
Combat calculations are heavily influenced by Class Types and Core Stats.

### The Four Core Stats
* **HP (Health Points):** The total damage an Axie can take before fainting.
* **Speed:** Determines turn order (Fastest attacks first). Tie-breakers prioritize lowest HP, then highest Skill, then highest Morale.
* **Skill:** Adds bonus damage to your attacks when that Axie executes a multi-card **Combo**. 
* **Morale:** Directly increases Critical Strike chance and your likelihood of entering **Last Stand**.

### Class Advantages (The RPS Wheel)
There are 6 primary classes organized into three operational triangles. Attacking a class you have an advantage over grants a **+15% damage bonus**, while attacking a class that counters you inflicts a **-15% damage penalty**: