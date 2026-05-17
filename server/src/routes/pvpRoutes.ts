import { Router } from 'express';
import { verifyAuth } from '../middleware/auth';
import { FirestoreService } from '../services/FirestoreService';
import { BattleValidator } from '../systems/BattleValidator';
import { AntiCheatDetector } from '../systems/AntiCheatDetector';
import {
  BattleValidationRequest,
  ValidationResult,
} from '../types/pvp';

export function createPvpRoutes(firestoreService: FirestoreService): Router {
  const router = Router();
  const battleValidator = new BattleValidator();
  const antiCheatDetector = new AntiCheatDetector();

  // Own MMR
  router.get('/mmr', verifyAuth, async (req, res) => {
    try {
      const mmr = await firestoreService.getUserMmr(req.userId!);
      res.json({ mmr });
    } catch (e) {
      res.status(500).json({ error: 'Failed to fetch MMR' });
    }
  });

  // Leaderboard
  router.get('/leaderboard', async (req, res) => {
    try {
      const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);
      const entries = await firestoreService.getMmrLeaderboard(limit);
      res.json({ entries });
    } catch (e) {
      res.status(500).json({ error: 'Failed to fetch leaderboard' });
    }
  });

  // Submit and validate battle result
  router.post('/validate-battle', verifyAuth, async (req, res) => {
    try {
      const request = req.body as BattleValidationRequest;
      const playerId = req.userId!;

      // Verify player owns their team
      if (request.playerId !== playerId) {
        return res.status(403).json({ error: 'Unauthorized' });
      }

      // Run validation
      const validation = battleValidator.validate(request);

      // If accepted, update MMR
      if (validation.result === ValidationResult.ACCEPTED) {
        const didWin = request.winner === 'player';
        const mmrChange = validation.mmrChange || 0;
        
        // Update player MMR in Firestore
        await firestoreService.updateUserMmr(playerId, mmrChange, didWin);

        // Check for suspicious patterns
        const userRanking = await firestoreService.getUserMmr(playerId);
        const suspicionScore = antiCheatDetector.calculateScore(
          playerId,
          { playerId, mmr: userRanking, wins: 0, losses: 0, winRate: 0, lastUpdated: Date.now() },
          request.battleDurationMs,
          [], // TODO: Parse damage patterns from actionLog
        );

        if (suspicionScore > 70) {
          console.log(
            `[AntiCheat] ${playerId} flagged with score ${suspicionScore}`,
          );
          antiCheatDetector.flagAccount(
            playerId,
            'High suspicion score from battle validation',
          );
        }

        return res.json({
          success: true,
          mmrChange,
          newMmr: userRanking + mmrChange,
          suspiciousFlagged: suspicionScore > 70,
        });
      } else if (validation.result === ValidationResult.SUSPICIOUS) {
        // Flag for review but still accept
        antiCheatDetector.flagAccount(playerId, validation.reason || 'Suspicious battle');
        return res.json({
          success: true,
          flagged: true,
          reason: validation.reason,
        });
      } else {
        // Rejected
        return res.status(400).json({
          success: false,
          reason: validation.reason,
          flaggedForReview: validation.flaggedForReview,
        });
      }
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'Battle validation failed' });
    }
  });

  // Get anti-cheat report for player
  router.get('/anti-cheat-report', verifyAuth, async (req, res) => {
    try {
      const playerId = req.userId!;
      const report = antiCheatDetector.getReport(playerId);
      res.json(report);
    } catch (e) {
      res.status(500).json({ error: 'Failed to fetch report' });
    }
  });

  return router;
}
