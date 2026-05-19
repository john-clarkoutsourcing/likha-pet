// ── BattleRow / BattleLane ────────────────────────────────────────────────────

/// Which row of the 3×3 grid the pet occupies.
/// Row 0 (Front) is targeted first by default; row 2 (Back) is furthest.
enum BattleRow {
  front('FRONT'),
  mid('MID'),
  back('BACK');

  final String label;
  const BattleRow(this.label);

  static BattleRow fromIndex(int i) =>
      BattleRow.values.firstWhere((r) => r.index == i, orElse: () => BattleRow.front);
}

/// Which lane (column) of the 3×3 grid the pet occupies.
/// Lane 0 = Upper, 1 = Center, 2 = Lower.
enum BattleLane {
  upper('Upper'),
  center('Center'),
  lower('Lower');

  final String label;
  const BattleLane(this.label);

  static BattleLane fromIndex(int i) =>
      BattleLane.values.firstWhere((l) => l.index == i, orElse: () => BattleLane.center);
}

// ── TeamSlot ──────────────────────────────────────────────────────────────────

/// A single pet assignment inside a team: which pet + where it stands.
class TeamSlot {
  final String    petUid;
  final BattleRow row;
  final BattleLane lane;

  const TeamSlot({
    required this.petUid,
    this.row  = BattleRow.front,
    this.lane = BattleLane.center,
  });

  factory TeamSlot.fromJson(Map<String, dynamic> j) => TeamSlot(
    petUid: j['petUid'] as String,
    row:    BattleRow.fromIndex((j['row'] as num?)?.toInt() ?? 0),
    lane:   BattleLane.fromIndex((j['lane'] as num?)?.toInt() ?? 1),
  );

  Map<String, dynamic> toJson() => {
    'petUid': petUid,
    'row':    row.index,
    'lane':   lane.index,
  };

  TeamSlot copyWith({String? petUid, BattleRow? row, BattleLane? lane}) =>
      TeamSlot(
        petUid: petUid ?? this.petUid,
        row:    row    ?? this.row,
        lane:   lane   ?? this.lane,
      );
}

// ── TeamComposition ───────────────────────────────────────────────────────────

class TeamComposition {
  final String         id;
  final String         name;
  final List<TeamSlot> slots;   // always 3 entries
  final DateTime       createdAt;
  final DateTime       updatedAt;

  const TeamComposition({
    required this.id,
    required this.name,
    required this.slots,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Ordered pet UIDs for callers that only need the uid list.
  List<String> get petUids => slots.map((s) => s.petUid).toList();

  /// Deserialise — supports old format (petUids list) and new (slots list).
  factory TeamComposition.fromJson(Map<String, dynamic> j) {
    List<TeamSlot> slots;
    if (j['slots'] != null) {
      slots = (j['slots'] as List)
          .map((e) => TeamSlot.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // Legacy: petUids list → assign default rows 0/1/2, center lane
      final uids = List<String>.from(j['petUids'] as List);
      slots = List.generate(uids.length, (i) => TeamSlot(
        petUid: uids[i],
        row:    BattleRow.fromIndex(i),
        lane:   BattleLane.center,
      ));
    }
    return TeamComposition(
      id:        j['id'] as String,
      name:      j['name'] as String,
      slots:     slots,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':        id,
    'name':      name,
    'slots':     slots.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  TeamComposition copyWith({
    String?         id,
    String?         name,
    List<TeamSlot>? slots,
    DateTime?       createdAt,
    DateTime?       updatedAt,
  }) => TeamComposition(
    id:        id        ?? this.id,
    name:      name      ?? this.name,
    slots:     slots     ?? this.slots,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
