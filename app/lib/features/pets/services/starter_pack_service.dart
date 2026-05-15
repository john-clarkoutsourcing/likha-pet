import 'package:uuid/uuid.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../models/owned_pet.dart';
import './gene_decoder.dart';

// ── StarterPackService ────────────────────────────────────────────────────────
//
// Generates hatched pets for a new player using DNA-based genetics.
// Every pet is fully randomised via a single 24-char DNA string:
//   • Random body class (one of 6)
//   • Random part classes (one per slot, independent of body for hybrid support)
//   • Random color, rarity, element, pattern
//
// All attributes are deterministically derived from DNA on-demand.
// Same DNA always produces the same pet (reproducibility + anti-cheat).

class StarterPackService {
  static final _uuid = const Uuid();

  // ── Starter eggs (3 random hatches) ────────────────────────────────────────

  /// Hatch 3 random starter pets. Call once on first launch.
  /// Each pet gets unique DNA, so composition is fully random.
  static List<OwnedPet> generate() =>
      List.generate(3, (_) => hatchRandom(generation: 0));

  // ── Hatch logic ─────────────────────────────────────────────────────────────

  /// Hatch one pet: generate random DNA containing body + 4 part classes.
  /// [generation] 0 = starter egg, 1+ = bred offspring.
  static OwnedPet hatchRandom({
    int generation = 1,
    String? parentAId,
    String? parentBId,
  }) {
    final dna = GeneDecoder.generateDNA();
    final decoded = GeneDecoder.decode(dna);

    return OwnedPet(
      uid: _uuid.v4(),
      name: _defaultName(decoded.bodyClass),
      dna: dna,
      generation: generation,
      parentAId: parentAId,
      parentBId: parentBId,
      createdAt: DateTime.now(),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Default name based on body class — player can rename later.
  static String _defaultName(CreatureClass cls) => switch (cls) {
    CreatureClass.plant   => 'Treant',
    CreatureClass.aquatic => 'Puffy',
    CreatureClass.beast   => 'Buba',
    CreatureClass.reptile => 'Kida',
    CreatureClass.bird    => 'Momo',
    CreatureClass.bug     => 'Plum',
  };
}
