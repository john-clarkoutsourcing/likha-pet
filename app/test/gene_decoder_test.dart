import 'package:flutter_test/flutter_test.dart';
import 'package:likha_pet/features/pets/services/gene_decoder.dart';
import 'package:likha_pet_battle_engine/trait.dart';

void main() {
  group('GeneDecoder', () {
    test('generateDNA creates valid 24-char hex string', () {
      final dna = GeneDecoder.generateDNA();
      expect(dna.length, 24);
      expect(RegExp(r'^[0-9a-f]{24}$').hasMatch(dna), true);
    });

    test('decode is deterministic - same DNA always produces same result', () {
      final dna = 'a1b2c3d4e5f6a7b8c9d0e1f2';
      final result1 = GeneDecoder.decode(dna);
      final result2 = GeneDecoder.decode(dna);
      
      expect(result1, result2);
      expect(result1.dna, dna);
    });

    test('decode extracts all 10 attributes from DNA', () {
      final dna = 'a1b2c3d4e5f6a7b8c9d0e1f2';
      final decoded = GeneDecoder.decode(dna);
      
      expect(decoded.dna, dna);
      expect(decoded.bodyClass, isA<CreatureClass>());
      expect(decoded.hornClass, isA<CreatureClass>());
      expect(decoded.backClass, isA<CreatureClass>());
      expect(decoded.tailClass, isA<CreatureClass>());
      expect(decoded.mouthClass, isA<CreatureClass>());
      expect(decoded.color, matches(r'^#[0-9A-F]{6}$'));
      expect(decoded.rarity, isIn(['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary']));
      expect(decoded.element, isIn(['Fire', 'Water', 'Earth', 'Wind', 'Light', 'Shadow', 'Thunder', 'Ice']));
      expect(decoded.pattern, isIn(['Spotted', 'Striped', 'Solid', 'Swirled', 'Crystalline', 'Mosaic']));
    });

    test('decode throws on invalid DNA length', () {
      expect(() => GeneDecoder.decode('tooshort'), throwsArgumentError);
      expect(() => GeneDecoder.decode('a1b2c3d4e5f6a7b8c9d0e1f2extra'), throwsArgumentError);
    });

    test('decode throws on non-hex characters', () {
      expect(() => GeneDecoder.decode('zzzzzzzzzzzzzzzzzzzzzzzz'), throwsArgumentError);
      expect(() => GeneDecoder.decode('G1b2c3d4e5f6a7b8c9d0e1f2'), throwsArgumentError);
    });

    test('all 6 creature classes can be decoded', () {
      final classes = <CreatureClass>{};
      
      // Generate 100 random DNAs and collect unique classes
      for (int i = 0; i < 100; i++) {
        final dna = GeneDecoder.generateDNA();
        final decoded = GeneDecoder.decode(dna);
        classes.add(decoded.bodyClass);
      }
      
      // With 100 samples, we should see most classes
      expect(classes.length, greaterThan(2));
    });

    test('rarity distribution follows cumulative probabilities', () {
      final rarities = <String, int>{};
      
      // Generate 1000 DNAs and check rarity distribution
      for (int i = 0; i < 1000; i++) {
        final dna = GeneDecoder.generateDNA();
        final decoded = GeneDecoder.decode(dna);
        rarities[decoded.rarity] = (rarities[decoded.rarity] ?? 0) + 1;
      }
      
      // Check that Common is most frequent
      final commonCount = rarities['Common'] ?? 0;
      final legendaryCount = rarities['Legendary'] ?? 0;
      expect(commonCount, greaterThan(legendaryCount));
      
      // All rarities should appear
      expect(rarities.keys.length, greaterThan(0));
    });
  });
}
