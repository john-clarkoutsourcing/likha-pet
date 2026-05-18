import 'dart:math';
import 'package:likha_pet_battle_engine/trait.dart';

/// Decodes 24-char hex DNA strings into body + parts composition.
///
/// DNA Format (24 hex chars = 12 bytes):
///   Byte 0  (hex 00-01): body class      — 0-255 % 6 → CreatureClass
///   Byte 1  (hex 02-03): horn class      — 0-255 % 6 → CreatureClass
///   Byte 2  (hex 04-05): back class      — 0-255 % 6 → CreatureClass
///   Byte 3  (hex 06-07): tail class      — 0-255 % 6 → CreatureClass
///   Byte 4  (hex 08-09): mouth class     — 0-255 % 6 → CreatureClass
///   Byte 5  (hex 10-11): color           — 0-255 % 8 → color string
///   Byte 6  (hex 12-13): element         — 0-255 % 8 → element string
///   Byte 7  (hex 14-15): pattern         — 0-255 % 6 → pattern string
///   Byte 8  (hex 16-17): reserved
///   Byte 9  (hex 18-19): variant AB      — upper nibble = horn, lower = back
///   Byte 10 (hex 20-21): variant CD      — upper nibble = tail, lower = mouth
///   Byte 11 (hex 22-23): reserved
///
/// VARIANT NIBBLE → CARD TIER (encoded in generateDNA, decoded deterministically):
///   Nibble 0-1  → Common     (HBT: '02'/'04' | Mouth: '02')
///   Nibble 2-3  → Uncommon   (HBT: '06'/'08' | Mouth: '04')
///   Nibble 4    → Rare       (HBT: '10'       | Mouth: '08')
///   Nibble 5    → Epic       (HBT: '12'       | Mouth: '10')
///   Nibbles 6-15 → wrap back to same mapping (mod 6 / mod 4)
///
/// RARITY LABEL is derived from the average variant tier of all 4 parts —
/// it is NOT stored as a separate byte, so it always reflects actual part quality.
///
/// Key Property: DETERMINISTIC — same DNA always produces the same attributes.
class GeneDecoder {
  // ── Lore tables (cosmetic only, no battle effect) ────────────────────────────

  static const _colors = [
    '#E74C3C', '#2ECC71', '#3498DB', '#9B59B6',
    '#F1C40F', '#1ABC9C', '#E67E22', '#EC407A',
  ];

  static const _elements = [
    'Fire', 'Water', 'Earth', 'Wind',
    'Light', 'Shadow', 'Thunder', 'Ice',
  ];

  static const _patterns = [
    'Spotted', 'Striped', 'Solid',
    'Swirled', 'Crystalline', 'Mosaic',
  ];

  // ── Part variant rarity weights ───────────────────────────────────────────────
  //
  // Used during DNA generation only. Maps a weighted roll to a nibble value (0–5)
  // that decode() later maps to a specific card variant.
  //
  // Rarity tier  → nibble value → HBT card  / Mouth card
  //   Common     → 0            → '02'      / '02'
  //   Common     → 1            → '04'      / '04'   (HBT only differs from mouth here)
  //   Uncommon   → 2            → '06'      / '04'   (mouth has 4 variants, HBT has 6)
  //   Rare       → 3            → '08'      / '08'
  //   Epic       → 4            → '10'      / '10'
  //   Legendary  → 5            → '12'      / '10'   (mouth has no '12')
  //
  // The weights below make Common parts drop ~50%, Legendary ~2%.
  static const _kVariantWeights = [
    0.35, // nibble 0 → Common
    0.20, // nibble 1 → Common-2
    0.20, // nibble 2 → Uncommon
    0.13, // nibble 3 → Rare
    0.08, // nibble 4 → Epic
    0.04, // nibble 5 → Legendary
  ];

  // ── Decode ────────────────────────────────────────────────────────────────────

