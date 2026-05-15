import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { JWTPayload } from '../models/User';

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

/**
 * Extend Express Request to include user info after auth
 */
declare global {
  namespace Express {
    interface Request {
      userId?: string;
      email?: string;
    }
  }
}

/**
 * JWT Verification Middleware
 * 
 * Usage:
 *   app.use('/api/protected', verifyAuth, protectedRoutes);
 * 
 * This middleware:
 *   1. Extracts JWT token from Authorization header (Bearer <token>)
 *   2. Verifies the JWT signature
 *   3. Checks if token has expired
 *   4. Attaches userId + email to req object for downstream routes
 *   5. Returns 401 Unauthorized if token is missing or invalid
 * 
 * Client Usage:
 *   // After login, store token in secure storage
 *   const token = response.body.token;
 *   
 *   // On subsequent requests, send token in header
 *   fetch('/api/spawn-egg', {
 *     headers: { Authorization: `Bearer ${token}` }
 *   });
 */
export function verifyAuth(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  try {
    // Extract token from "Authorization: Bearer <token>"
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Missing or invalid authorization header' });
      return;
    }

    const token = authHeader.substring('Bearer '.length);

    // Verify JWT signature and expiration
    const payload = jwt.verify(token, JWT_SECRET) as JWTPayload;

    // Attach user info to request for downstream handlers
    req.userId = payload.userId;
    req.email = payload.email;

    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      res.status(401).json({ error: 'Token expired' });
    } else if (error instanceof jwt.JsonWebTokenError) {
      res.status(401).json({ error: 'Invalid token' });
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
}

/**
 * Optional Auth Middleware
 * 
 * Like verifyAuth, but doesn't reject if token is missing.
 * Useful for endpoints that work with or without auth.
 * 
 * Usage:
 *   app.use('/api/public', optionalAuth, publicRoutes);
 */
export function optionalAuth(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring('Bearer '.length);
      const payload = jwt.verify(token, JWT_SECRET) as JWTPayload;
      req.userId = payload.userId;
      req.email = payload.email;
    }
    next();
  } catch (error) {
    // Silently ignore auth errors and continue
    next();
  }
}
