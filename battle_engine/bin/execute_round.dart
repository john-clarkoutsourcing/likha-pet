/// Server-side PvP battle round executor.
///
/// Receives complete team state and selections.
/// Simulates one full round: calculates turn order, applies actions, updates pet states.
/// Returns new pet states and winner if battle is complete.
///
/// Input format:
/// {
///   "seed": 1234567890,
///   "roundNumber": 1,
///   "playerATeam": [
///     { "uid": "pet-id-1", "name": "Pet 1", "hp": 150, "maxHp": 150, "shield": 0, 
///       "spd": 43, "def": 20, "mor": 10, "skl": 25, "isFainted": false },
///     ...
///   ],
///   "playerBTeam": [...],
///   "playerASelections": { "pet-id-1": ["skill-name"], "pet-id-2": ["skill-name"] },
///   "playerBSelections": { ... }
/// }
///
/// Output format:
/// {
///   "success": true,
///   "roundNumber": 1,
///   "turnOrder": [
///     { "uid": "pet-id-1", "name": "Pet 1", "team": "A", "action": "attack", 
///       "damage": 25, "target": "pet-id-4", "targetTeam": "B" },
///     ...
///   ],
///   "playerATeamAfter": [ { ...updated pet state... } ],
///   "playerBTeamAfter": [ { ...updated pet state... } ],
///   "battleComplete": false,
///   "winnerTeam": null
/// }

import 'dart:io';
import 'dart:convert';
import 'dart:math';

void main() async {
  try {
    final input = await stdin.transform(utf8.decoder).join();
    final json = jsonDecode(input) as Map<String, dynamic>;
    final result = executeRound(json);
    print(jsonEncode(result));
  } catch (e, st) {
    final error = {
      'success': false,
      'error': e.toString(),
      'stackTrace': st.toString(),
    };
    print(jsonEncode(error));
    exit(1);
  }
}

Map<String, dynamic> executeRound(Map<String, dynamic> input) {
  final seed = input['seed'] as int? ?? 0;
  final roundNumber = input['roundNumber'] as int;
  
  final rng = Random(seed + roundNumber); // Deterministic per round

  // Parse teams
  final playerATeamJson = (input['playerATeam'] as List<dynamic>).cast<Map<String, dynamic>>();
  final playerBTeamJson = (input['playerBTeam'] as List<dynamic>).cast<Map<String, dynamic>>();
  
  final playerASelections = input['playerASelections'] as Map<String, dynamic>? ?? {};
  final playerBSelections = input['playerBSelections'] as Map<String, dynamic>? ?? {};

  // Convert to mutable Pet objects
  final teamA = playerATeamJson.map((p) => Pet.fromJson(p)).toList();
  final teamB = playerBTeamJson.map((p) => Pet.fromJson(p)).toList();

  // Calculate turn order
  final turnOrder = _calculateTurnOrder(teamA, teamB);

  // Execute actions in turn order
  final actions = <Map<String, dynamic>>[];
  for (final turn in turnOrder) {
    if (turn.pet.isFainted) continue; // Skip fainted pets

    final selections = turn.team == 'A' ? playerASelections : playerBSelections;
    final petUid = turn.pet.uid;
    final selectedActions = selections[petUid] as List<dynamic>? ?? [];
    
    if (selectedActions.isEmpty) continue; // No action this turn

    final actionName = selectedActions[0] as String? ?? 'attack';
    
    // For now, simple attack action (can extend with skill system later)
    final targetTeam = turn.team == 'A' ? teamB : teamA;
    final target = targetTeam.firstWhere(
      (p) => !p.isFainted,
      orElse: () => targetTeam.first,
    );

    // Calculate damage (placeholder: 20-30 range)
    final baseDamage = 25 + rng.nextInt(6) - 3; // 22-28 range
    final damage = max(1, baseDamage - (target.def ~/ 3)); // Simple defense reduction

    // Apply damage
    target.takeDamage(damage);

    actions.add({
      'uid': turn.pet.uid,
      'name': turn.pet.name,
      'team': turn.team,
      'action': actionName,
      'damage': damage,
      'target': target.uid,
      'targetTeam': turn.team == 'A' ? 'B' : 'A',
    });

    // Check if target fainted
    if (target.hp <= 0) {
      target.isFainted = true;
    }
  }

  // Check battle completion (all pets on one team fainted)
  final allAFainted = teamA.every((p) => p.isFainted);
  final allBFainted = teamB.every((p) => p.isFainted);

  String? winnerTeam;
  if (allAFainted && !allBFainted) {
    winnerTeam = 'B';
  } else if (allBFainted && !allAFainted) {
    winnerTeam = 'A';
  } else if (allAFainted && allBFainted) {
    winnerTeam = 'draw'; // Both teams wiped
  }

  return {
    'success': true,
    'roundNumber': roundNumber,
    'turnOrder': actions,
    'playerATeamAfter': teamA.map((p) => p.toJson()).toList(),
    'playerBTeamAfter': teamB.map((p) => p.toJson()).toList(),
    'battleComplete': winnerTeam != null,
    'winnerTeam': winnerTeam,
  };
}

