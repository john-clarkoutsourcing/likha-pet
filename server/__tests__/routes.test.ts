import express from 'express';
import request from 'supertest';
import { MemoryStore } from '../src/store/MemoryStore';
import { HatcheryManager } from '../src/systems/HatcheryManager';
import { createPetRouter } from '../src/routes/petRoutes';
import { PetState } from '../src/models/BasePet';

function buildApp() {
  const app = express();
  app.use(express.json());
  const hatchery = new HatcheryManager(new MemoryStore());
  app.use('/api', createPetRouter(hatchery));
  return app;
}

describe('POST /api/spawn-egg', () => {
  it('returns 201 with a new egg', async () => {
    const res = await request(buildApp())
      .post('/api/spawn-egg')
      .send({ owner: 'tester' });

    expect(res.status).toBe(201);
    expect(res.body.state).toBe(PetState.EGG);
    expect(res.body.owner).toBe('tester');
    expect(res.body.dna).toMatch(/^[0-9a-f]{24}$/);
  });

  it('returns 400 when owner is missing', async () => {
    const res = await request(buildApp()).post('/api/spawn-egg').send({});
    expect(res.status).toBe(400);
  });
});

describe('GET /api/inventory', () => {
  it('returns an empty array for a new owner', async () => {
    const res = await request(buildApp()).get('/api/inventory?owner=nobody');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('returns spawned eggs for the correct owner', async () => {
    const app = buildApp();
    await request(app).post('/api/spawn-egg').send({ owner: 'alice' });
    await request(app).post('/api/spawn-egg').send({ owner: 'alice' });
    await request(app).post('/api/spawn-egg').send({ owner: 'bob' });

    const res = await request(app).get('/api/inventory?owner=alice');
    expect(res.body).toHaveLength(2);
    res.body.forEach((p: { owner: string }) => expect(p.owner).toBe('alice'));
  });

  it('returns 400 when owner param is missing', async () => {
    const res = await request(buildApp()).get('/api/inventory');
    expect(res.status).toBe(400);
  });
});

describe('POST /api/hatch/:id', () => {
  it('returns 409 when egg is not ready yet', async () => {
    const app = buildApp();
    const spawn = await request(app).post('/api/spawn-egg').send({ owner: 'tester' });
    const { id } = spawn.body;

    const res = await request(app)
      .post(`/api/hatch/${id}`)
      .send({ owner: 'tester' });

    expect(res.status).toBe(400); // HatcheryError wraps Pet's error as 400
    expect(res.body.error).toMatch(/not ready/i);
  });

  it('returns 404 for an unknown id', async () => {
    const res = await request(buildApp())
      .post('/api/hatch/does-not-exist')
      .send({ owner: 'tester' });
    expect(res.status).toBe(404);
  });

  it('returns 403 when a different owner tries to hatch', async () => {
    const app = buildApp();
    const spawn = await request(app).post('/api/spawn-egg').send({ owner: 'alice' });
    const res = await request(app)
      .post(`/api/hatch/${spawn.body.id}`)
      .send({ owner: 'eve' });
    expect(res.status).toBe(403);
  });
});
