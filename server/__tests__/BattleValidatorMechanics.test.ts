import { BattleValidator } from '../src/systems/BattleValidator';
import { BattleValidationRequest, ValidationResult } from '../src/types/pvp';
import { BattleActionLog, PetTeamSnapshot } from '../src/types/pvp';

describe('BattleValidator - Axie Mechanics', () => {
  const validator = new BattleValidator();

  describe('Energy Mechanics - FIXED', () => {
    it('should regenerate energy ONCE per round, not per action', () => {
      const request: BattleValidationRequest = {
        playerId: 'player1',
        playerTeam: ['pet1', 'pet2', 'pet3'],
        opponentTeam: ['opp1', 'opp2', 'opp3'],
        winner: 'player',
        actionLog: [
          // Round 1: Player acts twice (using 4 energy total from pool of 3)
          { round: 1, actor: 'pet1', action: 'Bite', energyUsed: 2, damageDealt: 30, timestamp: 100 },
          { round: 1, actor: 'pet2', action: 'Heal', energyUsed: 1, damageDealt: 0, timestamp: 200 },
          // Round 2: Should have 3 (starting) - 3 (spent) + 2 (regen) = 2
          { round: 2, actor: 'pet1', action: 'Attack', energyUsed: 2, damageDealt: 25, timestamp: 300 },
        ] as BattleActionLog[],
        finalPlayerTeamState: [
          { petId: 'pet1', hp: 150, statusEffects: [] },
          { petId: 'pet2', hp: 150, statusEffects: [] },
          { petId: 'pet3', hp: 150, statusEffects: [] },
        ],
        finalOpponentTeamState: [
          { petId: 'opp1', hp: 0, statusEffects: [] },
          { petId: 'opp2', hp: 0, statusEffects: [] },
          { petId: 'opp3', hp: 0, statusEffects: [] },
        ],
        battleDurationMs: 60000,
        randomSeed: 12345,
      };

      const result = validator.validate(request);
      expect(result.result).toBe(ValidationResult.ACCEPTED);
    });

    it('should reject if player tries to use more energy than available', () => {
      const request: BattleValidationRequest = {
        playerId: 'player1',
        playerTeam: ['pet1', 'pet2', 'pet3'],
        opponentTeam: ['opp1', 'opp2', 'opp3'],
        winner: 'player',
        actionLog: [
          // Round 1: Try to use 5 energy (only have 3)
          { round: 1, actor: 'pet1', action: 'Bite', energyUsed: 2, damageDealt: 30, timestamp: 100 },
          { round: 1, actor: 'pet2', action: 'Heal', energyUsed: 2, damageDealt: 0, timestamp: 200 },
          { round: 1, actor: 'pet3', action: 'Attack', energyUsed: 2, damageDealt: 20, timestamp: 300 }, // Should fail
        ] as BattleActionLog[],
        finalPlayerTeamState: [] as PetTeamSnapshot[],
        finalOpponentTeamState: [] as PetTeamSnapshot[],
        battleDurationMs: 60000,
        randomSeed: 12345,
      };

      const result = validator.validate(request);
      expect(result.result).toBe(ValidationResult.REJECTED);
      expect(result.reason).toContain('Insufficient energy');
    });

    it('should reject invalid energy costs (not 1 or 2)', () => {
      const request: BattleValidationRequest = {
        playerId: 'player1',
        playerTeam: ['pet1', 'pet2', 'pet3'],
        opponentTeam: ['opp1', 'opp2', 'opp3'],
        winner: 'player',
        actionLog: [
          { round: 1, actor: 'pet1', action: 'Bite', energyUsed: 3, damageDealt: 30, timestamp: 100 }, // Invalid!
        ] as BattleActionLog[],
        finalPlayerTeamState: [] as PetTeamSnapshot[],
        finalOpponentTeamState: [] as PetTeamSnapshot[],
        battleDurationMs: 60000,
        randomSeed: 12345,
      };

      const result = validator.validate(request);
      expect(result.result).toBe(ValidationResult.REJECTED);
      expect(result.reason).toContain('Invalid energy cost');
    });
  });

  describe('Damage Mechanics', () => {
    it('should reject damage exceeding single-target cap of 90', () => {
      const request: BattleValidationRequest = {
        playerId: 'player1',
        playerTeam: ['pet1', 'pet2', 'pet3'],
        opponentTeam: ['opp1', 'opp2', 'opp3'],
        winner: 'player',
        actionLog: [
          {
            round: 1,
            actor: 'pet1',
            action: 'Bite',
            target: 'opp1',
            energyUsed: 2,
            damageDealt: 95, // Exceeds 90 cap!
            timestamp: 100,
          },
        ] as BattleActionLog[],
        finalPlayerTeamState: [] as PetTeamSnapshot[],
        finalOpponentTeamState: [] as PetTeamSnapshot[],
        battleDurationMs: 60000,
        randomSeed: 12345,
      };

      const result = validator.validate(request);
      expect(result.result).toBe(ValidationResult.REJECTED);
      expect(result.reason).toContain('Damage exceeds cap');
    });

    it('should reject damage exceeding AoE cap of 30', () => {
      const request: BattleValidationRequest = {
        playerId: 'player1',
        playerTeam: ['pet1', 'pet2', 'pet3'],
        opponentTeam: ['opp1', 'opp2', 'opp3'],
        winner: 'player',
        actionLog: [
          {
            round: 1,
            actor: 'pet1',
            action: 'AoE', // No target = AoE
            energyUsed: 2,
            damageDealt: 35, // Exceeds 30 AoE cap!
            timestamp: 100,
          },
        ] as BattleActionLog[],
        finalPlayerTeamState: [] as PetTeamSnapshot[],
        finalOpponentTeamState: [] as PetTeamSnapshot[],
        battleDurationMs: 60000,
        randomSeed: 12345,
      };

      const result = validator.validate(request);
      expect(result.result).toBe(ValidationResult.REJECTED);
      expect(result.reason).toContain('Damage exceeds cap');
    });

    it('should allow valid single-target damage up to 90', () => {
      const request: BattleValidationRequest = {
        playerId: 'player1',
        playerTeam: ['pet1', 'pet2', 'pet3'],
        opponentTeam: ['opp1', 'opp2', 'opp3'],
        winner: 'player',
        actionLog: [
          {
            round: 1,
            actor: 'pet1',
            action: 'MaxDamage',
            target: 'opp1',
            energyUsed: 2,
            damageDealt: 90, // Exactly at cap
            timestamp: 100,
          },
        ] as BattleActionLog[],
        finalPlayerTeamState: [{ petId: 'pet1', hp: 150, statusEffects: [] }],
        finalOpponentTeamState: [{ petId: 'opp1', hp: 0, statusEffects: [] }],
        battleDurationMs: 60000,
        randomSeed: 12345,
      };

      const result = validator.validate(request);
      expect(result.result).toBe(ValidationResult.ACCEPTED);
    });
  });

  describe('Action Sequence Validation', () => {
    it('should reject if pet targets wrong team', () => {
      const request: BattleValidationRequest = {
        playerId: 'player1',
        playerTeam: ['pet1', 'pet2', 'pet3'],
        opponentTeam: ['opp1', 'opp2', 'opp3'],
        winner: 'player',
        actionLog: [
          {
            round: 1,
            actor: 'pet1',
            action: 'Bite',
            target: 'pet2', // Targeting own team!
            energyUsed: 2,
            damageDealt: 30,
            timestamp: 100,
          },
        ] as BattleActionLog[],
        finalPlayerTeamState: [
          { petId: 'pet1', hp: 150, statusEffects: [] },
          { petId: 'pet2', hp: 150, statusEffects: [] },
          { petId: 'pet3', hp: 150, statusEffects: [] },
        ],
        finalOpponentTeamState: [
          { petId: 'opp1', hp: 0, statusEffects: [] },
          { petId: 'opp2', hp: 0, statusEffects: [] },
          { petId: 'opp3', hp: 0, statusEffects: [] },
        ],
        battleDurationMs: 60000,
        randomSeed: 12345,
      };

      const result = validator.validate(request);
      expect(result.result).toBe(ValidationResult.REJECTED);
      expect(result.reason).toContain('Invalid target');
    });
  });

  describe('Outcome Validation', () => {
    it('should reject if claimed winner contradicts final state', () => {
      const request: BattleValidationRequest = {
        playerId: 'player1',
        playerTeam: ['pet1', 'pet2', 'pet3'],
        opponentTeam: ['opp1', 'opp2', 'opp3'],
        winner: 'player', // Claimed player won
        actionLog: [
          {
            round: 1,
            actor: 'pet1',
            action: 'Bite',
            target: 'opp1',
            energyUsed: 2,
            damageDealt: 30,
            timestamp: 100,
          },
        ] as BattleActionLog[],
        // But final state shows opponent alive, player dead
        finalPlayerTeamState: [{ petId: 'pet1', hp: 0, statusEffects: [] }],
        finalOpponentTeamState: [{ petId: 'opp1', hp: 100, statusEffects: [] }],
        battleDurationMs: 60000,
        randomSeed: 12345,
      };

      const result = validator.validate(request);
      expect(result.result).toBe(ValidationResult.REJECTED);
      expect(result.reason).toContain('Winner mismatch');
    });

    it('should accept if winner matches final state', () => {
      const request: BattleValidationRequest = {
        playerId: 'player1',
        playerTeam: ['pet1', 'pet2', 'pet3'],
        opponentTeam: ['opp1', 'opp2', 'opp3'],
        winner: 'player', // Player won
        actionLog: [
          {
            round: 1,
            actor: 'pet1',
            action: 'Bite',
            target: 'opp1',
            energyUsed: 2,
            damageDealt: 30,
            timestamp: 100,
          },
        ] as BattleActionLog[],
        // Final state shows player alive, all opponents dead
        finalPlayerTeamState: [
          { petId: 'pet1', hp: 100, statusEffects: [] },
          { petId: 'pet2', hp: 50, statusEffects: [] },
          { petId: 'pet3', hp: 0, statusEffects: [] },
        ],
        finalOpponentTeamState: [
          { petId: 'opp1', hp: 0, statusEffects: [] },
          { petId: 'opp2', hp: 0, statusEffects: [] },
          { petId: 'opp3', hp: 0, statusEffects: [] },
        ],
        battleDurationMs: 60000,
        randomSeed: 12345,
      };

      const result = validator.validate(request);
      expect(result.result).toBe(ValidationResult.ACCEPTED);
    });
  });
});
