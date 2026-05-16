import { Router } from 'express';
import { verifyAuth } from '../middleware/auth';
import { FirestoreService } from '../services/FirestoreService';

export function createPvpRoutes(firestoreService: FirestoreService): Router {
  const router = Router();

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

  return router;
}
