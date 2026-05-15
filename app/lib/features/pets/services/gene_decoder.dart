import 'dart:math';
import 'package:likha_pet_battle_engine/trait.dart';

/// Decodes 24-char hex DNA strings into body + parts composition.
/// Matches Axie Genetics: deterministic, scalable, single source of truth.
///
/// DNA Format (24 hex chars = 12 bytes):
///   Byte 0: body class      (0-255 % 6 → CreatureClass)
///   Byte 1: horn class      (0-255 % 6 → CreatureClass)
///   Byte 2: back class      (0-255 % 6 → CreatureClass)
///   Byte 3: tail class      (0-255 % 6 → CreatureClass)
///   Byte 4: mouth class     (0-255 % 6 → CreatureClass)
///   Byte 5: color           (0-255 % 8 → hex color string)
///   Byte 6: rarity          (0-255 → cumulative Rarity enum)
///   Byte 7: element         (0-255 % 8 → element name)
///   Byte 8: pattern         (0-255 % 6 → pattern name)
///   Bytes 9-11: reserved for future expansion
///
/// Key Property: DETERMINISTIC
///   The same DNA always produces the same creature attributes.
///   This is critical for reproducibility and anti-cheat validation.
class GeneDecoder {
  // CreatureClass values indexed 0-5 (for reference only)
  // plant=0, aquatic=1, beast=2, reptile=3, bird=4, bug=5

  // Color palette (8 colors)
  static const _colors = [
    '#E74C3C', // Red
    '#2ECC71', // Green
    '#3498DB', // Blue
    '#9B59B6', // Purple
    '#F1C40F', // Yellow
    '#1ABC9C', // Teal
    '#E67E22', // Orange
    '#EC407A', // Pink
  ];

  // Elements (8 elements)
  static const _elements = [
    'Fire',
    'Water',
    'Earth',
    'Wind',
    'Light',
    'Shadow',
    'Thunder',
    'Ice',
  ];

  // Patterns (6 patterns)
  static const _patterns = [
    'Spotted',
    'Striped',
    'Solid',
    'Swirled',
    'Crystalline',
    'Mosaic',
  ];

  /// Decode 24-char hex DNA into complete pet genetics.
  /// Throws [ArgumentError] if DNA format is invalid.
  static DecodedGenes decode(String dna) {
    if (dna.length != 24) {
      throw ArgumentError('DNA must be exactly 24 hex characters, got ${dna.length}');
    }
    if (!RegExp(r'^[0-9a-f]{24}$').hasMatch(dna)) {
      throw ArgumentError('DNA must be 24 lowercase hex characters');
    }

    // Helper to extract 2-char hex substring and convert to int
    int byte(int start) => int.parse(dna.substring(start, start + 2), radix: 16);

    final bodyClass  = _classFromByte(byte(0));
    final hornClass  = _classFromByte(byte(2));
    final backClass  = _classFromByte(byte(4));
    final tailClass  = _classFromByte(byte(6));
    final mouthClass = _classFromByte(byte(8));

    // Byte 9  (hex 18-19): upper nibble = horn variant index (0-15 → mod 6)
    //                       lower nibble = back variant index (0-15 → mod 6)
    // Byte 10 (hex 20-21): upper nibble = tail variant index (0-15 → mod 6)
    //                       lower nibble = mouth variant index (0-15 → mod 4)
    // OwnedPet._partId() applies the modulo against the available-variant arrays.
    final variantByte1  = byte(18);
    final variantByte2  = byte(20);
    final hornVariant   = variantByte1 >> 4;    // 0-15
    final backVariant   = variantByte1 & 0xF;   // 0-15
    final tailVariant   = variantByte2 >> 4;    // 0-15
    final mouthVariant  = variantByte2 & 0xF;   // 0-15

    return DecodedGenes(
      dna:         dna,
      bodyClass:   bodyClass,
      hornClass:   hornClass,
      backClass:   backClass,
      tailClass:   tailClass,
      mouthClass:  mouthClass,
      hornVariant:  hornVariant,
      backVariant:  backVariant,
      tailVariant:  tailVariant,
      mouthVariant: mouthVariant,
      color:   _colors[byte(10) % _colors.length],
      rarity:  _parseRarity(byte(12)),
      element: _elements[byte(14) % _elements.length],
      pattern: _patterns[byte(16) % _patterns.length],
    );
  }

  /// Generate a random 24-char hex DNA string (12 random bytes).
  /// Uses Dart's Random for sufficient entropy in MVP.
  static String generateDNA() {
    final random = Random();
    final buffer = StringBuffer();
    for (int i = 0; i < 12; i++) {
      final byte = random.nextInt(256);
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Convert a byte value to a CreatureClass.
  /// Uses modulo to map 0-255 to 6 creature classes.
  static CreatureClass _classFromByte(int b) {
    return CreatureClass.values[b % 6];
  }

  /// Parse rarity from a byte value using cumulative distribution.
  /// Matches server DNADecoder for consistency.
  static String _parseRarity(int seed) {
    final roll = seed / 255;
    if (roll < 0.50) return 'Common';
    if (roll < 0.75) return 'Uncommon';
    if (roll < 0.90) return 'Rare';
    if (roll < 0.98) return 'Epic';
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
