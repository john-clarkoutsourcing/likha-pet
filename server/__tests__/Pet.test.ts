import { Pet } from '../src/models/Pet';
import { PetState } from '../src/models/BasePet';
import { DNADecoder } from '../src/systems/DNADecoder';

function makePet(hatchTime = Date.now() + 60_000): Pet {
  const dna = DNADecoder.generateDNA();
  return new Pet('test-id', dna, hatchTime, 'player1', DNADecoder.decode(dna));
}

describe('Pet', () => {
  it('starts in Egg state', () => {
    expect(makePet().state).toBe(PetState.EGG);
  });

  it('generates a name from its id', () => {
    const pet = makePet();
    expect(pet.name).toBe('Likha #TEST-I'); // first 6 chars of 'test-id' uppercased
  });

  it('isReadyToHatch returns false before hatchTime', () => {
    expect(makePet(Date.now() + 60_000).isReadyToHatch()).toBe(false);
  });

  it('isReadyToHatch returns true after hatchTime', () => {
    expect(makePet(Date.now() - 1).isReadyToHatch()).toBe(true);
  });

  describe('hatch()', () => {
    it('transitions state to Hatched when ready', () => {
      const pet = makePet(Date.now() - 1);
      pet.hatch();
      expect(pet.state).toBe(PetState.HATCHED);
      expect(pet.hatchedAt).toBeDefined();
    });

    it('throws when egg is not ready', () => {
      const pet = makePet(Date.now() + 60_000);
      expect(() => pet.hatch()).toThrow(/not ready/i);
    });

    it('throws when already hatched', () => {
      const pet = makePet(Date.now() - 1);
      pet.hatch();
      expect(() => pet.hatch()).toThrow(/already hatched/i);
    });
  });
});
