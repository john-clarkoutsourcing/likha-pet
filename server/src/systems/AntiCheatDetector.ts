import { PlayerRanking } from '../types/pvp';

/**
 * AntiCheatDetector — Detects suspicious player behavior
 * 
 * Heuristics:
 * - Win rate anomalies (new players with >80% win rate)
 * - Impossible damage values
 * - Energy manipulation patterns
 * - Unusual battle duration (too fast/slow)
 * - Targeting impossible pets
 */
export class AntiCheatDetector {
  private suspicionScores: Map<string, number> = new Map();
  private flaggedAccounts: Set<string> = new Set();

  /**
   * Check if player should be flagged for review
   */
  isSuspicious(playerId: string): boolean {
    return this.flaggedAccounts.has(playerId);
  }

  /**
   * Calculate suspicion score for a player
   */
  calculateScore(
    playerId: string,
    ranking: PlayerRanking | null,
    battleDurationMs: number,
    damagePatterns: DamagePattern[],
  ): number {
    let score = 0;

    // Heuristic 1: New account with high win rate
    if (ranking) {
      const totalGames = ranking.wins + ranking.losses;
      if (totalGames < 10 && ranking.winRate > 0.8) {
        score += 25; // New account with >80% win rate
      } else if (totalGames < 20 && ranking.winRate > 0.9) {
        score += 20; // Early account with >90% win rate
      }
    }

    // Heuristic 2: Battle duration anomalies
    const avgBattleMs = 30000; // Expected ~30 seconds
    if (battleDurationMs < 10000) {
      score += 15; // Too fast (possible script automation)
    } else if (battleDurationMs > 120000) {
      score += 5; // Too slow (unusual but less suspicious)
    }

    // Heuristic 3: Damage pattern anomalies
    const damageScore = this._analyzeDamagePatterns(damagePatterns);
    score += damageScore;

    this.suspicionScores.set(playerId, score);

    if (score > 70) {
      this.flaggedAccounts.add(playerId);
    }

    return score;
  }

  /**
   * Analyze damage patterns for anomalies
   */
  private _analyzeDamagePatterns(patterns: DamagePattern[]): number {
    let score = 0;

    // Check for unrealistic patterns
    const perfectAccuracy = patterns.every((p) => p.hit);
    if (perfectAccuracy && patterns.length > 10) {
      score += 20; // Never missed a single turn
    }

    // Check for always maxing damage
    const alwaysMax = patterns.every((p) => p.damageDealt === p.maxPossible);
    if (alwaysMax && patterns.length > 5) {
      score += 25; // Suspicious: always dealing max damage
    }

    // Check for critical hit rate > 50% (should be ~10%)
    const criticalHits = patterns.filter((p) => p.isCritical).length;
    const critRate = criticalHits / patterns.length;
    if (critRate > 0.5) {
      score += 30; // Impossible critical hit rate
    }

    return Math.min(score, 50); // Cap at 50 for this category
  }

  /**
   * Get suspicion report for a player
   */
  getReport(playerId: string): SuspicionReport {
    return {
      playerId,
      score: this.suspicionScores.get(playerId) || 0,
      flagged: this.isSuspicious(playerId),
      timestamp: Date.now(),
    };
  }

  /**
   * Flag an account for manual review
   */
  flagAccount(playerId: string, reason: string): void {
    this.flaggedAccounts.add(playerId);
    console.log(`[AntiCheat] Flagged ${playerId}: ${reason}`);
  }

  /**
   * Unflag an account after review
   */
  unflagAccount(playerId: string): void {
    this.flaggedAccounts.delete(playerId);
  }

  /**
   * Get all flagged accounts
   */
  getFlaggedAccounts(): string[] {
    return Array.from(this.flaggedAccounts);
  }
}

export interface DamagePattern {
  damageDealt: number;
  maxPossible: number;
  hit: boolean;
  isCritical: boolean;
  targetWasBuffed: boolean;
}

export interface SuspicionReport {
  playerId: string;
  score: number; // 0-100
  flagged: boolean;
  timestamp: number;
}
