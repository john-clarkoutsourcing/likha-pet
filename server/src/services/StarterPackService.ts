import { DNADecoder } from '../systems/DNADecoder';
import { FirestoreService } from './FirestoreService';
import { v4 as uuidv4 } from 'uuid';

/**
 * StarterPackService
 * 
 * Provides starter pack functionality for new players.
 * Creates 3 eggs with random DNA that are ready to hatch immediately.
 */
export class StarterPackService {
  private firestoreService: FirestoreService;

  constructor(firestoreService: FirestoreService) {
    this.firestoreService = firestoreService;
  }

  /**
   * Create starter pack for a new player
   * 
   * Generates 3 eggs with random DNA and immediate hatch times.
   * All eggs are automatically ready to hatch (hatchTime = now).
   * 
   * @param userId - The user ID for the new player
   * @returns Array of 3 pet objects (eggs)
   */
  async createStarterPack(userId: string): Promise<any[]> {
    const now = Date.now();
    const eggs = [];

    // Create 3 eggs with random DNA
    for (let i = 0; i < 3; i++) {
      const petId = uuidv4();
      const dna = DNADecoder.generateDNA();
      const attributes = DNADecoder.decode(dna);

      const pet = {
        id: petId,
        dna,
        state: 'Egg',
        hatchTime: now, // Immediate hatch - ready now
        owner: userId,
        createdAt: now,
        name: `Likha #${petId.slice(0, 6).toUpperCase()}`,
        attributes,
      };

      // Save to Firestore
      await this.firestoreService.savePet(userId, pet);
      eggs.push(pet);
    }

    return eggs;
  }

  /**
   * Check if user has starter pack (has exactly 3 hatched eggs)
   * Used to determine if user is new or has already claimed starter pack
   */
  async hasClaimedStarterPack(userId: string): Promise<boolean> {
    const pets = await this.firestoreService.getPetsForUser(userId);
    return pets && pets.length > 0;
  }
}
