import { v4 as uuidv4 } from 'uuid';
import { Pet } from '../models/Pet';
import { PetState } from '../models/BasePet';
import { DNADecoder } from './DNADecoder';
import { MemoryStore } from '../store/MemoryStore';

const HATCH_DURATION_MS = 30_000; // 30 seconds for MVP; tune per rarity later

export class HatcheryManager {
  constructor(private readonly store: MemoryStore) {}

  spawnEgg(owner: string): Pet {
    const id = uuidv4();
    const dna = DNADecoder.generateDNA();
    const attributes = DNADecoder.decode(dna);
    const hatchTime = Date.now() + HATCH_DURATION_MS;
    const pet = new Pet(id, dna, hatchTime, owner, attributes);
    this.store.save(pet);
    return pet;
  }

  getInventory(owner: string): Pet[] {
    return this.store.findByOwner(owner);
  }

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

export class HatcheryError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
    this.name = 'HatcheryError';
  }
}
