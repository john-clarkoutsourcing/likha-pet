/**
 * User model for authentication
 */
export interface User {
  userId: string;        // UUID
  email: string;         // Unique email
  passwordHash: string;  // bcrypt hash of password
  createdAt: number;     // timestamp in ms
}

/**
 * Request body for registration
 */
export interface RegisterRequest {
  email: string;
  password: string;
}

/**
 * Request body for login
 */
export interface LoginRequest {
  email: string;
  password: string;
}

/**
 * Response after successful auth
 */
export interface AuthResponse {
  userId: string;
  token: string;  // JWT token
  email: string;
}

/**
 * JWT payload (what's inside the token)
 */
export interface JWTPayload {
  userId: string;
  email: string;
  iat: number;  // issued at
  exp: number;  // expires at
}
