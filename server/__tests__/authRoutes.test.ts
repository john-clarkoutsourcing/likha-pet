import { FirestoreService } from '../src/services/FirestoreService';
import { createAuthRoutes } from '../src/routes/authRoutes';
import express, { Express } from 'express';
import request from 'supertest';
import bcrypt from 'bcryptjs';

// Mock Firestore
jest.mock('../src/services/FirestoreService');

describe('Auth Routes', () => {
  let app: Express;
  let firestore: jest.Mocked<FirestoreService>;

  beforeEach(() => {
    app = express();
    app.use(express.json());
    firestore = new FirestoreService() as jest.Mocked<FirestoreService>;
    firestore.saveUser = jest.fn().mockResolvedValue(undefined);
    firestore.emailExists = jest.fn().mockResolvedValue(false);
    firestore.findUserByEmail = jest.fn();
    app.use('/api/auth', createAuthRoutes(firestore));
  });

  describe('POST /api/auth/register', () => {
    it('should register a new user successfully', async () => {
      firestore.emailExists.mockResolvedValue(false);

      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'test@example.com',
          password: 'password123',
        });

      expect(response.status).toBe(201);
      expect(response.body.userId).toBeDefined();
      expect(response.body.token).toBeDefined();
      expect(response.body.email).toBe('test@example.com');
    });

    it('should reject duplicate email', async () => {
      firestore.emailExists.mockResolvedValue(true);

      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'test@example.com',
          password: 'password456',
        });

      expect(response.status).toBe(409);
      expect(response.body.error).toContain('already registered');
    });

    it('should reject invalid email', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'notanemail',
          password: 'password123',
        });

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('Invalid email');
    });

    it('should reject short password', async () => {
      const response = await request(app)
        .post('/api/auth/register')
        .send({
          email: 'test@example.com',
          password: 'pass',
        });

      expect(response.status).toBe(400);
      expect(response.body.error).toContain('at least 6 characters');
    });
  });

  describe('POST /api/auth/login', () => {
    beforeEach(async () => {
      const hashedPassword = await bcrypt.hash('password123', 10);
      firestore.findUserByEmail.mockResolvedValue({
        userId: 'test-user-id',
        email: 'test@example.com',
        passwordHash: hashedPassword,
        createdAt: Date.now(),
      });
    });

    it('should login successfully with correct credentials', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'password123',
        });

      expect(response.status).toBe(200);
      expect(response.body.userId).toBeDefined();
      expect(response.body.token).toBeDefined();
      expect(response.body.email).toBe('test@example.com');
    });

    it('should reject incorrect password', async () => {
      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'wrongpassword',
        });

      expect(response.status).toBe(401);
      expect(response.body.error).toContain('Invalid email or password');
    });

    it('should reject nonexistent email', async () => {
      firestore.findUserByEmail.mockResolvedValue(null);

      const response = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'nonexistent@example.com',
          password: 'password123',
        });

      expect(response.status).toBe(401);
      expect(response.body.error).toContain('Invalid email or password');
    });
  });
});
