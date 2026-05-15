import express from 'express';
import request from 'supertest';
import jwt from 'jsonwebtoken';
import { MemoryStore } from '../src/store/MemoryStore';
import { FirestoreService } from '../src/services/FirestoreService';
import { HatcheryManager } from '../src/systems/HatcheryManager';
import { createPetRouter } from '../src/routes/petRoutes';
import { PetState } from '../src/models/BasePet';

// Mock Firestore
jest.mock('../src/services/FirestoreService');

const JWT_SECRET = 'your-secret-key-change-in-production';

function buildApp() {
  const app = express();
  app.use(express.json());

  const store = new MemoryStore();
  const firestore = new FirestoreService() as jest.Mocked<FirestoreService>;
  firestore.savePet = jest.fn().mockResolvedValue(undefined);
  firestore.getPetsForUser = jest.fn().mockResolvedValue([]);
  firestore.getPetById = jest.fn();
  firestore.updatePet = jest.fn().mockResolvedValue(undefined);

  const hatchery = new HatcheryManager(store, firestore);
  app.use('/api', createPetRouter(hatchery));
  return { app, firestore };
}

function getValidToken(userId = 'test-user') {
  return jwt.sign({ userId, email: 'test@example.com' }, JWT_SECRET, {
    expiresIn: '24h',
  });
}

describe('POST /api/spawn-egg (Updated for JWT auth)', () => {
  it('returns 201 with a new egg when JWT is provided', async () => {
    const { app, firestore } = buildApp();
    const token = getValidToken();

    const res = await request(app)
      .post('/api/spawn-egg')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(201);
    expect(res.body.state).toBe('Egg');
    expect(res.body.dna).toMatch(/^[0-9a-f]{24}$/);
    expect(firestore.savePet).toHaveBeenCalled();
  });

  it('returns 401 when JWT is missing', async () => {
    const { app } = buildApp();
    const res = await request(app).post('/api/spawn-egg').send({});
    expect(res.status).toBe(401);
  });
});

describe('GET /api/inventory (Updated for JWT auth)', () => {
  it('returns an empty array for a user with no pets', async () => {
    const { app, firestore } = buildApp();
    firestore.getPetsForUser.mockResolvedValue([]);
    const token = getValidToken();

    const res = await request(app)
      .get('/api/inventory')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('returns 401 when JWT is missing', async () => {
    const { app } = buildApp();
    const res = await request(app).get('/api/inventory');
    expect(res.status).toBe(401);
  });
});

describe('POST /api/hatch/:id (Updated for JWT auth)', () => {
  it('returns 409 when egg is not ready yet', async () => {
    const { app, firestore } = buildApp();
    const token = getValidToken('test-user');

    // First spawn an egg
    const spawn = await request(app)
      .post('/api/spawn-egg')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    const { id } = spawn.body;

    // Mock getPetById to return the spawned egg
    firestore.getPetById.mockResolvedValue({
      id,
      dna: spawn.body.dna,
      state: 'Egg',
      hatchTime: Date.now() + 30000, // 30 seconds in future
      createdAt: Date.now(),
    });

    // Try to hatch it immediately
    const res = await request(app)
      .post(`/api/hatch/${id}`)
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(409);
    expect(res.body.error).toMatch(/not ready/i);
  });

  it('returns 404 for an unknown pet id', async () => {
    const { app, firestore } = buildApp();
    const token = getValidToken();

    firestore.getPetById.mockResolvedValue(null);

    const res = await request(app)
      .post('/api/hatch/does-not-exist')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(404);
  });

  it('returns 401 when JWT is missing', async () => {
    const { app } = buildApp();
    const res = await request(app)
      .post('/api/hatch/test-id')
      .send({});
    expect(res.status).toBe(401);
  });
});
