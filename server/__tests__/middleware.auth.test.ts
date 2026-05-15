import { verifyAuth, optionalAuth } from '../src/middleware/auth';
import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';

const JWT_SECRET = 'test-secret-key';
const TEST_USER_ID = 'user-123';
const TEST_EMAIL = 'test@example.com';

describe('JWT Middleware', () => {
  describe('verifyAuth', () => {
    it('should attach userId and email to request when valid token provided', () => {
      // Create a valid JWT token
      const token = jwt.sign(
        { userId: TEST_USER_ID, email: TEST_EMAIL },
        JWT_SECRET,
        { expiresIn: '24h' }
      );

      const req = {
        headers: { authorization: `Bearer ${token}` },
      } as unknown as Request;
      
      const res = {} as Response;
      const next = jest.fn();

      // Mock jwt.verify to use our test secret
      jest.spyOn(jwt, 'verify').mockReturnValue({
        userId: TEST_USER_ID,
        email: TEST_EMAIL,
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 86400,
      } as any);

      verifyAuth(req, res, next);

      expect(req.userId).toBe(TEST_USER_ID);
      expect(req.email).toBe(TEST_EMAIL);
      expect(next).toHaveBeenCalled();

      jest.restoreAllMocks();
    });

    it('should return 401 when no authorization header provided', () => {
      const req = {
        headers: {},
      } as unknown as Request;
      
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      } as unknown as Response;
      const next = jest.fn();

      verifyAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.any(String) })
      );
      expect(next).not.toHaveBeenCalled();
    });

    it('should return 401 when invalid token format provided', () => {
      const req = {
        headers: { authorization: 'InvalidFormat token' },
      } as unknown as Request;
      
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      } as unknown as Response;
      const next = jest.fn();

      verifyAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(next).not.toHaveBeenCalled();
    });

    it('should return 401 when token is expired', () => {
      const req = {
        headers: { authorization: 'Bearer expired.token.here' },
      } as unknown as Request;
      
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      } as unknown as Response;
      const next = jest.fn();

      // Mock jwt.verify to throw TokenExpiredError
      jest.spyOn(jwt, 'verify').mockImplementation(() => {
        throw new jwt.TokenExpiredError('Token expired', new Date());
      });

      verifyAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: 'Token expired' })
      );

      jest.restoreAllMocks();
    });

    it('should return 401 when token is invalid', () => {
      const req = {
        headers: { authorization: 'Bearer invalid.token.here' },
      } as unknown as Request;
      
      const res = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      } as unknown as Response;
      const next = jest.fn();

      // Mock jwt.verify to throw JsonWebTokenError
      jest.spyOn(jwt, 'verify').mockImplementation(() => {
        throw new jwt.JsonWebTokenError('Invalid token');
      });

      verifyAuth(req, res, next);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: 'Invalid token' })
      );

      jest.restoreAllMocks();
    });
  });

  describe('optionalAuth', () => {
    it('should attach userId and email when valid token provided', () => {
      const req = {
        headers: { authorization: `Bearer valid.token` },
      } as unknown as Request;
      
      const res = {} as Response;
      const next = jest.fn();

      // Mock jwt.verify to use our test secret
      jest.spyOn(jwt, 'verify').mockReturnValue({
        userId: TEST_USER_ID,
        email: TEST_EMAIL,
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 86400,
      } as any);

      optionalAuth(req, res, next);

      expect(req.userId).toBe(TEST_USER_ID);
      expect(req.email).toBe(TEST_EMAIL);
      expect(next).toHaveBeenCalled();

      jest.restoreAllMocks();
    });

    it('should call next() even when no authorization header provided', () => {
      const req = {
        headers: {},
      } as unknown as Request;
      
      const res = {} as Response;
      const next = jest.fn();

      optionalAuth(req, res, next);

      expect(next).toHaveBeenCalled();
      expect(req.userId).toBeUndefined();
      expect(req.email).toBeUndefined();
    });

    it('should call next() even when token is invalid', () => {
      const req = {
        headers: { authorization: 'Bearer invalid.token' },
      } as unknown as Request;
      
      const res = {} as Response;
      const next = jest.fn();

      // Mock jwt.verify to throw error
      jest.spyOn(jwt, 'verify').mockImplementation(() => {
        throw new jwt.JsonWebTokenError('Invalid token');
      });

      optionalAuth(req, res, next);

      expect(next).toHaveBeenCalled();

      jest.restoreAllMocks();
    });
  });
});