class Pet {
  final String uid;
  final String name;
  int hp;
  final int maxHp;
  int shield;
  final int spd;
  final int def;
  final int mor;
  final int skl;
  bool isFainted;

  Pet({
    required this.uid,
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.shield,
    required this.spd,
    required this.def,
    required this.mor,
    required this.skl,
    required this.isFainted,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      uid: json['uid'] as String,
      name: json['name'] as String,
      hp: (json['hp'] as num).toInt(),
      maxHp: (json['maxHp'] as num).toInt(),
      shield: (json['shield'] as num?)?.toInt() ?? 0,
      spd: (json['spd'] as num).toInt(),
      def: (json['def'] as num?)?.toInt() ?? 20,
      mor: (json['mor'] as num?)?.toInt() ?? 10,
      skl: (json['skl'] as num?)?.toInt() ?? 20,
      isFainted: json['isFainted'] as bool? ?? false,
    );
  }

  void takeDamage(int amount) {
    final shieldAbsorbed = min(shield, amount);
    shield -= shieldAbsorbed;
    final remaining = amount - shieldAbsorbed;
    hp -= remaining;
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    'hp': hp,
    'maxHp': maxHp,
    'shield': shield,
    'spd': spd,
    'def': def,
    'mor': mor,
    'skl': skl,
    'isFainted': isFainted,
  };
}

class _TurnEntry {
  final Pet pet;
  final String team;
  final int spd;
  final int mor;
  final int skl;

  _TurnEntry({
    required this.pet,
    required this.team,
    required this.spd,
    required this.mor,
    required this.skl,
  });
}

List<_TurnEntry> _calculateTurnOrder(List<Pet> teamA, List<Pet> teamB) {
  final allPets = <_TurnEntry>[];

  for (final pet in teamA) {
    allPets.add(_TurnEntry(
      pet: pet,
      team: 'A',
      spd: pet.spd,
      mor: pet.mor,
      skl: pet.skl,
    ));
  }

  for (final pet in teamB) {
    allPets.add(_TurnEntry(
      pet: pet,
      team: 'B',
      spd: pet.spd,
      mor: pet.mor,
      skl: pet.skl,
    ));
  }

  // Sort by speed (highest first), then morale, skill, UID
  allPets.sort((a, b) {
    final speedDiff = b.spd.compareTo(a.spd);
    if (speedDiff != 0) return speedDiff;

    final moraleDiff = b.mor.compareTo(a.mor);
    if (moraleDiff != 0) return moraleDiff;

    final skillDiff = b.skl.compareTo(a.skl);
    if (skillDiff != 0) return skillDiff;

    return a.pet.uid.compareTo(b.pet.uid);
  });

  return allPets;
}
