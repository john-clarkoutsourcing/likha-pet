export enum PetState {
  EGG = 'Egg',
  HATCHED = 'Hatched',
}

export type Rarity = 'Common' | 'Uncommon' | 'Rare' | 'Epic' | 'Legendary';

export interface DNAAttributes {
  color: string;
  rarity: Rarity;
  basePower: number;
  element: string;
  pattern: string;
}

export interface PetDTO {
  id: string;
  dna: string;
  state: PetState;
  hatchTime: number;
  owner: string;
  attributes: DNAAttributes;
  name: string;
  createdAt: number;
  hatchedAt?: number;
}

// ── PvP Battle Validation ───────────────────────────────────────────────────

export interface BattleActionLog {
  round: number;
  actor: string;           // pet UID performing action
  action: string;          // trait/skill name
  target?: string;         // target pet UID (optional for AoE)
  energyUsed: number;
  damageDealt?: number;
  timestamp: number;
}

export interface BattleValidationRequest {
  playerId: string;
  playerTeam: string[];    // 3 pet UIDs
  opponentTeam: string[];  // 3 pet UIDs
  winner: string;          // 'player' | 'opponent'
  finalPlayerTeamState: PetTeamSnapshot[];
  finalOpponentTeamState: PetTeamSnapshot[];
  actionLog: BattleActionLog[];
  battleDurationMs: number;
  randomSeed?: number;     // for deterministic replay
}

export interface PetTeamSnapshot {
  petId: string;
  hp: number;
  statusEffects: StatusEffect[];
}

export interface StatusEffect {
  type: 'poison' | 'burn' | 'stun' | 'buff' | 'debuff';
  duration: number;
  value?: number;
}

export enum ValidationResult {
  ACCEPTED = 'accepted',
  REJECTED = 'rejected',
  SUSPICIOUS = 'suspicious',
}

export interface BattleValidationResponse {
  result: ValidationResult;
  reason?: string;
  mmrChange?: number;
  flaggedForReview?: boolean;
}

export interface PlayerRanking {
  playerId: string;
  mmr: number;
  wins: number;
  losses: number;
  winRate: number;
  lastUpdated: number;
}

export interface PvPQueueEntry {
  playerId: string;
  mmr: number;
  teamUids: string[];
  queuedAt: number;
  timeout: number;
}
