// ── TeamComposition ───────────────────────────────────────────────────────────
//
// Represents a saved team composition with a custom name.
// Players can create multiple teams and switch between them.
//
// Example:
//   name: "PPR" or "Plant-Plant-Reptile"
//   petUids: ["uuid1", "uuid2", "uuid3"] (front, mid, back)

class TeamComposition {
  final String id;                // UUID (unique team ID)
  final String name;              // e.g., "PPR", "My Fire Team"
  final List<String> petUids;     // [front, mid, back] pet UIDs (length == 3)
  final DateTime createdAt;
  final DateTime updatedAt;

  const TeamComposition({
    required this.id,
    required this.name,
    required this.petUids,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(petUids.length == 3);

  /// Get position label for a slot (0=front, 1=mid, 2=back)
  static String positionLabel(int slot) => switch (slot) {
    0 => 'FRONT',
    1 => 'MID',
    2 => 'BACK',
    _ => '',
  };

  factory TeamComposition.fromJson(Map<String, dynamic> j) => TeamComposition(
    id: j['id'] as String,
    name: j['name'] as String,
    petUids: List<String>.from(j['petUids'] as List),
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'petUids': petUids,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  TeamComposition copyWith({
    String? id,
    String? name,
    List<String>? petUids,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TeamComposition(
    id: id ?? this.id,
    name: name ?? this.name,
    petUids: petUids ?? this.petUids,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
