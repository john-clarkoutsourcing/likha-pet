/**
 * Task 1.6: API Integration Verification Tests
 * 
 * These tests verify that the Flutter app can successfully:
 * 1. Register users and get JWT tokens
 * 2. Login and receive JWT tokens
 * 3. Call protected routes with JWT tokens
 * 4. Handle errors correctly
 * 5. Token persistence (simulated)
 */

import request from 'supertest';
import express, { Application } from 'express';
import cors from 'cors';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { FirestoreService } from '../src/services/FirestoreService';
import { HatcheryManager, HatcheryError } from '../src/systems/HatcheryManager';
import { createAuthRoutes } from '../src/routes/authRoutes';
import { createPetRouter } from '../src/routes/petRoutes';
import { verifyAuth } from '../src/middleware/auth';
import { MemoryStore } from '../src/store/MemoryStore';

// Mock Firestore for testing
jest.mock('../src/services/FirestoreService');

const JWT_SECRET = 'your-secret-key-change-in-production';

describe('Task 1.6: API Integration Verification - Flutter ↔ Server', () => {
  let app: Application;
  let firestore: jest.Mocked<FirestoreService>;
  let hatchery: HatcheryManager;
  let testUserId: string;
  let testToken: string;
  let testEmail: string;

  beforeEach(() => {
    // Create Express app
    app = express();
    app.use(cors());
    app.use(express.json());

    // Mock Firestore
    firestore = new FirestoreService() as jest.Mocked<FirestoreService>;
    firestore.saveUser = jest.fn().mockResolvedValue(undefined);
    firestore.findUserByEmail = jest.fn();
    firestore.emailExists = jest.fn();
    firestore.savePet = jest.fn().mockResolvedValue(undefined);
    firestore.getPetsForUser = jest.fn().mockResolvedValue([]);
    firestore.getPetById = jest.fn();
    firestore.updatePet = jest.fn().mockResolvedValue(undefined);

    // Setup routes
    const store = new MemoryStore();
    hatchery = new HatcheryManager(store, firestore);

    app.use('/api/auth', createAuthRoutes(firestore));
    app.use('/api', createPetRouter(hatchery));

    // Health check
    app.get('/health', (_req, res) => res.json({ status: 'ok' }));

    // Test data
    testUserId = uuidv4();
    testEmail = `user-${Date.now()}@example.com`;
    testToken = jwt.sign({ userId: testUserId, email: testEmail }, JWT_SECRET, {
      expiresIn: '24h',
    });
  });

  describe('1️⃣ Register Flow (Flutter → Server → Firestore)', () => {
    it('should allow user registration with valid email and password', async () => {
      firestore.emailExists = jest.fn().mockResolvedValue(false);
      firestore.saveUser = jest.fn().mockResolvedValue(undefined);

      const response = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .send({
          email: 'newuser@example.com',
          password: 'password123',
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('userId');
      expect(response.body).toHaveProperty('token');
      expect(response.body.email).toBe('newuser@example.com');
      expect(firestore.saveUser).toHaveBeenCalled();
    });

    it('should reject registration with invalid email format', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .send({
          email: 'not-an-email',
          password: 'password123',
        });

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('email');
    });

    it('should reject registration with short password', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .send({
          email: 'user@example.com',
          password: 'short',
        });

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('Password must be at least 6 characters');
    });

    it('should create starter pack (3 eggs) after successful registration', async () => {
      firestore.emailExists = jest.fn().mockResolvedValue(false);
      firestore.saveUser = jest.fn().mockResolvedValue(undefined);
      firestore.savePet = jest.fn().mockResolvedValue(undefined);

      const response = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .send({
          email: 'starter@example.com',
          password: 'password123',
        });

      expect(response.status).toBe(201);
      expect(firestore.savePet).toHaveBeenCalledTimes(3);

      // Verify all 3 pets are eggs ready to hatch
      const calls = (firestore.savePet as jest.Mock).mock.calls;
      calls.forEach(([userId, pet]) => {
        expect(userId).toBe(response.body.userId);
        expect(pet.state).toBe('Egg');
        expect(pet.dna).toMatch(/^[0-9a-f]{24}$/);
        expect(pet.hatchTime).toBeLessThanOrEqual(Date.now() + 100); // Ready to hatch
        expect(pet.attributes).toBeDefined();
        expect(pet.name).toMatch(/^Likha #[A-F0-9]{6}$/);
      });
    });

    it('should register user and immediately have 3 pets available', async () => {
      const newUserId = uuidv4();
      firestore.emailExists = jest.fn().mockResolvedValue(false);
      firestore.saveUser = jest.fn().mockResolvedValue(undefined);
      firestore.savePet = jest.fn().mockResolvedValue(undefined);

      const registerResponse = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .send({
          email: 'quickstart@example.com',
          password: 'password123',
        });

      expect(registerResponse.status).toBe(201);
      const userId = registerResponse.body.userId;

      // Mock that this user now has 3 pets
      const mockPets: any[] = [];
      const calls = (firestore.savePet as jest.Mock).mock.calls;
      calls.forEach(([callUserId, pet]) => {
        if (callUserId === userId) {
          mockPets.push(pet);
        }
      });

      firestore.getPetsForUser = jest.fn().mockResolvedValue(mockPets);

      // Verify inventory has 3 eggs
      const inventoryResponse = await request(app)
        .get('/api/inventory')
        .set('Authorization', `Bearer ${registerResponse.body.token}`);

      expect(inventoryResponse.status).toBe(200);
      expect(inventoryResponse.body).toHaveLength(3);
    });

    it('should reject duplicate email registration', async () => {
      firestore.emailExists = jest.fn().mockResolvedValue(true);

      const response = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .send({
          email: 'existing@example.com',
          password: 'password123',
        });

      expect(response.status).toBe(409);
      expect(response.body.error).toContain('already registered');
    });

    it('should return JWT token with userId and email claims', async () => {
      firestore.emailExists = jest.fn().mockResolvedValue(false);

      const response = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .send({
          email: 'newuser@example.com',
          password: 'password123',
        });

      // Decode and verify JWT
      const token = response.body.token;
      const decoded = jwt.verify(token, JWT_SECRET) as any;
      expect(decoded.email).toBe('newuser@example.com');
      expect(decoded.userId).toBeDefined();
    });
  });

  describe('2️⃣ Login Flow (Flutter → Server)', () => {
    beforeEach(async () => {
      const hashedPassword = await bcrypt.hash('password123', 10);
      firestore.findUserByEmail = jest.fn().mockResolvedValue({
        userId: testUserId,
        email: testEmail,
        passwordHash: hashedPassword,
        createdAt: Date.now(),
      });
    });

    it('should allow user login with correct credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .set('Content-Type', 'application/json')
        .send({
          email: testEmail,
          password: 'password123',
        });

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('userId');
      expect(response.body).toHaveProperty('token');
      expect(response.body.email).toBe(testEmail);
    });

    it('should reject login with incorrect password', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .set('Content-Type', 'application/json')
        .send({
          email: testEmail,
          password: 'wrongpassword',
        });

      expect(response.status).toBe(401);
      expect(response.body.error).toContain('Invalid email or password');
    });

    it('should reject login with unregistered email', async () => {
      firestore.findUserByEmail = jest.fn().mockResolvedValue(null);

      const response = await request(app)
        .post('/api/auth/login')
        .set('Content-Type', 'application/json')
        .send({
          email: 'nonexistent@example.com',
          password: 'password123',
        });

      expect(response.status).toBe(401);
      expect(response.body.error).toContain('Invalid email or password');
    });

    it('should return valid JWT token', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .set('Content-Type', 'application/json')
        .send({
          email: testEmail,
          password: 'password123',
        });

      const token = response.body.token;
      const decoded = jwt.verify(token, JWT_SECRET) as any;
      expect(decoded.userId).toBe(testUserId);
      expect(decoded.email).toBe(testEmail);
    });
  });

  describe('3️⃣ Protected Routes (Flutter sends JWT)', () => {
    it('should allow spawn-egg with valid JWT', async () => {
      firestore.savePet = jest.fn().mockResolvedValue(undefined);

      const response = await request(app)
        .post('/api/spawn-egg')
        .set('Authorization', `Bearer ${testToken}`)
        .set('Content-Type', 'application/json')
        .send({});

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('dna');
      expect(response.body.state).toBe('Egg');
      expect(firestore.savePet).toHaveBeenCalled();
    });

    it('should reject spawn-egg without JWT', async () => {
      const response = await request(app)
        .post('/api/spawn-egg')
        .set('Content-Type', 'application/json')
        .send({});

      expect(response.status).toBe(401);
      expect(response.body.error).toContain('authorization');
    });

    it('should reject spawn-egg with invalid JWT', async () => {
      const response = await request(app)
        .post('/api/spawn-egg')
        .set('Authorization', 'Bearer invalid.token.here')
        .set('Content-Type', 'application/json')
        .send({});

      expect(response.status).toBe(401);
    });

    it('should allow inventory with valid JWT', async () => {
      firestore.getPetsForUser = jest.fn().mockResolvedValue([
        {
          id: 'pet-1',
          dna: '123456789abcdef',
          state: 'Egg',
          hatchTime: Date.now() + 30000,
          createdAt: Date.now(),
        },
      ]);

      const response = await request(app)
        .get('/api/inventory')
        .set('Authorization', `Bearer ${testToken}`)
        .set('Content-Type', 'application/json');

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBe(1);
      expect(response.body[0].id).toBe('pet-1');
    });

    it('should reject inventory without JWT', async () => {
      const response = await request(app)
        .get('/api/inventory')
        .set('Content-Type', 'application/json');

      expect(response.status).toBe(401);
    });
  });

  describe('4️⃣ Token Persistence (Flutter Secure Storage Simulation)', () => {
    it('should allow multiple requests with same token', async () => {
      firestore.savePet = jest.fn().mockResolvedValue(undefined);
      firestore.getPetsForUser = jest.fn().mockResolvedValue([]);

      // First request
      const spawn1 = await request(app)
        .post('/api/spawn-egg')
        .set('Authorization', `Bearer ${testToken}`);

      expect(spawn1.status).toBe(201);

      // Second request with same token (simulating app restart)
      const spawn2 = await request(app)
        .post('/api/spawn-egg')
        .set('Authorization', `Bearer ${testToken}`);

      expect(spawn2.status).toBe(201);

      // Token should still work for inventory
      const inventory = await request(app)
        .get('/api/inventory')
        .set('Authorization', `Bearer ${testToken}`);

      expect(inventory.status).toBe(200);
    });

    it('should extract userId from JWT and scope operations', async () => {
      const differentUserId = uuidv4();
      const differentToken = jwt.sign(
        { userId: differentUserId, email: 'other@example.com' },
        JWT_SECRET,
        { expiresIn: '24h' }
      );

      firestore.savePet = jest.fn().mockResolvedValue(undefined);

      // Two different users spawn eggs
      const user1Response = await request(app)
        .post('/api/spawn-egg')
        .set('Authorization', `Bearer ${testToken}`);

      const user2Response = await request(app)
        .post('/api/spawn-egg')
        .set('Authorization', `Bearer ${differentToken}`);

      // Both should succeed
      expect(user1Response.status).toBe(201);
      expect(user2Response.status).toBe(201);

      // Verify savePet was called with correct userIds
      expect(firestore.savePet).toHaveBeenCalledTimes(2);

      // Get first call arguments
      const firstCall = (firestore.savePet as jest.Mock).mock.calls[0];
      const secondCall = (firestore.savePet as jest.Mock).mock.calls[1];

      expect(firstCall[0]).toBe(testUserId);
      expect(secondCall[0]).toBe(differentUserId);
    });
  });

  describe('5️⃣ Error Handling (Flutter UI should show errors)', () => {
    it('should return structured error responses', async () => {
      firestore.emailExists = jest.fn().mockResolvedValue(true);

      const response = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .send({
          email: 'existing@example.com',
          password: 'password123',
        });

      expect(response.body).toHaveProperty('error');
      expect(typeof response.body.error).toBe('string');
    });

    it('should handle missing request body gracefully', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .send({});

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
    });

    it('should handle server errors gracefully', async () => {
      firestore.emailExists = jest
        .fn()
        .mockRejectedValue(new Error('Database error'));

      const response = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .send({
          email: 'user@example.com',
          password: 'password123',
        });

      expect(response.status).toBe(500);
      expect(response.body).toHaveProperty('error');
    });
  });

  describe('6️⃣ Full End-to-End Scenario (Register → Spawn → Inventory)', () => {
    it('should complete full user journey', async () => {
      firestore.emailExists = jest.fn().mockResolvedValue(false);
      firestore.saveUser = jest.fn().mockResolvedValue(undefined);
      firestore.savePet = jest.fn().mockResolvedValue(undefined);
      firestore.getPetsForUser = jest.fn().mockResolvedValue([]);

      // Step 1: Register
      const registerRes = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .send({
          email: 'newuser@example.com',
          password: 'password123',
        });

      expect(registerRes.status).toBe(201);
      const token = registerRes.body.token;
      const userId = registerRes.body.userId;

      // Step 2: Spawn egg with token
      const spawnRes = await request(app)
        .post('/api/spawn-egg')
        .set('Authorization', `Bearer ${token}`)
        .set('Content-Type', 'application/json')
        .send({});

      expect(spawnRes.status).toBe(201);
      expect(spawnRes.body.state).toBe('Egg');

      // Step 3: Get inventory with same token
      firestore.getPetsForUser = jest.fn().mockResolvedValue([spawnRes.body]);

      const inventoryRes = await request(app)
        .get('/api/inventory')
        .set('Authorization', `Bearer ${token}`)
        .set('Content-Type', 'application/json');

      expect(inventoryRes.status).toBe(200);
      expect(inventoryRes.body.length).toBeGreaterThan(0);
    });
  });

  describe('7️⃣ CORS Support (Flutter Web Browser)', () => {
    it('should include CORS headers in responses', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .set('Content-Type', 'application/json')
        .set('Origin', 'http://localhost:8080')
        .send({
          email: 'user@example.com',
          password: 'password123',
        });

      // CORS headers should be present (handled by cors middleware)
      expect(response.headers['access-control-allow-origin']).toBeDefined();
    });
  });
});
