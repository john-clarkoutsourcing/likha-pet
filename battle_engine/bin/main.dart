import '../lib/pet.dart';
import '../lib/trait.dart';
import '../lib/trait_system.dart';
import '../lib/battle_engine.dart';

void main() {
  _printTraitReference();
  _runBattle();
}

// ── Trait reference ───────────────────────────────────────────────────────────

void _printTraitReference() {
  final ts = TraitSystem();

  final allTraits = [
    TraitLibrary.tikbalangCharge,
    TraitLibrary.bakunawaSwallow,
    TraitLibrary.aswangFang,
    TraitLibrary.anakngLupaSlam,
    TraitLibrary.lakanCounter,
    TraitLibrary.amihanVeil,
    TraitLibrary.bayanihanShield,
    TraitLibrary.sarimanokAura,
    TraitLibrary.diwataBlessing,
    TraitLibrary.manananggalDrain,
    TraitLibrary.kapreSmoke,
    TraitLibrary.enkantoFlash,
  ];

  print('${'═' * 60}');
  print(' LIKHA PET — Trait Reference (${allTraits.length} traits)');
  print('═' * 60);

  const typeLabels = {
    TraitType.offensive: '⚔  Offensive',
    TraitType.defensive: '🛡  Defensive',
    TraitType.support:   '💚 Support  ',
    TraitType.utility:   '⚡ Utility  ',
  };

  for (final trait in allTraits) {
    final typeLabel = typeLabels[trait.type]!;
    print('  [$typeLabel]  ${trait.name.padRight(22)} ${ts.describe(trait)}');
  }
  print('${'═' * 60}\n');
}

// ── Battle simulation ─────────────────────────────────────────────────────────

void _runBattle() {
  // ── Team Bayani (Aggressive / CC-heavy) ──────────────────────────────────
  //
  // Bakunawa:   Burst single-target + stun (high-value CC opener)
  // Tikbalang:  Cheap spam + AoE to hit multiple targets
  // Manananggal: Poison pressure + team defense buff

  final bakunawa = Pet(
    id: 'pet_001',
    name: 'Bakunawa',
    traits: [
      TraitLibrary.aswangFang,        // 45 dmg, 3E, CD:2 — heavy hitter
      TraitLibrary.enkantoFlash,      // Stun, 3E, CD:3  — CC opener
      TraitLibrary.tikbalangCharge,   // 30 dmg, 1E, CD:0 — cheap filler
    ],
  );

  final tikbalang = Pet(
    id: 'pet_002',
    name: 'Tikbalang',
    traits: [
      TraitLibrary.anakngLupaSlam,    // AoE 25, 3E, CD:2
      TraitLibrary.tikbalangCharge,   // 30 dmg, 1E, CD:0
      TraitLibrary.kapreSmoke,        // AoE attackDown, 2E, CD:3
    ],
  );

  final manananggal = Pet(
    id: 'pet_003',
    name: 'Manananggal',
    traits: [
      TraitLibrary.manananggalDrain,  // Poison 8/round×3, 2E, CD:2
      TraitLibrary.bayanihanShield,   // All-ally defenseUp +15, 3E, CD:3
      TraitLibrary.amihanVeil,        // Self shield 40, 2E, CD:3
    ],
  );

  // ── Team Diwata (Balanced / Support-heavy) ────────────────────────────────
  //
  // Diwata:    Full-team healer + self-defense
  // Sarimanok: Single-target heal + burst damage
  // Amihan:    Poison + AoE to mirror Team Bayani's pressure

  final diwata = Pet(
    id: 'pet_004',
    name: 'Diwata',
    traits: [
      TraitLibrary.diwataBlessing,    // All-ally heal 20, 2E, CD:3
      TraitLibrary.lakanCounter,      // Self defenseUp +15, 1E, CD:2
      TraitLibrary.tikbalangCharge,   // 30 dmg, 1E, CD:0
    ],
  );

  final sarimanok = Pet(
    id: 'pet_005',
    name: 'Sarimanok',
    traits: [
      TraitLibrary.sarimanokAura,     // Heal lowest-HP ally 35, 2E, CD:3
      TraitLibrary.bakunawaSwallow,   // 50 dmg lowest-HP enemy, 2E, CD:1
      TraitLibrary.amihanVeil,        // Self shield 40, 2E, CD:3
    ],
  );

  final amihan = Pet(
    id: 'pet_006',
    name: 'Amihan',
    traits: [
      TraitLibrary.manananggalDrain,  // Poison 8/round×3, 2E, CD:2
      TraitLibrary.anakngLupaSlam,    // AoE 25, 3E, CD:2
      TraitLibrary.bayanihanShield,   // All-ally defenseUp +15, 3E, CD:3
    ],
  );

  // ── Run ───────────────────────────────────────────────────────────────────

  final engine = BattleEngine(
    teamA: [bakunawa, tikbalang, manananggal],
    teamB: [diwata, sarimanok, amihan],
    teamAName: 'Team Bayani',
    teamBName: 'Team Diwata',
  );

  final result = engine.run();

  // ── Output ────────────────────────────────────────────────────────────────

  print(result.log);

  // Post-battle summary
  print('${'─' * 60}');
  print(' Post-Battle Summary');
  print('─' * 60);
  print('  Outcome    : ${result.outcome.name}');
  print('  Rounds     : ${result.totalRounds}');
  print('  Log events : ${result.events.length}');
  print('  State snaps: ${result.stateHistory.length}');

  // Show final state from history
  if (result.stateHistory.isNotEmpty) {
    final last = result.stateHistory.last;
    print('\n  Final pet states:');
    for (final p in [...last.teamA, ...last.teamB]) {
      final status = p.isFainted ? 'FAINTED' : 'HP:${p.hp}/${p.maxHp}';
      print('    ${p.name.padRight(14)} $status');
    }
  }

  // Event type breakdown
  print('\n  Event breakdown:');
  final eventCounts = <String, int>{};
  for (final e in result.events) {
    final key = e.runtimeType.toString();
    eventCounts[key] = (eventCounts[key] ?? 0) + 1;
  }
  for (final entry in eventCounts.entries) {
    print('    ${entry.key.padRight(22)}: ${entry.value}');
  }
  print('${'─' * 60}');
}
