import * as http from 'http';
import express from 'express';
import cors from 'cors';
import { initializeFirebase } from './services/firebase';
import { FirestoreService } from './services/FirestoreService';
import { MemoryStore } from './store/MemoryStore';
import { HatcheryManager } from './systems/HatcheryManager';
import { createPetRouter } from './routes/petRoutes';
import { createAuthRoutes } from './routes/authRoutes';
import { createPvpRoutes } from './routes/pvpRoutes';
import { PvpGateway } from './ws/PvpGateway';

const app = express();
const PORT = process.env.PORT ?? 3000;

const corsOptions: cors.CorsOptions = {
  origin: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true,
};
app.use(cors(corsOptions));
app.options('*', cors(corsOptions)); // respond to all preflight requests
app.use(express.json());

initializeFirebase();
console.log(`✓ Firebase initialized (emulator: ${process.env.FIRESTORE_EMULATOR_HOST || 'none'})`);

const store = new MemoryStore();
const firestoreService = new FirestoreService();
const hatchery = new HatcheryManager(store, firestoreService);

app.use('/api/auth', createAuthRoutes(firestoreService));
app.use('/api', createPetRouter(hatchery));
app.use('/api/pvp', createPvpRoutes(firestoreService));
app.get('/health', (_req, res) => res.json({ status: 'ok', game: 'Likha Pet' }));

const httpServer = http.createServer(app);

PvpGateway.attach(httpServer, firestoreService);

httpServer.listen(PORT, () => {
  console.log(`🐣  Likha Pet server running → http://localhost:${PORT}`);
});
