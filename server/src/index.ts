import express from 'express';
import cors from 'cors';
import { MemoryStore } from './store/MemoryStore';
import { HatcheryManager } from './systems/HatcheryManager';
import { createPetRouter } from './routes/petRoutes';

const app = express();
const PORT = process.env.PORT ?? 3000;

app.use(cors());
app.use(express.json());

const store = new MemoryStore();
const hatchery = new HatcheryManager(store);

app.use('/api', createPetRouter(hatchery));
app.get('/health', (_req, res) => res.json({ status: 'ok', game: 'Likha Pet' }));

app.listen(PORT, () => {
  console.log(`🐣  Likha Pet server running → http://localhost:${PORT}`);
});