  /// Decode a 24-char hex DNA string into full pet genetics.
  static DecodedGenes decode(String dna) {
    if (dna.length != 24) {
      throw ArgumentError('DNA must be 24 hex characters, got ${dna.length}');
    }
    if (!RegExp(r'^[0-9a-f]{24}$').hasMatch(dna)) {
      throw ArgumentError('DNA must be 24 lowercase hex characters');
    }

    int byte(int charPos) =>
        int.parse(dna.substring(charPos, charPos + 2), radix: 16);

    final bodyClass  = _classFromByte(byte(0));
    final hornClass  = _classFromByte(byte(2));
    final backClass  = _classFromByte(byte(4));
    final tailClass  = _classFromByte(byte(6));
    final mouthClass = _classFromByte(byte(8));

    final v1 = byte(18); // variant byte 1: horn (hi) + back (lo)
    final v2 = byte(20); // variant byte 2: tail (hi) + mouth (lo)

    final hornVariant  = v1 >> 4;  // 0-15
    final backVariant  = v1 & 0xF; // 0-15
    final tailVariant  = v2 >> 4;  // 0-15
    final mouthVariant = v2 & 0xF; // 0-15

    // Rarity is derived from the average variant tier — reflects true card quality.
    final rarity = _rarityFromVariants(
        hornVariant, backVariant, tailVariant, mouthVariant);

    return DecodedGenes(
      dna:          dna,
      bodyClass:    bodyClass,
      hornClass:    hornClass,
      backClass:    backClass,
      tailClass:    tailClass,
      mouthClass:   mouthClass,
      hornVariant:  hornVariant,
      backVariant:  backVariant,
      tailVariant:  tailVariant,
      mouthVariant: mouthVariant,
      color:   _colors[byte(10) % _colors.length],
      rarity:  rarity,
      element: _elements[byte(12) % _elements.length],
      pattern: _patterns[byte(14) % _patterns.length],
    );
  }

  // ── Generation ────────────────────────────────────────────────────────────────

