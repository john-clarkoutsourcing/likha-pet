import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { MemoryStore } from '../store/MemoryStore';
import { HatcheryError } from '../systems/HatcheryManager';
import { User, RegisterRequest, LoginRequest, AuthResponse } from '../models/User';

/**
 * Create auth routes
 * @param store MemoryStore instance for user persistence
 */
export function createAuthRoutes(store: MemoryStore): Router {
  const router = Router();

  /**
   * POST /api/auth/register
   * Register a new user with email + password
   */
  router.post('/register', async (req: Request, res: Response) => {
    try {
      const { email, password } = req.body as RegisterRequest;

      // Validate input
      if (!email || !password) {
        throw new HatcheryError(400, 'Email and password are required');
      }

      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw new HatcheryError(400, 'Invalid email format');
      }

      if (password.length < 6) {
        throw new HatcheryError(400, 'Password must be at least 6 characters');
      }

      // Check if email already registered
      if (store.emailExists(email)) {
        throw new HatcheryError(409, 'Email already registered');
      }

      // Hash password with bcrypt
      const passwordHash = await bcrypt.hash(password, 10);

      // Create user
      const userId = uuidv4();
      const user: User = {
        userId,
        email,
        passwordHash,
        createdAt: Date.now(),
      };

      // Save user
      store.saveUser(user);

      // Create JWT token
      const token = jwt.sign(
        { userId, email } as any,
        JWT_SECRET,
        { expiresIn: TOKEN_EXPIRY }
      );

      // Return response
      res.status(201).json({
        userId,
        token,
        email,
      } as AuthResponse);
    } catch (error) {
      if (error instanceof HatcheryError) {
        res.status(error.status).json({ error: error.message });
      } else {
        res.status(500).json({ error: 'Internal server error' });
      }
    }
  });

  /**
   * POST /api/auth/login
   * Login with email + password
   */
  router.post('/login', async (req: Request, res: Response) => {
    try {
      const { email, password } = req.body as LoginRequest;

      // Validate input
      if (!email || !password) {
        throw new HatcheryError(400, 'Email and password are required');
      }

      // Find user by email
      const user = store.findUserByEmail(email);
      if (!user) {
        throw new HatcheryError(401, 'Invalid email or password');
      }

      // Compare password hash
      const passwordMatch = await bcrypt.compare(password, user.passwordHash);
      if (!passwordMatch) {
        throw new HatcheryError(401, 'Invalid email or password');
      }

      // Create JWT token
      const token = jwt.sign(
        { userId: user.userId, email: user.email } as any,
        JWT_SECRET,
        { expiresIn: TOKEN_EXPIRY }
      );

      // Return response
      res.status(200).json({
        userId: user.userId,
        token,
        email: user.email,
      } as AuthResponse);
    } catch (error) {
      if (error instanceof HatcheryError) {
        res.status(error.status).json({ error: error.message });
      } else {
        res.status(500).json({ error: 'Internal server error' });
      }
    }
  });

  return router;
}
