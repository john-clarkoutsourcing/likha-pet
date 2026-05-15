/**
 * Express API Server for Likha Pet — Pet Lifecycle Management + Authentication
 * 
 * This server handles:
 *   1. User authentication (register, login with JWT tokens)
 *   2. Pet lifecycle: spawning eggs with random DNA, hatching, inventory
 *   3. Data persistence via Firestore (or MemoryStore for testing)
 * 
 * Architecture:
 *   1. Firebase Admin SDK initializes (Firestore emulator in dev, real DB in prod)
 *   2. Auth routes handle user registration/login (Firestore-backed)
 *   3. Protected pet routes extract userId from JWT and scope operations
 *   4. HatcheryManager coordinates DNA logic, validation, and persistence
 * 
 * Data Flow:
 *   Register: POST /api/auth/register → User saved to /users/{userId}
 *   Login: POST /api/auth/login → JWT token returned (valid 24 hours)
 *   Spawn Egg: POST /api/spawn-egg → Pet saved to /users/{userId}/pets/{petId}
 *   Hatch: POST /api/hatch/:id → Pet.state updated to HATCHED
 *   Inventory: GET /api/inventory → All pets for authenticated user
 */

import express from 'express';
import cors from 'cors';
import { initializeFirebase } from './services/firebase';
import { FirestoreService } from './services/FirestoreService';
import { MemoryStore } from './store/MemoryStore';
import { HatcheryManager } from './systems/HatcheryManager';
import { createPetRouter } from './routes/petRoutes';
import { createAuthRoutes } from './routes/authRoutes';

const app = express();
const PORT = process.env.PORT ?? 3000;

// Enable CORS for browser clients and parse JSON request bodies
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin SDK (connects to Firestore emulator in dev)
initializeFirebase();
console.log(`✓ Firebase initialized (emulator: ${process.env.FIRESTORE_EMULATOR_HOST || 'none'})`);

// Initialize services
const store = new MemoryStore(); // Fallback for compatibility
const firestoreService = new FirestoreService();
const hatchery = new HatcheryManager(store, firestoreService);

// Mount authentication routes under /api/auth namespace
// Uses Firestore for user persistence
app.use('/api/auth', createAuthRoutes(firestoreService));

// Mount pet lifecycle routes under /api namespace
// All endpoints are protected by JWT auth (via middleware in petRoutes)
app.use('/api', createPetRouter(hatchery));

// Health check endpoint for orchestration scripts (run.sh, load balancers, etc.)
app.get('/health', (_req, res) => res.json({ status: 'ok', game: 'Likha Pet' }));

app.listen(PORT, () => {
  console.log(`🐣  Likha Pet server running → http://localhost:${PORT}`);
});
