import { Router, Request, Response, NextFunction } from 'express';
import { HatcheryManager, HatcheryError } from '../systems/HatcheryManager';
import { verifyAuth } from '../middleware/auth';

export function createPetRouter(hatchery: HatcheryManager): Router {
  const router = Router();

  // All pet routes require authentication
  router.use(verifyAuth);

  router.post('/spawn-egg', async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Owner is now from JWT (req.userId), not from request body
      const pet = await hatchery.spawnEgg(req.userId!);
      res.status(201).json(pet);
    } catch (e) { next(e); }
  });

  router.get('/inventory', async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Owner is from JWT (req.userId), not from query parameter
      const pets = await hatchery.getInventory(req.userId!);
      res.json(pets);
    } catch (e) { next(e); }
  });

  router.post('/hatch/:id', async (req: Request, res: Response, next: NextFunction) => {
    const { id } = req.params;
    try {
      // Owner is from JWT (req.userId), not from request body
      const pet = await hatchery.hatchEgg(id, req.userId!);
      res.json(pet);
    } catch (e) { next(e); }
  });

  // Centralised error handler for this router
  router.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (err instanceof HatcheryError) {
      res.status(err.status).json({ error: err.message });
    } else {
      res.status(500).json({ error: 'Internal server error.' });
    }
  });

  return router;
}
