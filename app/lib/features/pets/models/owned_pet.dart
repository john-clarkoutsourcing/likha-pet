import 'package:likha_pet_battle_engine/trait.dart';
import '../../battle/data/creature_registry.dart';
import '../services/gene_decoder.dart';

// ── PetGenes ──────────────────────────────────────────────────────────────────
//
// Three genetic layers per part slot, matching Axie's D / R1 / R2 system.
// Only [dominant] is used in battle. [r1] and [r2] are inherited by offspring.

class PetGenes {
  final String dominant;  // kPartCatalogue key — the visible, active part
  final String? r1;       // recessive 1 — passed during breeding
  final String? r2;       // recessive 2 — deeply hidden, rare inheritance

  const PetGenes({required this.dominant, this.r1, this.r2});

  factory PetGenes.fromJson(Map<String, dynamic> j) => PetGenes(
    dominant: j['d'] as String,
    r1: j['r1'] as String?,
    r2: j['r2'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'd': dominant,
    if (r1 != null) 'r1': r1,
    if (r2 != null) 'r2': r2,
  };
}

// ── OwnedPet ──────────────────────────────────────────────────────────────────
//
// A pet in the player's roster. Identified by [uid] (UUID).
// DNA = 24-char hex string containing all genetic information:
//   • Body class (determines visual skeleton + base stats)
//   • 4 Part classes (determines card pool + stat bonuses)
//   • Color, rarity, element, pattern (for future visual/gameplay effects)
//
// This matches Axie Genetics: single DNA string is the source of truth.
// All other attributes are deterministically derived from DNA on-demand.

class OwnedPet {
  final String uid;
  final String name;
  final String dna;              // 24-char hex: single source of truth
  final int breedCount;          // 0–5; cost increases per breed
  final int generation;          // 0 = starter, 1 = first offspring, etc.
  final String? parentAId;
  final String? parentBId;
  final DateTime createdAt;

  // Lazy-loaded decoded genetics
  late final DecodedGenes _decoded = GeneDecoder.decode(dna);

  OwnedPet({
    required this.uid,
    required this.name,
    required this.dna,
    this.breedCount = 0,
    this.generation = 0,
    this.parentAId,
    this.parentBId,
    required this.createdAt,
  });

  // ── Derived attributes from DNA ────────────────────────────────────────────

  /// Body type ID (e.g., 'beast_1', 'plant_1')
  String get bodyId => '${_decoded.bodyClass.name}_1';

  /// Part IDs derived from decoded DNA.
  /// Maps variant nibble (0-15) → catalogue key '{class}_{slot}_{variantCode}'.
  String get hornId  => _partId(_decoded.hornClass.name,  'horn',  _decoded.hornVariant);
  String get backId  => _partId(_decoded.backClass.name,  'back',  _decoded.backVariant);
  String get tailId  => _partId(_decoded.tailClass.name,  'tail',  _decoded.tailVariant);
  String get mouthId => _partId(_decoded.mouthClass.name, 'mouth', _decoded.mouthVariant);

  // Horn/back/tail: 6 variants; mouth: 4 variants (matching local card-art availability)
  static const _kHBTVariants   = ['02', '04', '06', '08', '10', '12'];
  static const _kMouthVariants = ['02', '04', '08', '10'];

  static String _partId(String cls, String slot, int idx) {
    final variants = slot == 'mouth' ? _kMouthVariants : _kHBTVariants;
    final v = variants[idx % variants.length];
    return '${cls}_${slot}_$v';
  }

  /// Visual attributes from DNA
  String get color => _decoded.color;
  String get rarity => _decoded.rarity;
  String get element => _decoded.element;
  String get pattern => _decoded.pattern;

  bool get canBreed => breedCount < 5;

  /// Purity = number of parts whose class matches the body class (0–4).
  int get purity {
    final body = kBodyCatalogue[bodyId];
    if (body == null) return 0;
    final cls = body.bodyClass;
    int count = 0;
    for (final id in [hornId, backId, tailId, mouthId]) {
      final part = kPartCatalogue[id];
      if (part != null && part.partClass == cls) count++;
    }
    return count;
  }

