import { DNAAttributes, Rarity } from '../models/BasePet';

const COLORS = ['#E74C3C', '#2ECC71', '#3498DB', '#9B59B6', '#F1C40F', '#1ABC9C', '#E67E22', '#EC407A'];
const ELEMENTS = ['Fire', 'Water', 'Earth', 'Wind', 'Light', 'Shadow', 'Thunder', 'Ice'];
const PATTERNS = ['Spotted', 'Striped', 'Solid', 'Swirled', 'Crystalline', 'Mosaic'];

/**
 * DNADecoder — Converts random 24-hex DNA strings into creature attributes.
 * 
 * The algorithm is DETERMINISTIC: the same DNA always produces the same creature.
 * This is critical for:
 *   - Fairness in PvP/PvE (players can't claim RNG changed outcomes)
 *   - Reproducibility (test battles with known DNA)
 *   - Anti-cheat (Cloud Functions can re-run battles and verify outcomes)
 * 
 * DNA Format: 24 lowercase hex characters (12 bytes)
 *   Examples: 'a1b2c3d4e5f6a7b8c9d0e1f2', 'ff00ff00ff00ff00ff00ff00'
 * 
 * Decoding Process:
 *   - Each 2 hex chars (1 byte) represents one genetic trait
 *   - Traits are mapped to discrete creature attributes:
 *     * Bytes 0–1: color      (0–255 → 8 colors, [0] % 8)
 *     * Bytes 2–3: rarity     (0–255 → parseRarity())
 *     * Bytes 4–7: basePower  (0–65535 → scaled to 1–100)
 *     * Bytes 8–9: element    (0–255 → 8 elements)
 *     * Bytes 10–11: pattern   (0–255 → 6 patterns)
 * 
 * Rarity Distribution (cumulative):
 *   Common:   0–50%  (0.0–0.5)
 *   Uncommon: 50–75% (0.5–0.75)
 *   Rare:     75–90% (0.75–0.9)
 *   Epic:     90–98% (0.9–0.98)
 *   Legendary: 98–100% (0.98–1.0) — very rare
 */
export class DNADecoder {
  /**
   * Decode a 24-hex DNA string into creature attributes.
   * Each hex pair maps deterministically to one trait, so the same DNA always
   * produces the same creature — important for reproducibility and fairness.
   */
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

  /**
   * Generate a random 24-hex DNA string (12 random bytes).
   * 
   * Process:
   *   1. Create 12 random bytes (0–255 each)
   *   2. Convert each byte to hex (00–ff)
   *   3. Pad with leading zero if needed (e.g., '0a' not 'a')
   *   4. Join all 12 hex pairs into one 24-char string
   * 
   * Example output: 'e74c3c2ecc713498db9b59b6'
   * 
   * Randomness: Uses Math.random() (not cryptographically secure,
   *             but sufficient for MVP game mechanics).
   */
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
