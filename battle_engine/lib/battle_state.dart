import 'pet.dart';

/// Immutable snapshot of the complete battle state at the end of one round.
///
/// Firebase integration:
///   toJson() maps directly to the Firestore battles/{id}/state document.
///   The Cloud Function writes one BattleState per resolved round.
///   Both Flutter clients read it via a real-time onSnapshot listener.
///
/// PvE validation:
///   The server-side CF replays the battle and compares its stateHistory
///   against the client's submitted result to detect tampering.
class BattleState {
  final int round;
  final List<PetSnapshot> teamA;
  final List<PetSnapshot> teamB;
  final String roundLog;

  const BattleState({
    required this.round,
    required this.teamA,
    required this.teamB,
    required this.roundLog,
  });

  /// Build a snapshot from live Pet objects after a round resolves.
  factory BattleState.fromLive({
    required int round,
    required List<Pet> teamA,
    required List<Pet> teamB,
    required String roundLog,
  }) {
    return BattleState(
      round: round,
      teamA: teamA.map(PetSnapshot.fromLive).toList(),
      teamB: teamB.map(PetSnapshot.fromLive).toList(),
      roundLog: roundLog,
    );
  }

  /// Firestore-compatible JSON. Used by the Cloud Function state writer
  /// and by client-side PvE result submission.
  Map<String, dynamic> toJson() => {
    'round': round,
    'teamA': teamA.map((p) => p.toJson()).toList(),
    'teamB': teamB.map((p) => p.toJson()).toList(),
    'roundLog': roundLog,
  };
}

// ── Pet snapshot ──────────────────────────────────────────────────────────────

class PetSnapshot {
  final String id;
  final String name;
  final int hp;
  final int maxHp;
  final int energy;
  final int shield;
  final int morale;
  final int skill;
  final String creatureClassName; // 'beast' | 'plant' | 'aquatic' | etc.
  final bool isFainted;
  final bool isStunned;
  final bool isStenched;
  final List<DebuffSnapshot> debuffs;
  final List<BuffSnapshot> buffs;
  final Map<String, int> traitCooldowns;

  const PetSnapshot({
    required this.id,
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.energy,
    required this.shield,
    required this.morale,
    required this.skill,
    required this.creatureClassName,
    required this.isFainted,
    required this.isStunned,
    required this.isStenched,
    required this.debuffs,
    required this.buffs,
    required this.traitCooldowns,
  });

  factory PetSnapshot.fromLive(Pet pet) => PetSnapshot(
    id:    pet.id,
    name:  pet.name,
    hp:    pet.hp,
    maxHp: pet.maxHp,
    energy: pet.energy,
    shield: pet.shield,
    morale: pet.morale,
    skill:  pet.skill,
    creatureClassName: pet.creatureClass.name,
    isFainted: pet.isFainted,
    isStunned: pet.isStunned,
    isStenched: pet.isStenched,
    debuffs: pet.debuffs.map(DebuffSnapshot.fromLive).toList(),
    buffs:   pet.buffs.map(BuffSnapshot.fromLive).toList(),
    traitCooldowns: {
      for (final t in pet.traits) t.id: t.cooldownRemaining,
    },
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hp': hp,
    'maxHp': maxHp,
    'energy': energy,
    'shield': shield,
    'isFainted': isFainted,
    'isStunned': isStunned,
    'isStenched': isStenched,
    'debuffs': debuffs.map((d) => d.toJson()).toList(),
    'buffs': buffs.map((b) => b.toJson()).toList(),
    'traitCooldowns': traitCooldowns,
  };

  @override
  String toString() =>
      '$name [HP:$hp/$maxHp  E:$energy  Shld:$shield${isFainted ? " FAINTED" : ""}]';
}

// ── Status snapshots ──────────────────────────────────────────────────────────

class DebuffSnapshot {
  final String type;
  final int value;
  final int roundsRemaining;

  const DebuffSnapshot({
    required this.type,
    required this.value,
    required this.roundsRemaining,
  });

  factory DebuffSnapshot.fromLive(StatusEffect s) => DebuffSnapshot(
    type: s.type.name,
    value: s.value,
    roundsRemaining: s.roundsRemaining,
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'roundsRemaining': roundsRemaining,
  };
}

class BuffSnapshot {
  final String type;
  final int value;
  final int roundsRemaining;

  const BuffSnapshot({
    required this.type,
    required this.value,
    required this.roundsRemaining,
  });

  factory BuffSnapshot.fromLive(BuffEffect b) => BuffSnapshot(
    type: b.type.name,
    value: b.value,
    roundsRemaining: b.roundsRemaining,
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'roundsRemaining': roundsRemaining,
  };
}
