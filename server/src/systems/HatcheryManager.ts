import { v4 as uuidv4 } from 'uuid';
import { Pet } from '../models/Pet';
import { PetState } from '../models/BasePet';
import { DNADecoder } from './DNADecoder';
import { MemoryStore } from '../store/MemoryStore';
import { FirestoreService } from '../services/FirestoreService';

const HATCH_DURATION_MS = 30_000; // 30 seconds for MVP; tune per rarity later

/**
 * HatcheryManager — Orchestrates the complete pet lifecycle
 * 
 * Responsibilities:
 *   1. Generate random creatures (eggs) with unique DNA
 *   2. Validate ownership before hatching or retrieving pets
 *   3. Enforce hatch timer expiration (you can't hatch too early)
 *   4. Persist all changes to Firestore (or MemoryStore for testing)
 * 
 * Error Handling:
 *   All domain errors are thrown as HatcheryError(status, message).
 *   The Express middleware in petRoutes.ts catches these and returns
 *   typed HTTP responses (404, 403, 409, etc.).
 * 
 * Data Flow Example:
 *   Client POST /api/spawn-egg with JWT { userId: 'user123' }
 *     → HatcheryManager.spawnEgg('user123')
 *     → Create UUID, generate 24-hex DNA, decode to traits
 *     → Create Pet object with hatchTime = now + 30s
 *     → FirestoreService.savePet(userId, pet)
 *     → Return Pet to client
 */
export class HatcheryManager {
  constructor(
    private readonly memoryStore: MemoryStore,
    private readonly firestoreService: FirestoreService,
  ) {}

  /**
   * Spawn a new egg with random DNA and hatch timer.
   * 
   * Process:
   *   1. Generate unique ID (UUID v4)
   *   2. Generate random 24-char hex DNA string (00000000000000000000000000)
   *   3. Decode DNA deterministically to get creature attributes (color, rarity, etc.)
   *   4. Set hatchTime to (now + 30 seconds)
   *   5. Create Pet object and persist to Firestore
   * 
   * Returns: New Pet object in EGG state, not yet hatched.
   * 
   * Tip: The DNA is deterministic. The same DNA always produces the same creature.
   *      This is important for fairness and reproducibility in PvP/PvE battles.
   */
  async spawnEgg(userId: string): Promise<Pet> {
    const id = uuidv4();
    const dna = DNADecoder.generateDNA();
    const attributes = DNADecoder.decode(dna);
    const hatchTime = Date.now() + HATCH_DURATION_MS;
    const pet = new Pet(id, dna, hatchTime, userId, attributes);
    
    await this.firestoreService.savePet(userId, pet);
    this.memoryStore.save(pet); // Keep in-memory copy for quick access
    return pet;
  }

  /**
   * Retrieve all pets owned by a user.
   * 
   * This is called by the client to populate the pet list.
   * Fetches from Firestore for persistent storage.
   * Note: No pagination yet — all pets are returned. This could be slow with
   *       many pets in production (consider adding limit/offset).
   */
  async getInventory(userId: string): Promise<any[]> {
    return this.firestoreService.getPetsForUser(userId);
  }

  /**
   * Transition an egg to hatched state (reveals creature attributes).
   * 
   * Validation:
   *   1. Pet must exist (404 if not found)
   *   2. Pet state must be EGG (409 if already hatched)
   *   3. hatchTime must have passed (error if not ready)
   * 
   * Process:
   *   1. Fetch pet from Firestore
   *   2. Verify state (must be EGG)
   *   3. Verify hatchTime has passed
   *   4. Update state to HATCHED with hatchedAt timestamp
   *   5. Persist updated pet to Firestore
   * 
   * Returns: Hatched pet object with updated state and hatchedAt timestamp
   * 
   * Security: Firestore security rules (future) will prevent cross-user access
   */
  async hatchEgg(id: string, requestingUserId: string): Promise<any> {
    const pet = await this.firestoreService.getPetById(requestingUserId, id);
    if (!pet) throw new HatcheryError(404, 'Egg not found.');
    
    // Check if already hatched
    if (pet.state === PetState.HATCHED) {
      throw new HatcheryError(409, 'Already hatched.');
    }

    // Check if ready to hatch
    if (Date.now() < pet.hatchTime) {
      const secs = Math.ceil((pet.hatchTime - Date.now()) / 1000);
      throw new HatcheryError(409, `Not ready to hatch. ${secs}s remaining.`);
    }

    // Update pet state in Firestore
    const hatchedAt = Date.now();
    await this.firestoreService.updatePet(requestingUserId, id, {
      state: PetState.HATCHED,
      hatchedAt,
      name: `Likha #${id.slice(0, 6).toUpperCase()}`,
    });

    // Return updated pet
    return {
      ...pet,
      state: PetState.HATCHED,
      hatchedAt,
      name: `Likha #${id.slice(0, 6).toUpperCase()}`,
    };
  }
}

/**
 * HatcheryError — Custom error class for domain-level pet operations.
 * 
 * Usage:
 *   throw new HatcheryError(404, 'Egg not found.');
 *   throw new HatcheryError(403, 'Ownership mismatch.');
 * 
 * The status code is used by the Express error middleware to return
 * the correct HTTP status (404 Not Found, 403 Forbidden, etc.).
 * 
 * This separation keeps domain logic independent of HTTP concerns.
 */
export class HatcheryError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
    this.name = 'HatcheryError';
  }
}
