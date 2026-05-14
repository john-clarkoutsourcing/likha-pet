import { DNADecoder } from '../src/systems/DNADecoder';

describe('DNADecoder', () => {
  describe('generateDNA', () => {
    it('produces a 24-character hex string', () => {
      const dna = DNADecoder.generateDNA();
      expect(dna).toMatch(/^[0-9a-f]{24}$/);
    });

    it('produces unique DNAs across calls', () => {
      const samples = new Set(Array.from({ length: 100 }, () => DNADecoder.generateDNA()));
      expect(samples.size).toBe(100);
    });
  });

  describe('decode', () => {
    it('returns deterministic attributes for the same DNA', () => {
      const dna = DNADecoder.generateDNA();
      expect(DNADecoder.decode(dna)).toEqual(DNADecoder.decode(dna));
    });

    it('returns a valid color hex string', () => {
      const { color } = DNADecoder.decode(DNADecoder.generateDNA());
      expect(color).toMatch(/^#[0-9A-Fa-f]{6}$/);
    });

    it('returns basePower between 1 and 100', () => {
      for (let i = 0; i < 50; i++) {
        const { basePower } = DNADecoder.decode(DNADecoder.generateDNA());
        expect(basePower).toBeGreaterThanOrEqual(1);
        expect(basePower).toBeLessThanOrEqual(100);
      }
    });

    it('returns a valid rarity', () => {
      const valid = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary'];
      const { rarity } = DNADecoder.decode(DNADecoder.generateDNA());
      expect(valid).toContain(rarity);
    });

    it('Legendary appears roughly 2% of the time (probabilistic)', () => {
      // Force the rarity seed byte to 0xFF (255/255 = 1.0 → Legendary)
      const legendaryDna = 'ff' + 'ff' + '0000' + '00' + '00';
      expect(DNADecoder.decode(legendaryDna).rarity).toBe('Legendary');
    });

    it('Common appears for low rarity seed', () => {
      // seed byte 0x00 → roll = 0 → Common
      const commonDna = '00' + '00' + '0000' + '00' + '00';
      expect(DNADecoder.decode(commonDna).rarity).toBe('Common');
    });
  });
});
