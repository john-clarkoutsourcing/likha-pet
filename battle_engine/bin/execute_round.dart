/// Simple turn order calculator for server-side PvP synchronization.
/// 
/// Receives JSON input on stdin with team speeds.
/// Outputs turn order based on speed stats.
///
/// Input format:
/// {
///   "seed": 1234567890,
///   "roundNumber": 1,
///   "playerATeam": [
///     { "uid": "pet-id-1", "name": "Pet 1", "spd": 43 },
///     ...
///   ],
///   "playerBTeam": [...],
///   "playerASelection": { "traitName": "skill-name", "targetIndex": 1 },
///   "playerBSelection": { "traitName": "skill-name", "targetIndex": 0 }
/// }

import 'dart:io';
import 'dart:convert';

void main() async {
  try {
    final input = await stdin.transform(utf8.decoder).join();
    final json = jsonDecode(input) as Map<String, dynamic>;
    final result = calculateTurnOrder(json);
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

Map<String, dynamic> calculateTurnOrder(Map<String, dynamic> input) {
  final roundNumber = input['roundNumber'] as int;
  
  // Parse teams
  final playerATeamJson = (input['playerATeam'] as List<dynamic>).cast<Map<String, dynamic>>();
  final playerBTeamJson = (input['playerBTeam'] as List<dynamic>).cast<Map<String, dynamic>>();

  // Create list of all pets with their team info
  final allPets = <Map<String, dynamic>>[];
  
  for (int i = 0; i < playerATeamJson.length; i++) {
    final pet = playerATeamJson[i];
    allPets.add({
      'uid': pet['uid'],
      'name': pet['name'],
      'spd': pet['spd'] ?? 30,
      'team': 'A',
      'index': i,
      'originalOrder': allPets.length,
    });
  }

  for (int i = 0; i < playerBTeamJson.length; i++) {
    final pet = playerBTeamJson[i];
    allPets.add({
      'uid': pet['uid'],
      'name': pet['name'],
      'spd': pet['spd'] ?? 30,
      'team': 'B',
      'index': i,
      'originalOrder': allPets.length,
    });
  }

  // Sort by speed (highest first), then by morale, skill, and UID
  allPets.sort((a, b) {
    // Primary: Speed (descending)
    final speedDiff = (b['spd'] as int).compareTo(a['spd'] as int);
    if (speedDiff != 0) return speedDiff;

    // Secondary: Morale (descending)
    final moraleDiff = (b['mor'] as int? ?? 20).compareTo(a['mor'] as int? ?? 20);
    if (moraleDiff != 0) return moraleDiff;

    // Tertiary: Skill (descending)
    final skillDiff = (b['skl'] as int? ?? 20).compareTo(a['skl'] as int? ?? 20);
    if (skillDiff != 0) return skillDiff;

    // Quaternary: UID (lexicographic for determinism)
    return (a['uid'] as String).compareTo(b['uid'] as String);
  });

  // Convert to output format
  final turnOrder = allPets.map((pet) => {
    'uid': pet['uid'],
    'name': pet['name'],
    'index': pet['index'],
  }).toList();

  return {
    'success': true,
    'roundNumber': roundNumber,
    'turnOrder': turnOrder,
    'battleComplete': false,  // Placeholder - server would track actual state
  };
}
