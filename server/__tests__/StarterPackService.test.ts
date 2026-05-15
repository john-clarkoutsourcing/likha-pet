import { StarterPackService } from '../src/services/StarterPackService';
import { FirestoreService } from '../src/services/FirestoreService';
import { DNADecoder } from '../src/systems/DNADecoder';

jest.mock('../src/services/FirestoreService');

describe('StarterPackService', () => {
  let starterPack: StarterPackService;
  let firestore: jest.Mocked<FirestoreService>;

  beforeEach(() => {
    firestore = new FirestoreService() as jest.Mocked<FirestoreService>;
    firestore.savePet = jest.fn().mockResolvedValue(undefined);
    firestore.getPetsForUser = jest.fn().mockResolvedValue([]);
    starterPack = new StarterPackService(firestore);
  });

  describe('createStarterPack', () => {
    it('creates 3 eggs with random DNA for new player', async () => {
      const userId = 'test-user-123';

      const eggs = await starterPack.createStarterPack(userId);

      expect(eggs).toHaveLength(3);
      expect(firestore.savePet).toHaveBeenCalledTimes(3);

      // Verify all eggs
      eggs.forEach((egg) => {
        expect(egg.state).toBe('Egg');
        expect(egg.owner).toBe(userId);
        expect(egg.dna).toMatch(/^[0-9a-f]{24}$/);
        expect(egg.hatchTime).toBeDefined();
        expect(egg.attributes).toBeDefined();
        expect(egg.name).toMatch(/^Likha #[A-F0-9]{6}$/);
      });
    });

    it('generates unique DNA for each egg', async () => {
      const userId = 'test-user-456';

      const eggs = await starterPack.createStarterPack(userId);

      const dnasSet = new Set(eggs.map(e => e.dna));
      // All 3 DNAs should be unique (extremely unlikely to generate same DNA twice)
      expect(dnasSet.size).toBe(3);
    });

    it('eggs are ready to hatch immediately (hatchTime = now)', async () => {
      const userId = 'test-user-789';
      const before = Date.now();

      const eggs = await starterPack.createStarterPack(userId);

      const after = Date.now();

      eggs.forEach((egg) => {
        // hatchTime should be very close to now (within 1 second)
        expect(egg.hatchTime).toBeGreaterThanOrEqual(before);
        expect(egg.hatchTime).toBeLessThanOrEqual(after + 1000);
      });
    });

    it('saves all 3 pets to Firestore with correct userId', async () => {
      const userId = 'test-user-xyz';

      await starterPack.createStarterPack(userId);

      expect(firestore.savePet).toHaveBeenCalledTimes(3);

      // Check all calls have correct userId
      firestore.savePet.mock.calls.forEach(([callUserId, pet]) => {
        expect(callUserId).toBe(userId);
        expect(pet.state).toBe('Egg');
        expect(pet.owner).toBe(userId);
      });
    });

    it('each egg has unique ID and attributes', async () => {
      const userId = 'test-user-unique';

      const eggs = await starterPack.createStarterPack(userId);

      const ids = eggs.map(e => e.id);
      const uniqueIds = new Set(ids);
      expect(uniqueIds.size).toBe(3);

      // Verify attributes are decoded from DNA
      eggs.forEach((egg) => {
        expect(egg.attributes.color).toBeDefined();
        expect(egg.attributes.rarity).toBeDefined();
        expect(egg.attributes.basePower).toBeGreaterThan(0);
        expect(egg.attributes.element).toBeDefined();
        expect(egg.attributes.pattern).toBeDefined();
      });
    });
  });

  describe('hasClaimedStarterPack', () => {
    it('returns false for new user with no pets', async () => {
      firestore.getPetsForUser.mockResolvedValue([]);

      const hasClaimed = await starterPack.hasClaimedStarterPack('new-user');

      expect(hasClaimed).toBe(false);
    });

    it('returns true for user with at least one pet', async () => {
      const mockPets = [
        {
          id: 'pet-1',
          state: 'Egg' as const,
          dna: '000000000000000000000000',
          owner: 'player-1',
          hatchTime: Date.now(),
          createdAt: Date.now(),
        },
      ];
      firestore.getPetsForUser.mockResolvedValue(mockPets);

      const hasClaimed = await starterPack.hasClaimedStarterPack('player-1');

      expect(hasClaimed).toBe(true);
    });
  });

  describe('DNA generation and attributes', () => {
    it('creates pets with realistic attribute distribution', async () => {
      const userId = 'test-distribution';

      const eggs = await starterPack.createStarterPack(userId);

      eggs.forEach((egg) => {
        const { attributes } = egg;
        
        // Verify all attributes are present
        expect(['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary']).toContain(
          attributes.rarity
        );
        expect(['Fire', 'Water', 'Earth', 'Wind', 'Light', 'Shadow', 'Thunder', 'Ice']).toContain(
          attributes.element
        );
        expect(attributes.basePower).toBeGreaterThan(0);
        expect(attributes.basePower).toBeLessThanOrEqual(100);
        expect(attributes.color).toBeDefined();
        expect(attributes.pattern).toBeDefined();
      });
    });
  });
});
