import { Pet } from '../models/Pet';
import { User } from '../models/User';

export class MemoryStore {
  private readonly pets = new Map<string, Pet>();
  private readonly users = new Map<string, User>();

  // ========== PET OPERATIONS ==========

  save(pet: Pet): void {
    this.pets.set(pet.id, pet);
  }

  findById(id: string): Pet | undefined {
    return this.pets.get(id);
  }

  findByOwner(owner: string): Pet[] {
    return [...this.pets.values()].filter(p => p.owner === owner);
  }

  delete(id: string): boolean {
    return this.pets.delete(id);
  }

  // ========== USER OPERATIONS ==========

  /**
   * Save a user to the store
   */
  saveUser(user: User): void {
    this.users.set(user.userId, user);
  }

  /**
   * Find user by ID
   */
  findUserById(userId: string): User | undefined {
    return this.users.get(userId);
  }

  /**
   * Find user by email (for login)
   */
  findUserByEmail(email: string): User | undefined {
    return [...this.users.values()].find(u => u.email === email);
  }

  /**
   * Check if email is already registered
   */
  emailExists(email: string): boolean {
    return this.findUserByEmail(email) !== undefined;
  }
}
