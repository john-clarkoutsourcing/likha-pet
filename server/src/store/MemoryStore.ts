import { Pet } from '../models/Pet';

export class MemoryStore {
  private readonly pets = new Map<string, Pet>();

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
}
