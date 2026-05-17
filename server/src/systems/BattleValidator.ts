import { BattleValidationRequest, BattleValidationResponse, ValidationResult, PetTeamSnapshot, BattleActionLog } from '../types/pvp';

/**
 * BattleValidator — Validates PvP battles for anti-cheat
 * 
 * Process:
 * 1. Receive client's battle log + final state
 * 2. Replay battle server-side with recorded actions
 * 3. Compare server outcome with client's claimed outcome
 * 4. Detect energy cheats, damage exploits, impossible move sequences
 * 5. Flag suspicious patterns (win rate anomalies, etc.)
 */
export class BattleValidator {
  /**
   * Validate a submitted PvP battle result
   * Returns: ACCEPTED if valid, REJECTED if cheating detected, SUSPICIOUS if flagged for review
   */
  validate(request: BattleValidationRequest): BattleValidationResponse {
    // Step 1: Validate input structure
    if (!this._validateStructure(request)) {
      return {
        result: ValidationResult.REJECTED,
        reason: 'Invalid battle data structure',
      };
    }

    // Step 2: Validate team composition
    if (!this._validateTeamComposition(request)) {
      return {
        result: ValidationResult.REJECTED,
        reason: 'Invalid team composition (not owned by player)',
      };
    }

    // Step 3: Validate action log for illegal moves
    const actionValidation = this._validateActions(request);
    if (!actionValidation.valid) {
      return {
        result: ValidationResult.REJECTED,
        reason: actionValidation.reason || 'Illegal action detected',
      };
    }

    // Step 3.5: Validate action sequence integrity
    const sequenceValidation = this._validateActionSequence(
      request.actionLog,
      request.playerTeam,
      request.opponentTeam,
    );
    if (!sequenceValidation) {
      return {
        result: ValidationResult.REJECTED,
        reason: 'Invalid action sequence detected',
      };
    }

    // Step 4: Replay battle and compare outcome
    const replayValidation = this._replayAndCompare(request);
    if (!replayValidation.valid) {
      return {
        result: ValidationResult.REJECTED,
        reason: replayValidation.reason || 'Battle outcome mismatch',
        flaggedForReview: true,
      };
    }

    // Step 5: Check for suspicious patterns
    const suspiciousScore = this._calculateSuspiciousScore(request);
    if (suspiciousScore > 70) {
      return {
        result: ValidationResult.SUSPICIOUS,
        reason: `Suspicious activity detected (score: ${suspiciousScore}/100)`,
        flaggedForReview: true,
      };
    }

    // Battle is valid
    return {
      result: ValidationResult.ACCEPTED,
      mmrChange: this._calculateMMRChange(request),
    };
  }

  /**
   * Validate basic structure of battle request
   */
  private _validateStructure(req: BattleValidationRequest): boolean {
    if (!req.playerId || !req.playerTeam || !req.opponentTeam) {
      return false;
    }
    if (req.playerTeam.length !== 3 || req.opponentTeam.length !== 3) {
      return false;
    }
    if (!Array.isArray(req.actionLog)) {
      return false;
    }
    if (!req.finalPlayerTeamState || !req.finalOpponentTeamState) {
      return false;
    }
    return true;
  }

  /**
   * Validate team ownership (TODO: requires DB lookup)
   * For now, just check teams are valid length
   */
  private _validateTeamComposition(req: BattleValidationRequest): boolean {
    // TODO: Query Firestore to verify:
    // - All 3 pet UIDs in playerTeam exist
    // - All are owned by playerId
    // - Pets are HATCHED (not EGG)
    // - Pets are not locked in another PvP battle
    return true; // Placeholder
  }

