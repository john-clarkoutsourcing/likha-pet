import * as admin from 'firebase-admin';
import { User } from '../models/User';

interface PetData {
  id: string;
  dna: string;
  name?: string;
  state: 'Egg' | 'Hatched';
  hatchTime: number;
  createdAt: number;
  hatchedAt?: number;
}

/**
 * FirestoreService — Manages database persistence using Firebase Firestore.
 * 
 * Collections:
 *   /users/{userId}                    → User document (email, passwordHash, createdAt)
 *   /users/{userId}/pets/{petId}       → Pet document (dna, name, state, hatchTime, etc.)
 */
export class FirestoreService {
  private db: admin.firestore.Firestore;

  constructor() {
    // When running locally, Firebase emulator is configured via environment variables
    // set by ./run.sh or process.env.FIRESTORE_EMULATOR_HOST
    this.db = admin.firestore();
  }

  // ============================================================================
  // USER OPERATIONS
  // ============================================================================

  /**
   * Save user to Firestore /users/{userId}
   */
  async saveUser(user: User): Promise<void> {
    await this.db.collection('users').doc(user.userId).set({
      email: user.email,
      passwordHash: user.passwordHash,
      createdAt: user.createdAt,
    });
  }

  /**
   * Find user by ID
   */
  async findUserById(userId: string): Promise<User | null> {
    const doc = await this.db.collection('users').doc(userId).get();
    if (!doc.exists) return null;

    const data = doc.data() as any;
    return {
      userId: doc.id,
      email: data.email,
      passwordHash: data.passwordHash,
      createdAt: data.createdAt,
    };
  }

  /**
   * Find user by email
   */
  async findUserByEmail(email: string): Promise<User | null> {
    const query = await this.db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (query.empty) return null;

    const doc = query.docs[0];
    const data = doc.data();
    return {
      userId: doc.id,
      email: data.email,
      passwordHash: data.passwordHash,
      createdAt: data.createdAt,
    };
  }

  /**
   * Check if email exists
   */
  async emailExists(email: string): Promise<boolean> {
    const query = await this.db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();
    return !query.empty;
  }

  // ============================================================================
  // PET OPERATIONS
  // ============================================================================

  /**
   * Save pet to Firestore /users/{userId}/pets/{petId}
   */
  async savePet(userId: string, pet: any): Promise<void> {
    await this.db
      .collection('users')
      .doc(userId)
      .collection('pets')
      .doc(pet.id)
      .set({
        dna: pet.dna,
        name: pet.name,
        state: pet.state,
        hatchTime: pet.hatchTime,
        createdAt: pet.createdAt,
        hatchedAt: pet.hatchedAt || null,
      });
  }

  /**
   * Get all pets for a user
   */
  async getPetsForUser(userId: string): Promise<PetData[]> {
    const snapshot = await this.db
      .collection('users')
      .doc(userId)
      .collection('pets')
      .get();

    return snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        dna: data.dna,
        name: data.name,
        state: data.state,
        hatchTime: data.hatchTime,
        createdAt: data.createdAt,
        hatchedAt: data.hatchedAt,
      } as PetData;
    });
  }

  /**
   * Get pet by ID for a user
   */
  async getPetById(userId: string, petId: string): Promise<PetData | null> {
    const doc = await this.db
      .collection('users')
      .doc(userId)
      .collection('pets')
      .doc(petId)
      .get();

    if (!doc.exists) return null;

    const data = doc.data() as any;
    return {
      id: doc.id,
      dna: data.dna,
      name: data.name,
      state: data.state,
      hatchTime: data.hatchTime,
      createdAt: data.createdAt,
      hatchedAt: data.hatchedAt,
    };
  }

  /**
   * Update pet (e.g., when hatching)
   */
  async updatePet(userId: string, petId: string, updates: Partial<PetData>): Promise<void> {
    const updateData: any = {};
    if (updates.state !== undefined) updateData.state = updates.state;
    if (updates.name !== undefined) updateData.name = updates.name;
    if (updates.hatchedAt !== undefined) updateData.hatchedAt = updates.hatchedAt;

    await this.db
      .collection('users')
      .doc(userId)
      .collection('pets')
      .doc(petId)
      .update(updateData);
  }

  /**
   * Delete pet
   */
  async deletePet(userId: string, petId: string): Promise<void> {
    await this.db
      .collection('users')
      .doc(userId)
      .collection('pets')
      .doc(petId)
      .delete();
  }

  // ============================================================================
  // ADMIN / UTILITY
  // ============================================================================

  /**
   * Clear all data (useful for testing)
   */
  async clearAllData(): Promise<void> {
    const users = await this.db.collection('users').get();
    for (const userDoc of users.docs) {
      const pets = await userDoc.ref.collection('pets').get();
      for (const petDoc of pets.docs) {
        await petDoc.ref.delete();
      }
      await userDoc.ref.delete();
    }
  }
}
