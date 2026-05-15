/**
 * Express API Server for Likha Pet — Pet Lifecycle Management
 * 
 * This server handles all pet operations: spawning eggs with random DNA,
 * checking egg readiness, and hatching them into fully-fledged creatures.
 * 
 * Architecture:
 *   1. Client (Phaser) sends HTTP requests to /api endpoints
 *   2. petRoutes delegates to HatcheryManager (domain logic)
 *   3. HatcheryManager coordinates DNADecoder (genetic algorithms) & MemoryStore (storage)
 *   4. Errors are caught by middleware and returned as typed HTTP responses
 * 
 * Data Flow:
 *   POST /api/spawn-egg → HatcheryManager.spawnEgg() → MemoryStore.save(pet)
 *   POST /api/hatch/:id → HatcheryManager.hatchEgg() → Pet.hatch() → MemoryStore.save(pet)
 *   GET /api/inventory → HatcheryManager.getInventory() → MemoryStore.findByOwner()
 * 
 * Notes:
 *   - All timestamps use Date.now() (milliseconds)
 *   - Ownership is hardcoded to 'player1' in MVP (no JWT auth yet)
 *   - MemoryStore clears on server restart (no persistence)
 *   - See AGENTS.md for full architecture documentation
 */

import express from 'express';
import cors from 'cors';
import { MemoryStore } from './store/MemoryStore';
import { HatcheryManager } from './systems/HatcheryManager';
import { createPetRouter } from './routes/petRoutes';
import { createAuthRoutes } from './routes/authRoutes';

const app = express();
const PORT = process.env.PORT ?? 3000;

// Enable CORS for browser clients and parse JSON request bodies
app.use(cors());
app.use(express.json());

// Initialize the in-memory pet store and hatchery manager
// Every request will use these same instances (no persistence on restart)
const store = new MemoryStore();
const hatchery = new HatcheryManager(store);

// Mount authentication routes under /api/auth namespace
app.use('/api/auth', createAuthRoutes(store));

// Mount pet lifecycle routes under /api namespace
// All endpoints are defined in petRoutes.ts
app.use('/api', createPetRouter(hatchery));

// Health check endpoint for orchestration scripts (run.sh, load balancers, etc.)
app.get('/health', (_req, res) => res.json({ status: 'ok', game: 'Likha Pet' }));

app.listen(PORT, () => {
  console.log(`🐣  Likha Pet server running → http://localhost:${PORT}`);
});
