export interface PetState {
  uid: string;
  name: string;
  hp: number;
  maxHp: number;
  spd: number;
  skl: number;
  mor: number;
  dex: number;
  def: number;
  shield: number;
  isFainted: boolean;
  index: number;
  statusEffects: StatusEffect[];
}

export interface StatusEffect {
  name: string;
  remainingRounds: number;
  magnitude: number;
}

export interface PlayerSelection {
  traitName: string;
  targetIndex: number;
}

// Card effect metadata submitted by each client with their selections.
export interface CardEffect {
  effectType: string;  // 'damage'|'heal'|'shield'|'buff'|'debuff'|'poison'|'burn'|'stun'|'aoe'|'shieldBreak'|...
  effectValue: number; // base numeric value from the card
  target: string;      // 'enemy'|'self'|'ally'|'all_enemies'|'back_enemy'
}

export interface RoundExecutionInput {
  seed: number;
  roundNumber: number;
  playerATeam: PetState[];
  playerBTeam: PetState[];
  playerASelections: Record<string, string[]>;  // petUid -> [cardInstanceId, ...]
  playerBSelections: Record<string, string[]>;
  cardEffects?: Record<string, CardEffect>;      // cardInstanceId -> effect info
}

export interface ActionLog {
  uid: string;
  name: string;
  team: 'A' | 'B';
  action: string;
  effectType: string;
  damage: number;
  healAmount: number;
  shieldAmount: number;
  statusApplied: string;
  target: string;
  targetTeam: 'A' | 'B';
  // Authoritative post-action state — clients apply these directly (no local recalc)
  targetHpAfter: number;
  targetShieldAfter: number;
  targetIsFainted: boolean;
  actorHpAfter: number;      // for heals/buffs that affect the actor
  actorShieldAfter: number;
}

export interface RoundExecutionResult {
  success: boolean;
  roundNumber?: number;
  turnOrder?: ActionLog[];
  playerATeamAfter?: PetState[];
  playerBTeamAfter?: PetState[];
  battleComplete?: boolean;
  winnerTeam?: 'A' | 'B' | 'draw' | null;
  error?: string;
  stackTrace?: string;
}

/**
 * Server-side battle executor — pure TypeScript, no Dart dependency.
 * Handles all card effect types: damage, heal, shield, buff, debuff,
 * poison, burn, stun, shieldBreak, aoe, lifeSteal.
 */
export class ServerBattleExecutor {
  async executeRound(input: RoundExecutionInput): Promise<RoundExecutionResult> {
    try {
      return this._executeRoundSync(input);
    } catch (err) {
      return { success: false, error: err instanceof Error ? err.message : String(err) };
    }
  }