  /**
   * Validate each action in the battle log
   */
  private _validateActions(
    req: BattleValidationRequest,
  ): { valid: boolean; reason?: string } {
    let playerEnergy = 3; // Starting energy
    let opponentEnergy = 3;
    let lastProcessedRound = 0; // Track round changes

    for (const action of req.actionLog) {
      const isPlayer = req.playerTeam.includes(action.actor);
      const currentEnergy = isPlayer ? playerEnergy : opponentEnergy;

      // Check: Energy availability
      if (action.energyUsed > currentEnergy) {
        return {
          valid: false,
          reason: `Insufficient energy: used ${action.energyUsed}, had ${currentEnergy}`,
        };
      }

      // Check: Energy used is 1 or 2 (Axie Classic rules)
      if (action.energyUsed < 1 || action.energyUsed > 2) {
        return {
          valid: false,
          reason: `Invalid energy cost: ${action.energyUsed} (must be 1 or 2)`,
        };
      }

      // Check: Action exists in trait library (TODO: validate against trait.dart definitions)
      // if (!this._isValidAction(action.action)) {
      //   return { valid: false, reason: `Invalid action: ${action.action}` };
      // }

      // Check: Target validity
      if (action.target) {
        const targetTeam = isPlayer ? req.opponentTeam : req.playerTeam;
        if (!targetTeam.includes(action.target)) {
          return {
            valid: false,
            reason: `Invalid target: ${action.target}`,
          };
        }
      }

      // Check: Damage is within caps (single: 90, AoE: 30)
      const damageIsAoE = !action.target;
      const maxDamage = damageIsAoE ? 30 : 90;
      if ((action.damageDealt || 0) > maxDamage) {
        return {
          valid: false,
          reason: `Damage exceeds cap: ${action.damageDealt} > ${maxDamage}`,
        };
      }

      // Check: Damage is at least 1 (Axie rule)
      if ((action.damageDealt || 0) < 0) {
        return {
          valid: false,
          reason: `Damage cannot be negative: ${action.damageDealt}`,
        };
      }

      // Update energy: spend first, then regen if round changed
      if (isPlayer) {
        playerEnergy -= action.energyUsed;

        // Regenerate energy only ONCE per round (when round increments)
        if (action.round > lastProcessedRound) {
          playerEnergy += 2;
          lastProcessedRound = action.round;
        }

        // Cap energy at 9
        playerEnergy = Math.min(playerEnergy, 9);
      } else {
        opponentEnergy -= action.energyUsed;

        // Opponent energy regenerates on same round boundary
        if (action.round > lastProcessedRound) {
          opponentEnergy += 2;
        }

        opponentEnergy = Math.min(opponentEnergy, 9);
      }

      // Final safety check: energy should never be negative
      if (playerEnergy < 0 || opponentEnergy < 0) {
        return {
          valid: false,
          reason: `Energy pool corrupted (negative value)`,
        };
      }
    }

    return { valid: true };
  }

  /**
   * Replay battle server-side and compare with client's outcome
   * TODO: Import and run actual Dart battle engine via child process
   */
  private _replayAndCompare(
    req: BattleValidationRequest,
  ): { valid: boolean; reason?: string } {
    // Placeholder: In production, this would:
    // 1. Spawn battle engine subprocess
    // 2. Feed action log + random seed
    // 3. Compare final state with client's submission
    // 4. Check for outcome match (who won, final HP values, etc.)

    // For now, simple check: winner matches final state
    const playerAlive = req.finalPlayerTeamState.some((pet: PetTeamSnapshot) => pet.hp > 0);
    const opponentAlive = req.finalOpponentTeamState.some((pet: PetTeamSnapshot) => pet.hp > 0);

    const claimedPlayerWon = req.winner === 'player';
    const playerShouldWin = playerAlive && !opponentAlive;

    if (claimedPlayerWon !== playerShouldWin) {
      return {
        valid: false,
        reason: 'Winner mismatch: claimed vs. final state',
      };
    }

    return { valid: true };
  }

  /**
   * Calculate suspicious activity score (0-100)
   * Higher = more suspicious
   */
  private _calculateSuspiciousScore(req: BattleValidationRequest): number {
    let score = 0;

    // Heuristic 1: Battle duration too short
    if (req.battleDurationMs < 5000) {
      score += 20; // Very fast battles are suspicious
    }

    // Heuristic 2: Perfect HP (no damage taken)
    const playerHealthy = req.finalPlayerTeamState.every(
      (pet: PetTeamSnapshot) => pet.hp === 100,
    );
    if (playerHealthy) {
      score += 15; // Perfect health is suspicious
    }

    // Heuristic 3: Opponent team completely destroyed
    const opponentWiped = req.finalOpponentTeamState.every((pet: PetTeamSnapshot) => pet.hp <= 0);
    if (opponentWiped && playerHealthy) {
      score += 30; // Dominating victory is more suspicious
    }

    // Heuristic 4: Unusual action patterns (e.g., always attacking, never defending)
    const playerActions = req.actionLog.filter((a: BattleActionLog) =>
      req.playerTeam.includes(a.actor),
    );
    const defensiveActions = playerActions.filter((a: BattleActionLog) =>
      ['shield', 'heal', 'buff'].includes(a.action.toLowerCase()),
    );
    if (defensiveActions.length === 0) {
      score += 10; // No defensive moves is unusual
    }

    return Math.min(score, 100);
  }

