import { v4 as uuidv4 } from 'uuid';
import { Pet } from '../models/Pet';
import { PetState } from '../models/BasePet';
import { DNADecoder } from './DNADecoder';
import { MemoryStore } from '../store/MemoryStore';

const HATCH_DURATION_MS = 30_000; // 30 seconds for MVP; tune per rarity later

/**
 * HatcheryManager — Orchestrates the complete pet lifecycle
 * 
 * Responsibilities:
 *   1. Generate random creatures (eggs) with unique DNA
 *   2. Validate ownership before hatching or retrieving pets
 *   3. Enforce hatch timer expiration (you can't hatch too early)
 *   4. Persist all changes to the store
 * 
 * Error Handling:
 *   All domain errors are thrown as HatcheryError(status, message).
 *   The Express middleware in petRoutes.ts catches these and returns
 *   typed HTTP responses (404, 403, 409, etc.).
 * 
 * Data Flow Example:
 *   Client POST /api/spawn-egg { owner: 'player1' }
 *     → HatcheryManager.spawnEgg('player1')
 *     → Create UUID, generate 24-hex DNA, decode to traits
 *     → Create Pet object with hatchTime = now + 30s
 *     → MemoryStore.save(pet)
 *     → Return Pet to client
 */
export class HatcheryManager {
  constructor(private readonly store: MemoryStore) {}

  /**
   * Spawn a new egg with random DNA and hatch timer.
   * 
   * Process:
   *   1. Generate unique ID (UUID v4)
   *   2. Generate random 24-char hex DNA string (00000000000000000000000000)
   *   3. Decode DNA deterministically to get creature attributes (color, rarity, etc.)
   *   4. Set hatchTime to (now + 30 seconds)
   *   5. Create Pet object and persist to store
   * 
   * Returns: New Pet object in EGG state, not yet hatched.
   * 
   * Tip: The DNA is deterministic. The same DNA always produces the same creature.
   *      This is important for fairness and reproducibility in PvP/PvE battles.
   */
  spawnEgg(owner: string): Pet {
    const id = uuidv4();
    const dna = DNADecoder.generateDNA();
    const attributes = DNADecoder.decode(dna);
    const hatchTime = Date.now() + HATCH_DURATION_MS;
    const pet = new Pet(id, dna, hatchTime, owner, attributes);
    this.store.save(pet);
    return pet;
  }

  /**
   * Retrieve all pets owned by a player.
   * 
   * This is called by the client to populate the pet list (Phaser HatcheryScene).
   * Note: No pagination yet — all pets are returned. This could be slow with
   *       many pets in production (consider adding limit/offset).
   */
  getInventory(owner: string): Pet[] {
    return this.store.findByOwner(owner);
  }

  /**
   * Transition an egg to hatched state (reveals creature attributes).
   * 
   * Validation:
   *   1. Pet must exist (404 if not found)
   *   2. Owner must match requestingOwner (403 if mismatch)
   *   3. Egg must not already be hatched (409 if already hatched)
   *   4. hatchTime must have passed (error from Pet.hatch())
   * 
   * Process:
   *   1. Fetch pet from store
   *   2. Verify ownership & state
   *   3. Call Pet.hatch() which:
   *      - Checks hatchTime expiration
   *      - Updates state to HATCHED
   *      - Sets hatchedAt = Date.now()
   *      - Generates auto pet name (Likha #XXXXXX)
   *   4. Persist updated pet to store
   * 
   * Returns: Fully hatched Pet object with name and hatchedAt timestamp.
   * 
   * Security: Ownership check prevents players from hatching others' eggs.
   */
  hatchEgg(id: string, requestingOwner: string): Pet {
    const pet = this.store.findById(id);
    if (!pet) throw new HatcheryError(404, 'Egg not found.');
    if (pet.owner !== requestingOwner) throw new HatcheryError(403, 'This egg does not belong to you.');
    if (pet.state === PetState.HATCHED) throw new HatcheryError(409, 'Already hatched.');

    pet.hatch(); // throws its own message if timer isn't up
    this.store.save(pet);
    return pet;
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