  String get purityLabel => '$purity/4';

  String get classLabel {
    final body = kBodyCatalogue[bodyId];
    return body != null ? body.bodyClass.displayName : '?';
  }

  // ── Convert to CreatureDefinition for battle ───────────────────────────────

  CreatureDefinition toCreatureDefinition() {
    final body = kBodyCatalogue[bodyId]!;
    return CreatureDefinition(
      id: uid,
      name: name,
      body: body,
      horn: kPartCatalogue[hornId]!,
      back: kPartCatalogue[backId]!,
      tail: kPartCatalogue[tailId]!,
      mouth: kPartCatalogue[mouthId]!,
    );
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory OwnedPet.fromJson(Map<String, dynamic> j) {
    // Support both old (with bodyId + part genes) and new (with DNA) formats
    final hasDNA = j.containsKey('dna');
    
    if (hasDNA) {
      // New format: DNA-based
      return OwnedPet(
        uid: j['uid'] as String,
        name: j['name'] as String,
        dna: j['dna'] as String,
        breedCount: (j['breedCount'] as int?) ?? 0,
        generation: (j['generation'] as int?) ?? 0,
        parentAId: j['parentAId'] as String?,
        parentBId: j['parentBId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
    } else {
      // Old format: bodyId + part genes (migration path)
      // Convert old format to DNA by generating one from the parts
      // For now, we'll generate a deterministic DNA from the old data
      final oldDNA = _generateDNAFromLegacyFormat(j);
      return OwnedPet(
        uid: j['uid'] as String,
        name: j['name'] as String,
        dna: oldDNA,
        breedCount: (j['breedCount'] as int?) ?? 0,
        generation: (j['generation'] as int?) ?? 0,
        parentAId: j['parentAId'] as String?,
        parentBId: j['parentBId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'dna': dna,
    'breedCount': breedCount,
    'generation': generation,
    if (parentAId != null) 'parentAId': parentAId,
    if (parentBId != null) 'parentBId': parentBId,
    'createdAt': createdAt.toIso8601String(),
  };

  OwnedPet copyWith({
    String? name,
    int? breedCount,
  }) =>
      OwnedPet(
        uid: uid,
        name: name ?? this.name,
        dna: dna,
        breedCount: breedCount ?? this.breedCount,
        generation: generation,
        parentAId: parentAId,
        parentBId: parentBId,
        createdAt: createdAt,
      );

  /// Convert legacy format (bodyId + part genes) to DNA.
  /// This is a migration helper for backward compatibility.
  static String _generateDNAFromLegacyFormat(Map<String, dynamic> data) {
    // Map body ID to class index
    final bodyId = data['bodyId'] as String? ?? 'beast_1';
    final classMap = {
      'plant': 0,
      'aquatic': 1,
      'beast': 2,
      'reptile': 3,
      'bird': 4,
      'bug': 5,
    };
    
    int bodyIndex = 0;
    for (final key in classMap.keys) {
      if (bodyId.contains(key)) {
        bodyIndex = classMap[key]!;
        break;
      }
    }

    // Map part class to index
    int getClassIndex(String partId) {
      for (final key in classMap.keys) {
        if (partId.contains(key)) return classMap[key]!;
      }
      return 0;
    }

    final hornId = (data['horn'] as Map?)?['d'] as String? ?? 'beast_horn';
    final backId = (data['back'] as Map?)?['d'] as String? ?? 'beast_back';
    final tailId = (data['tail'] as Map?)?['d'] as String? ?? 'beast_tail';
    final mouthId = (data['mouth'] as Map?)?['d'] as String? ?? 'beast_mouth';

    // Generate DNA with class info in first 5 bytes
    final bytes = [
      bodyIndex,
      getClassIndex(hornId),
      getClassIndex(backId),
      getClassIndex(tailId),
      getClassIndex(mouthId),
      (data['color'] as int?) ?? 128,  // Color
      (data['rarity'] as int?) ?? 128, // Rarity
      (data['element'] as int?) ?? 64, // Element
      (data['pattern'] as int?) ?? 32, // Pattern
      0, 0, 0, // Reserved
    ];

    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('');
  }
}
