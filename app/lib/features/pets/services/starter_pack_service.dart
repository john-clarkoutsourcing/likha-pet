import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../models/owned_pet.dart';
import './gene_decoder.dart';

// ── StarterPackService ────────────────────────────────────────────────────────
//
// Generates the initial 3 pets for a new player.
//
// Guarantees:
//   1. All 3 starters have DIFFERENT body classes — no duplicate classes.
//   2. The body classes are drawn from the 6 available, randomly ordered.
//   3. Parts use rarity-weighted generation (common parts are most likely).
//   4. All 3 starters are Common rarity — fair starting point for everyone.
//
// After the starter pack, new pets via breeding or future hatching use fully
// random rarity-weighted generation (including rare/epic/legendary parts).

class StarterPackService {
  static final _uuid = const Uuid();

  // ── Starter pack (3 guaranteed-diverse pets) ────────────────────────────────

  /// Generate the 3 starter pets. Always called once on first launch.
  /// Each pet has a unique body class (no duplicate starting classes).
  static List<OwnedPet> generate() {
    final rng = Random();

    // Pick 3 distinct classes at random from all 6.
    final allClasses = List<CreatureClass>.from(CreatureClass.values)..shuffle(rng);
    final starterClasses = allClasses.take(3).toList();

    return starterClasses.map((cls) {
      // Generate DNA with forced body class and common-only part variants.
      final dna = GeneDecoder.generateStarterDNA(cls, rng: rng);
      return OwnedPet(
        uid:       _uuid.v4(),
        name:      _defaultName(cls),
        dna:       dna,
        generation: 0,
        createdAt: DateTime.now(),
      );
    }).toList();
  }

  // ── Hatch one random pet (breeding offspring, future eggs, etc.) ─────────────

  /// Hatch one pet with rarity-weighted part generation.
  static OwnedPet hatchRandom({
    int generation = 1,
    String? parentAId,
    String? parentBId,
  }) {
    final dna     = GeneDecoder.generateDNA();
    final decoded = GeneDecoder.decode(dna);
    return OwnedPet(
      uid:        _uuid.v4(),
      name:       _defaultName(decoded.bodyClass),
      dna:        dna,
      generation: generation,
      parentAId:  parentAId,
      parentBId:  parentBId,
      createdAt:  DateTime.now(),
    );
  }

  // ── Default names ─────────────────────────────────────────────────────────────

  static String _defaultName(CreatureClass cls) => switch (cls) {
    CreatureClass.plant   => 'Treant',
    CreatureClass.aquatic => 'Puffy',
    CreatureClass.beast   => 'Buba',
    CreatureClass.reptile => 'Kida',
    CreatureClass.bird    => 'Momo',
    CreatureClass.bug     => 'Plum',
  };
}