  /**
   * Calculate MMR change based on opponent strength
   * TODO: Query player rankings table
   */
  private _calculateMMRChange(req: BattleValidationRequest): number {
    // Placeholder: Fixed +20 for win, -10 for loss
    if (req.winner === 'player') {
      return 20; // TODO: Scale by opponent MMR
    } else {
      return -10;
    }
  }

  /**
   * Validate damage formula: max(1, raw_damage - defense)
   * Axie Infinity: damage = max(1, (attacker.attack + skill.value) - defender.defense)
   * Caps: 90 single-target, 30 per-target AoE
   */
  private _validateDamageFormula(
    attackerAttack: number,
    defenderDefense: number,
    skillDamage: number,
    claimedDamage: number,
    isAoE: boolean = false,
  ): boolean {
    // Calculate expected damage
    const raw = attackerAttack + skillDamage;
    const netDamage = Math.max(1, raw - defenderDefense);
    const maxDamage = isAoE ? 30 : 90;
    const expectedDamage = Math.min(netDamage, maxDamage);

    // Allow small variance (±1) for rounding
    return Math.abs(expectedDamage - claimedDamage) <= 1;
  }

  /**
   * Validate formation-based targeting
   * Front row (index 0): can be targeted by any skill
   * Mid/Back rows (index 1-2): only by skills with back_enemy or lowest_hp_enemy targeting
   */
  private _validateTargetPosition(
    targetIndex: number,
    skillHasBackTargeting: boolean,
  ): boolean {
    if (targetIndex === 0) {
      return true; // Front can always be targeted
    } else {
      return skillHasBackTargeting; // Mid/Back need special targeting
    }
  }

  /**
   * Validate status effect application
   * Poison: 3 rounds duration, 8 damage per round
   * Stun: 1 round duration, skips next action
   * Buffs/Debuffs: track duration and expiration
   */
  private _validateStatusEffect(
    effectType: string,
    duration: number,
    value: number,
  ): boolean {
    switch (effectType.toLowerCase()) {
      case 'poison':
        return duration === 3 && value === 8;
      case 'burn':
        return duration >= 1 && value >= 5; // Rough validation
      case 'stun':
        return duration === 1; // Stun lasts one turn
      case 'buff':
      case 'debuff':
        return duration >= 1 && duration <= 5; // Buffs/debuffs last 1-5 rounds
      default:
        return false; // Unknown effect
    }
  }

  /**
   * Validate cooldown progression
   * Each action should decrement cooldown by 1
   * Cooldown must reach 0 before skill can be used again
   */
  private _validateCooldownTracking(actionLog: BattleActionLog[]): boolean {
    const cooldowns: { [skillId: string]: number } = {};

    for (const action of actionLog) {
      const skillKey = `${action.actor}-${action.action}`;

      // If skill was used, cooldown should be 0
      if (!cooldowns[skillKey] || cooldowns[skillKey] === 0) {
        // Mark skill as on cooldown after use
        // TODO: Get cooldown max from trait library
        cooldowns[skillKey] = 1; // Placeholder
      } else {
        // Skill is on cooldown, shouldn't be usable
        return false;
      }
    }

    return true;
  }

  /**
   * Validate action sequence integrity
   * - Pets should act in speed order (descending)
   * - Stunned pets should skip their turn
   * - Actions should follow game rules
   */
  private _validateActionSequence(
    actionLog: BattleActionLog[],
    playerTeam: string[],
    opponentTeam: string[],
  ): boolean {
    for (let i = 0; i < actionLog.length; i++) {
      const action = actionLog[i];

      // Check: Actor is in one of the teams
      const isPlayerPet = playerTeam.includes(action.actor);
      const isOpponentPet = opponentTeam.includes(action.actor);
      if (!isPlayerPet && !isOpponentPet) {
        return false; // Invalid actor
      }

      // Check: Target is in opposing team (if applicable)
      if (action.target) {
        const targetInPlayerTeam = playerTeam.includes(action.target);
        const targetInOpponentTeam = opponentTeam.includes(action.target);

        if (isPlayerPet && !targetInOpponentTeam) {
          return false; // Player pet can only target opponent
        }
        if (isOpponentPet && !targetInPlayerTeam) {
          return false; // Opponent pet can only target player
        }
      }
    }

    return true;
  }
}