  private _executeRoundSync(input: RoundExecutionInput): RoundExecutionResult {
    const { seed, roundNumber, playerATeam, playerBTeam,
            playerASelections, playerBSelections, cardEffects = {} } = input;

    const rng = this._makeRng(seed + roundNumber);

    // Deep-clone so we never mutate input
    const teamA: PetState[] = playerATeam.map(p => ({
      ...p, statusEffects: p.statusEffects?.map(s => ({ ...s })) ?? []
    }));
    const teamB: PetState[] = playerBTeam.map(p => ({
      ...p, statusEffects: p.statusEffects?.map(s => ({ ...s })) ?? []
    }));

    // ── Process status effects at round start ─────────────────────────────────
    for (const pet of [...teamA, ...teamB]) {
      if (pet.isFainted) continue;
      for (const status of pet.statusEffects) {
        if (status.name === 'poison' || status.name === 'burn') {
          pet.hp = Math.max(0, pet.hp - status.magnitude);
          if (pet.hp <= 0) pet.isFainted = true;
        }
        status.remainingRounds--;
      }
      pet.statusEffects = pet.statusEffects.filter(s => s.remainingRounds > 0);
    }

    // ── Build turn order: speed desc → morale → skill → uid ──────────────────
    const allPets = [
      ...teamA.map(p => ({ pet: p, team: 'A' as const })),
      ...teamB.map(p => ({ pet: p, team: 'B' as const })),
    ].sort((a, b) => {
      const d = b.pet.spd - a.pet.spd;
      if (d !== 0) return d;
      const m = b.pet.mor - a.pet.mor;
      if (m !== 0) return m;
      const s = b.pet.skl - a.pet.skl;
      if (s !== 0) return s;
      return a.pet.uid < b.pet.uid ? -1 : 1;
    });

    const actions: ActionLog[] = [];

    for (const { pet, team } of allPets) {
      if (pet.isFainted) continue;

      // Check if stunned
      if (pet.statusEffects.some(s => s.name === 'stun')) continue;

      const selections = team === 'A' ? playerASelections : playerBSelections;
      const selectedCards = (selections[pet.uid] ?? []) as string[];
      if (selectedCards.length === 0) continue;

      const cardId   = selectedCards[0];
      const cardFx   = cardEffects[cardId];
      const effectType  = cardFx?.effectType ?? 'damage';
      const effectValue = cardFx?.effectValue ?? 0;
      const targetPref  = cardFx?.target ?? 'enemy';

      const enemyTeam = team === 'A' ? teamB : teamA;
      const allyTeam  = team === 'A' ? teamA : teamB;
      const isSelf    = targetPref === 'self' || targetPref === 'ally';

      let damage      = 0;
      let healAmount  = 0;
      let shieldAmount = 0;
      let statusApplied = '';
      let actionTarget: PetState | null = null;
      let actionTargetTeam: 'A' | 'B' = team === 'A' ? 'B' : 'A';

      switch (effectType) {
        // ── Offensive ───────────────────────────────────────────────────────
        case 'damage':
        case 'aoe': {
          const enemy = enemyTeam.find(p => !p.isFainted);
          if (!enemy) continue;
          actionTarget = enemy;
          actionTargetTeam = team === 'A' ? 'B' : 'A';
          const base = effectValue > 0 ? effectValue + rng.nextInt(8) - 4 : 30 + rng.nextInt(8) - 4;
          damage = Math.max(1, base - Math.floor((enemy.def ?? 0) / 3));
          // Class bonus: +15% or -15% based on speed (simplified)
          const shieldAbsorb = Math.min(enemy.shield, damage);
          enemy.shield -= shieldAbsorb;
          enemy.hp = Math.max(0, enemy.hp - (damage - shieldAbsorb));
          if (enemy.hp <= 0) enemy.isFainted = true;
          break;
        }
        case 'shieldBreak': {
          const enemy = enemyTeam.find(p => !p.isFainted);
          if (!enemy) continue;
          actionTarget = enemy;
          actionTargetTeam = team === 'A' ? 'B' : 'A';
          enemy.shield = 0;
          damage = Math.max(1, 20 - Math.floor((enemy.def ?? 0) / 3));
          enemy.hp = Math.max(0, enemy.hp - damage);
          if (enemy.hp <= 0) enemy.isFainted = true;
          break;
        }

        // ── Status debuffs ───────────────────────────────────────────────────
        case 'poison': {
          const enemy = enemyTeam.find(p => !p.isFainted);
          if (!enemy) continue;
          actionTarget = enemy;
          actionTargetTeam = team === 'A' ? 'B' : 'A';
          const mag = effectValue > 0 ? effectValue : 15;
          enemy.statusEffects.push({ name: 'poison', remainingRounds: 2, magnitude: mag });
          statusApplied = 'poison';
          // Also deal small damage on application
          damage = Math.max(1, Math.floor(mag * 0.5));
          enemy.hp = Math.max(0, enemy.hp - damage);
          if (enemy.hp <= 0) enemy.isFainted = true;
          break;
        }
        case 'burn': {
          const enemy = enemyTeam.find(p => !p.isFainted);
          if (!enemy) continue;
          actionTarget = enemy;
          actionTargetTeam = team === 'A' ? 'B' : 'A';
          const mag = effectValue > 0 ? effectValue : 15;
          enemy.statusEffects.push({ name: 'burn', remainingRounds: 2, magnitude: mag });
          statusApplied = 'burn';
          damage = Math.max(1, Math.floor(mag * 0.5));
          enemy.hp = Math.max(0, enemy.hp - damage);
          if (enemy.hp <= 0) enemy.isFainted = true;
          break;
        }
        case 'stun': {
          const enemy = enemyTeam.find(p => !p.isFainted);
          if (!enemy) continue;
          actionTarget = enemy;
          actionTargetTeam = team === 'A' ? 'B' : 'A';
          enemy.statusEffects.push({ name: 'stun', remainingRounds: 1, magnitude: 0 });
          statusApplied = 'stun';
          break;
        }
        case 'debuff':
        case 'atk_down':
        case 'def_down':
        case 'spd_down': {
          const enemy = enemyTeam.find(p => !p.isFainted);
          if (!enemy) continue;
          actionTarget = enemy;
          actionTargetTeam = team === 'A' ? 'B' : 'A';
          enemy.statusEffects.push({ name: effectType, remainingRounds: 2, magnitude: effectValue });
          statusApplied = effectType;
          break;
        }

        // ── Self / Ally ──────────────────────────────────────────────────────
        case 'heal':
        case 'regen': {
          healAmount = effectValue > 0 ? effectValue : 30;
          pet.hp = Math.min(pet.maxHp, pet.hp + healAmount);
          actionTarget = pet;
          actionTargetTeam = team;
          break;
        }
        case 'shield': {
          shieldAmount = effectValue > 0 ? effectValue : 50;
          pet.shield += shieldAmount;
          actionTarget = pet;
          actionTargetTeam = team;
          break;
        }
        case 'buff':
        case 'atk_up':
        case 'def_up':
        case 'spd_up':
        case 'energized': {
          pet.statusEffects.push({ name: effectType, remainingRounds: 2, magnitude: effectValue });
          statusApplied = effectType;
          actionTarget = pet;
          actionTargetTeam = team;
          break;
        }

        // ── Default: treat as damage ─────────────────────────────────────────
        default: {
          const enemy = enemyTeam.find(p => !p.isFainted);
          if (!enemy) continue;
          actionTarget = enemy;
          actionTargetTeam = team === 'A' ? 'B' : 'A';
          const base = effectValue > 0 ? effectValue + rng.nextInt(6) - 3 : 30 + rng.nextInt(6) - 3;
          damage = Math.max(1, base - Math.floor((enemy.def ?? 0) / 3));
          const shieldAbsorb = Math.min(enemy.shield, damage);
          enemy.shield -= shieldAbsorb;
          enemy.hp = Math.max(0, enemy.hp - (damage - shieldAbsorb));
          if (enemy.hp <= 0) enemy.isFainted = true;
        }
      }

      if (!actionTarget) continue;

      actions.push({
        uid:              pet.uid,
        name:             pet.name,
        team,
        action:           cardId,
        effectType,
        damage,
        healAmount,
        shieldAmount,
        statusApplied,
        target:           actionTarget.uid,
        targetTeam:       actionTargetTeam,
        // Authoritative post-action state sent to clients — no local recalc needed.
        targetHpAfter:    actionTarget.hp,
        targetShieldAfter: actionTarget.shield,
        targetIsFainted:  actionTarget.isFainted,
        actorHpAfter:     pet.hp,
        actorShieldAfter: pet.shield,
      });
    }

    // ── Win condition ─────────────────────────────────────────────────────────
    const allAFainted = teamA.every(p => p.isFainted);
    const allBFainted = teamB.every(p => p.isFainted);
    let winnerTeam: 'A' | 'B' | 'draw' | null = null;
    if (allAFainted && !allBFainted)      winnerTeam = 'B';
    else if (allBFainted && !allAFainted) winnerTeam = 'A';
    else if (allAFainted && allBFainted)  winnerTeam = 'draw';

    console.log(`[Battle] Round ${roundNumber} — ${actions.length} actions, winner: ${winnerTeam ?? 'none'}`);

    return {
      success:          true,
      roundNumber,
      turnOrder:        actions,
      playerATeamAfter: teamA,
      playerBTeamAfter: teamB,
      battleComplete:   winnerTeam !== null,
      winnerTeam,
    };
  }

  private _makeRng(seed: number) {
    let s = seed >>> 0;
    return {
      next(): number {
        s = Math.imul(s, 1664525) + 1013904223 >>> 0;
        return s / 0x100000000;
      },
      nextInt(max: number): number {
        return Math.floor(this.next() * max);
      },
    };
  }
}