  /// Generate a random DNA string with rarity-weighted part variants.
  /// Most pets will have Common parts; Legendary parts are genuinely rare.
  static String generateDNA({Random? rng}) {
    final r = rng ?? Random();
    final bytes = List<int>.filled(12, 0);

    // Bytes 0-4: body + part classes (uniform random across all 6 classes)
    for (int i = 0; i < 5; i++) {
      bytes[i] = r.nextInt(256);
    }

    // Bytes 5-7: color, element, pattern (uniform random, cosmetic only)
    for (int i = 5; i < 8; i++) {
      bytes[i] = r.nextInt(256);
    }

    // Byte 8: reserved
    bytes[8] = 0;

    // Bytes 9-10: variant nibbles — rarity-weighted per part slot.
    final hornN  = _rollVariantNibble(r);
    final backN  = _rollVariantNibble(r);
    final tailN  = _rollVariantNibble(r);
    final mouthN = _rollVariantNibble(r);
    bytes[9]  = (hornN << 4) | backN;
    bytes[10] = (tailN << 4) | mouthN;

    // Byte 11: reserved
    bytes[11] = 0;

    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// Generate a DNA string for a starter pet:
  ///   • Guaranteed body class matches [cls]
  ///   • Part variants are Common only (nibbles 0-1) — fair starting point
  ///   • Part classes are fully random (hybrids are fine for starters)
  static String generateStarterDNA(CreatureClass cls, {Random? rng}) {
    final r = rng ?? Random();
    final bytes = List<int>.filled(12, 0);

    // Byte 0: forced body class.
    bytes[0] = cls.index + 6 * r.nextInt(42);

    // Bytes 1-4: random part classes (uniform).
    for (int i = 1; i < 5; i++) {
      bytes[i] = r.nextInt(256);
    }

    // Bytes 5-7: cosmetic (color, element, pattern).
    for (int i = 5; i < 8; i++) {
      bytes[i] = r.nextInt(256);
    }

    // Byte 8: reserved.
    bytes[8] = 0;

    // Bytes 9-10: variant nibbles — Common only (nibbles 0 or 1).
    // This ensures all starters have Common-tier cards.
    final hornN  = r.nextInt(2); // 0 or 1
    final backN  = r.nextInt(2);
    final tailN  = r.nextInt(2);
    final mouthN = r.nextInt(2);
    bytes[9]  = (hornN << 4) | backN;
    bytes[10] = (tailN << 4) | mouthN;

    bytes[11] = 0;

    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static CreatureClass _classFromByte(int b) =>
      CreatureClass.values[b % CreatureClass.values.length];

  /// Weighted roll → nibble index 0-5 using the rarity weight table.
  static int _rollVariantNibble(Random rng) {
    final roll = rng.nextDouble();
    double cumulative = 0;
    for (int i = 0; i < _kVariantWeights.length; i++) {
      cumulative += _kVariantWeights[i];
      if (roll < cumulative) return i;
    }
    return _kVariantWeights.length - 1;
  }

  /// Derive a rarity label from the average variant tier across all 4 parts.
  /// Nibble 0-1 = Common, 2 = Uncommon, 3 = Rare, 4 = Epic, 5 = Legendary.
  /// Average is taken so mixed pets show a fair combined rarity.
  static String _rarityFromVariants(int h, int b, int t, int m) {
    // Clamp each nibble to the tier range 0-5 (mod 6 mirrors what OwnedPet does).
    final avgTier = ((h % 6) + (b % 6) + (t % 6) + (m % 6)) / 4.0;
    if (avgTier < 1.5) return 'Common';
    if (avgTier < 2.5) return 'Uncommon';
    if (avgTier < 3.5) return 'Rare';
    if (avgTier < 4.5) return 'Epic';
    return 'Legendary';
  }
}

/// Complete set of attributes decoded from a DNA string.
class DecodedGenes {
  final String dna;
  final CreatureClass bodyClass;
  final CreatureClass hornClass;
  final CreatureClass backClass;
  final CreatureClass tailClass;
  final CreatureClass mouthClass;
  /// 0 = base part (no suffix), 1 = _2 variant
  final int hornVariant;
  final int backVariant;
  final int tailVariant;
  final int mouthVariant;
  final String color;
  final String rarity;
  final String element;
  final String pattern;

  const DecodedGenes({
    required this.dna,
    required this.bodyClass,
    required this.hornClass,
    required this.backClass,
    required this.tailClass,
    required this.mouthClass,
    this.hornVariant  = 0,
    this.backVariant  = 0,
    this.tailVariant  = 0,
    this.mouthVariant = 0,
    required this.color,
    required this.rarity,
    required this.element,
    required this.pattern,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecodedGenes &&
          runtimeType == other.runtimeType &&
          dna == other.dna &&
          bodyClass == other.bodyClass &&
          hornClass == other.hornClass &&
          backClass == other.backClass &&
          tailClass == other.tailClass &&
          mouthClass == other.mouthClass &&
          color == other.color &&
          rarity == other.rarity &&
          element == other.element &&
          pattern == other.pattern;

  @override
  int get hashCode =>
      dna.hashCode ^
      bodyClass.hashCode ^
      hornClass.hashCode ^
      backClass.hashCode ^
      tailClass.hashCode ^
      mouthClass.hashCode ^
      color.hashCode ^
      rarity.hashCode ^
      element.hashCode ^
      pattern.hashCode;

  @override
  String toString() => 'DecodedGenes('
      'dna: $dna, '
      'body: ${bodyClass.name}, '
      'horn: ${hornClass.name}, '
      'back: ${backClass.name}, '
      'tail: ${tailClass.name}, '
      'mouth: ${mouthClass.name}, '
      'color: $color, '
      'rarity: $rarity, '
      'element: $element, '
      'pattern: $pattern)';
}
