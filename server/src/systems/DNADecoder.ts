import { DNAAttributes, Rarity } from '../models/BasePet';

const COLORS = ['#E74C3C', '#2ECC71', '#3498DB', '#9B59B6', '#F1C40F', '#1ABC9C', '#E67E22', '#EC407A'];
const ELEMENTS = ['Fire', 'Water', 'Earth', 'Wind', 'Light', 'Shadow', 'Thunder', 'Ice'];
const PATTERNS = ['Spotted', 'Striped', 'Solid', 'Swirled', 'Crystalline', 'Mosaic'];

export class DNADecoder {
  // Each hex pair maps deterministically to one trait, so the same DNA always
  // produces the same creature — important for reproducibility and fairness.
  static decode(dna: string): DNAAttributes {
    const b = (start: number, len = 2) => parseInt(dna.slice(start, start + len), 16);

    return {
      color:     COLORS[b(0) % COLORS.length],
      rarity:    DNADecoder.parseRarity(b(2)),
      basePower: Math.floor((b(4, 4) / 0xffff) * 99) + 1, // 1–100
      element:   ELEMENTS[b(8) % ELEMENTS.length],
      pattern:   PATTERNS[b(10) % PATTERNS.length],
    };
  }

  static generateDNA(): string {
    return Array.from({ length: 12 }, () =>
      Math.floor(Math.random() * 256).toString(16).padStart(2, '0'),
    ).join('');
  }

  private static parseRarity(seed: number): Rarity {
    const roll = seed / 255;
    if (roll < 0.50) return 'Common';
    if (roll < 0.75) return 'Uncommon';
    if (roll < 0.90) return 'Rare';
    if (roll < 0.98) return 'Epic';
    return 'Legendary';
  }
}
