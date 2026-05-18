import { resolveCardEffect } from './ServerTraitCatalog';

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
  energy?: number;
  isFainted: boolean;
  lastStandTicks?: number;
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
  buffType?: string;
  debuffType?: string;
  duration?: number;
  selfShield?: number;
  lifeSteal?: boolean;
  energySteal?: boolean;
  energyDrain?: boolean;
  tags?: string[];
}

export interface RoundExecutionInput {
  seed: number;
  roundNumber: number;
  playerATeam: PetState[];
  playerBTeam: PetState[];
  playerASelections: Record<string, string[]>;  // petUid -> [cardInstanceId, ...]
  playerBSelections: Record<string, string[]>;
  cardTraits?: Record<string, string>;         // cardInstanceId -> traitId
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
            playerASelections, playerBSelections, cardTraits = {}, cardEffects = {} } = input;

    const rng = this._makeRng(seed + roundNumber);

    // Deep-clone so we never mutate input
    const teamA: PetState[] = playerATeam.map(p => ({
      ...p, statusEffects: p.statusEffects?.map(s => ({ ...s })) ?? []
    }));
    const teamB: PetState[] = playerBTeam.map(p => ({
      ...p, statusEffects: p.statusEffects?.map(s => ({ ...s })) ?? []
    }));
    const selectedTraitsByPetId = new Map<string, CardEffect>();

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

      // Check if stunned / feared / disabled.
      if (pet.statusEffects.some(s => s.name === 'stun' || s.name === 'fear' || s.name === 'disabled')) {
        pet.statusEffects = pet.statusEffects.filter(s =>
          s.name !== 'stun' && s.name !== 'fear' && s.name !== 'disabled',
        );
        continue;
      }

      const selections = team === 'A' ? playerASelections : playerBSelections;
      const selectedCards = (selections[pet.uid] ?? []) as string[];
      if (selectedCards.length === 0) continue;

      const cardId   = selectedCards[0];
      const traitId   = cardTraits[cardId] ?? cardId;
      const cardFx    = resolveCardEffect(traitId, cardEffects[cardId]);
      selectedTraitsByPetId.set(pet.uid, cardFx);
      const effectType  = cardFx.effectType;
      const effectValue = cardFx.effectValue;
      const targetPref  = cardFx.target;
      const tags = cardFx.tags ?? [];

      const enemyTeam = team === 'A' ? teamB : teamA;
      const allyTeam  = team === 'A' ? teamA : teamB;
      const selfOrAllyTarget = allyTeam.find(p => !p.isFainted) ?? pet;

      let damage      = 0;
      let healAmount  = 0;
      let shieldAmount = 0;
      let statusApplied = '';
      let actionTarget: PetState | null = null;
      let actionTargetTeam: 'A' | 'B' = team === 'A' ? 'B' : 'A';

      if (tags.includes('cleanse') && pet.statusEffects.length > 0) {
        pet.statusEffects = [];
      }

      switch (effectType) {
        // ── Offensive ───────────────────────────────────────────────────────
        case 'damage':
        case 'aoe': {
           const enemy = this._selectTarget(enemyTeam, targetPref);
           if (!enemy) continue;
          actionTarget = enemy;
          actionTargetTeam = team === 'A' ? 'B' : 'A';
          const base = effectValue > 0 ? effectValue + rng.nextInt(8) - 4 : 30 + rng.nextInt(8) - 4;
          const damageBoost = tags.includes('bonus_damage_if_debuffed') && enemy.statusEffects.length > 0
            ? 1.2
            : 1.0;
          const critChance = Math.max(
            0,
            Math.min(0.3, (pet.mor * 0.001) - (enemy.spd * 0.0005)),
          );
          const crit = tags.includes('crit_if_first') || (critChance > 0 && rng.next() < critChance);
          const critMultiplier = tags.includes('double_crit_damage') ? 3 : 2;
          const hitCount = tags.includes('multi_hit_3') ? 3 : 1;
          damage = Math.max(1, Math.round((base - Math.floor((enemy.def ?? 0) / 3)) * damageBoost));
          // Class bonus: +15% or -15% based on speed (simplified)
            const ignoreShield = enemy.statusEffects.some(s => s.name === 'sleep');
           let totalActual = 0;
            for (let i = 0; i < hitCount; i++) {
              const hitDamage = Math.max(1, Math.min(90, crit ? damage * critMultiplier : damage));
              const shieldAbsorb = ignoreShield ? 0 : Math.min(enemy.shield, hitDamage);
              enemy.shield -= shieldAbsorb;
              const actual = hitDamage - shieldAbsorb;
              enemy.hp = Math.max(0, enemy.hp - actual);
              totalActual += actual;
              if (enemy.hp <= 0) enemy.isFainted = true;
              if (ignoreShield) {
                enemy.statusEffects = enemy.statusEffects.filter(s => s.name !== 'sleep');
              }
              if (enemy.isFainted) break;
            }
           const victimFx = selectedTraitsByPetId.get(enemy.uid);
           if (victimFx?.tags?.includes('counter_stun_plant_reptile') ||
               victimFx?.tags?.includes('counter_stun_aqua_bird')) {
             enemy.statusEffects.push({ name: 'stun', remainingRounds: 1, magnitude: 0 });
             statusApplied = 'stun';
           }
           if (victimFx?.tags?.includes('on_hit_energy_vs_aquatic')) {
             (pet as PetState & { energy?: number }).energy =
               ((pet as PetState & { energy?: number }).energy ?? 0) + 1;
           }
           if (victimFx?.tags?.includes('disable_horn_next') ||
               victimFx?.tags?.includes('disable_ability') ||
               victimFx?.tags?.includes('disable_melee_next')) {
             pet.statusEffects.push({ name: 'disabled', remainingRounds: 1, magnitude: 0 });
             statusApplied = 'disabled';
           }
           if ((tags.includes('end_last_stand') || tags.includes('prevent_last_stand')) && (enemy.lastStandTicks ?? 0) > 0) {
             enemy.lastStandTicks = 0;
             enemy.hp = 0;
             enemy.isFainted = true;
           }
           if (cardFx.lifeSteal && totalActual > 0) {
               healAmount = Math.min(totalActual, 50);
               pet.hp = Math.min(pet.maxHp, pet.hp + healAmount);
           }
           if (cardFx.energySteal || cardFx.energyDrain) {
             const energyTarget = enemyTeam.find(p => !p.isFainted) ?? enemy;
             if (energyTarget && energyTarget !== pet) {
              (energyTarget as PetState & { energy?: number }).energy =
                Math.max(0, ((energyTarget as PetState & { energy?: number }).energy ?? 0) - 1);
              if (cardFx.energySteal) {
                (pet as PetState & { energy?: number }).energy =
                  ((pet as PetState & { energy?: number }).energy ?? 0) + 1;
               }
             }
           }
           if (tags.includes('energy_on_crit') && crit) {
             (pet as PetState & { energy?: number }).energy =
               ((pet as PetState & { energy?: number }).energy ?? 0) + 1;
           }
           if (tags.includes('self_aroma')) {
             pet.statusEffects.push({ name: 'aroma', remainingRounds: 1, magnitude: 0 });
           }
           if (tags.includes('self_speed_up')) {
             pet.statusEffects.push({ name: 'speed_up', remainingRounds: 2, magnitude: 20 });
           }
           const reflect = enemy.statusEffects.find(s => s.name === 'reflect');
           if (reflect && pet.hp > 0) {
             const reflected = Math.max(1, Math.min(90, Math.round(totalActual * ((reflect.magnitude ?? 0) / 100))));
             pet.hp = Math.max(0, pet.hp - reflected);
             if (pet.hp <= 0) pet.isFainted = true;
           }
           break;
         }
        case 'shieldBreak': {
           const enemy = this._selectTarget(enemyTeam);
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
        case 'poison':
        case 'stench': {
           const enemy = this._selectTarget(enemyTeam);
           if (!enemy) continue;
          actionTarget = enemy;
          actionTargetTeam = team === 'A' ? 'B' : 'A';
          const mag = effectValue > 0 ? effectValue : 15;
          enemy.statusEffects.push({
            name: effectType,
            remainingRounds: cardFx.duration ?? 2,
            magnitude: mag,
          });
          statusApplied = effectType;
          // Also deal small damage on application
          damage = Math.max(1, Math.floor(mag * 0.5));
          enemy.hp = Math.max(0, enemy.hp - damage);
          if (enemy.hp <= 0) enemy.isFainted = true;
          break;
        }
        case 'burn': {
           const enemy = this._selectTarget(enemyTeam);
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
          const enemy = this._selectTarget(enemyTeam);
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
        case 'spd_down':
        case 'sleep':
        case 'fear':
        case 'aroma':
        case 'chill':
        case 'jinx':
        case 'heal_block':
        case 'crit_block':
        case 'disabled':
        case 'reflect': {
           const enemy = targetPref === 'self' || targetPref === 'ally'
             ? selfOrAllyTarget
             : this._selectTarget(enemyTeam);
           if (!enemy) continue;
          actionTarget = enemy;
          actionTargetTeam = team === 'A' ? 'B' : 'A';
          const debuffName = cardFx.debuffType ?? effectType;
          enemy.statusEffects.push({
            name: debuffName,
            remainingRounds: cardFx.duration ?? 2,
            magnitude: effectValue,
          });
          statusApplied = debuffName;
          break;
        }

        // ── Self / Ally ──────────────────────────────────────────────────────
        case 'heal':
        case 'regen': {
          healAmount = effectValue > 0 ? effectValue : 30;
          const targetPet = targetPref === 'self' || targetPref === 'ally'
            ? selfOrAllyTarget
            : pet;
          if (targetPet.statusEffects.some(s => s.name === 'heal_block')) {
            break;
          }
          targetPet.hp = Math.min(targetPet.maxHp, targetPet.hp + healAmount);
          actionTarget = targetPet;
          actionTargetTeam = team;
          break;
        }
        case 'shield': {
          shieldAmount = effectValue > 0 ? effectValue : 50;
          const targetPet = targetPref === 'self' || targetPref === 'ally'
            ? selfOrAllyTarget
            : pet;
          targetPet.shield += shieldAmount;
          actionTarget = targetPet;
          actionTargetTeam = team;
          break;
        }
        case 'buff':
        case 'atk_up':
        case 'def_up':
        case 'spd_up':
        case 'energized': {
          const buffName = cardFx.buffType ?? effectType;
          const targetPet = targetPref === 'self' || targetPref === 'ally'
            ? selfOrAllyTarget
            : pet;
          targetPet.statusEffects.push({
            name: buffName,
            remainingRounds: cardFx.duration ?? 2,
            magnitude: effectValue,
          });
          statusApplied = buffName;
          actionTarget = targetPet;
          actionTargetTeam = team;
          break;
        }

        // ── Default: treat as damage ─────────────────────────────────────────
        default: {
           const enemy = this._selectTarget(enemyTeam);
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

      if (cardFx.selfShield > 0) {
        const shieldAmt = Math.min(cardFx.selfShield, 999);
        pet.shield += shieldAmt;
        shieldAmount += shieldAmt;
      }

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

  private _selectTarget(team: PetState[], targetSpec?: string): PetState | null {
    const alive = team.filter(p => !p.isFainted);
    if (alive.length === 0) return null;

    // Build a sorted candidate list based on the card's target spec.
    let candidates: PetState[];
    if (targetSpec === 'furthest_enemy' || targetSpec === 'back_enemy') {
      // Back row first (highest index alive).
      candidates = [...alive].reverse();
    } else if (targetSpec === 'lowest_hp_enemy') {
      candidates = [...alive].sort((a, b) => a.hp - b.hp);
    } else if (targetSpec === 'fastest_enemy') {
      candidates = [...alive].sort((a, b) => b.spd - a.spd);
    } else {
      // Default: front-most alive.
      candidates = alive;
    }

    // Aroma overrides position preference (forces targeting the aroma pet).
    const aroma = candidates.find(p => p.statusEffects.some(s => s.name === 'aroma'));
    if (aroma) return aroma;

    // Stench makes a pet untargetable unless it's the only option.
    const visible = candidates.find(p => !p.statusEffects.some(s => s.name === 'stench'));
    return visible ?? candidates[0];
  }
}
