import { Router, Request, Response, NextFunction } from 'express';
import { HatcheryManager, HatcheryError } from '../systems/HatcheryManager';

export function createPetRouter(hatchery: HatcheryManager): Router {
  const router = Router();

  router.post('/spawn-egg', (req: Request, res: Response, next: NextFunction) => {
    const { owner } = req.body as { owner?: string };
    if (!owner?.trim()) {
      res.status(400).json({ error: 'owner is required.' });
      return;
    }
    try {
      const pet = hatchery.spawnEgg(owner.trim());
      res.status(201).json(pet);
    } catch (e) { next(e); }
  });

  router.get('/inventory', (req: Request, res: Response, next: NextFunction) => {
    const { owner } = req.query as { owner?: string };
    if (!owner?.trim()) {
      res.status(400).json({ error: 'owner query parameter is required.' });
      return;
    }
    try {
      res.json(hatchery.getInventory(owner.trim()));
    } catch (e) { next(e); }
  });

  router.post('/hatch/:id', (req: Request, res: Response, next: NextFunction) => {
    const { id } = req.params;
    const { owner } = req.body as { owner?: string };
    if (!owner?.trim()) {
      res.status(400).json({ error: 'owner is required.' });
      return;
    }
    try {
      const pet = hatchery.hatchEgg(id, owner.trim());
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
