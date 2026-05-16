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
    TraitLibrary.beastHorn,
    TraitLibrary.beastBack,
    TraitLibrary.beastTail,
    TraitLibrary.beastMouth,
    TraitLibrary.plantHorn,
    TraitLibrary.plantBack,
    TraitLibrary.aquaticHorn,
    TraitLibrary.aquaticMouth,
    TraitLibrary.birdBack,
    TraitLibrary.birdMouth,
    TraitLibrary.bugHorn,
    TraitLibrary.reptileBack,
  ];

  print('${'═' * 60}');
  print(' LIKHA PET — Trait Reference (${allTraits.length} traits)');
  print('═' * 60);

  const typeLabels = {
    TraitType.offensive: '⚔  Offensive',
    TraitType.defensive: '🛡  Defensive',
    TraitType.support: '💚 Support  ',
    TraitType.utility: '⚡ Utility  ',
  };

  for (final trait in allTraits) {
    final typeLabel = typeLabels[trait.type]!;
    print('  [$typeLabel]  ${trait.name.padRight(22)} ${ts.describe(trait)}');
  }
  print('${'═' * 60}\n');
}

// ── Battle simulation ─────────────────────────────────────────────────────────

void _runBattle() {
  // ── Team A ────────────────────────────────────────────────────────────────
  final beast = Pet(
    id: 'pet_001',
    name: 'Beast',
    traits: [
      TraitLibrary.beastHorn,
      TraitLibrary.beastBack,
      TraitLibrary.beastTail,
    ],
  );

  final plant = Pet(
    id: 'pet_002',
    name: 'Plant',
    traits: [
      TraitLibrary.plantHorn,
      TraitLibrary.plantBack,
      TraitLibrary.plantTail,
    ],
  );

  final aquatic = Pet(
    id: 'pet_003',
    name: 'Aquatic',
    traits: [
      TraitLibrary.aquaticHorn,
      TraitLibrary.aquaticTail,
      TraitLibrary.aquaticMouth,
    ],
  );

  // ── Team B ────────────────────────────────────────────────────────────────
  final bird = Pet(
    id: 'pet_004',
    name: 'Bird',
    traits: [
      TraitLibrary.birdHorn,
      TraitLibrary.birdBack,
      TraitLibrary.birdTail,
    ],
  );

  final bug = Pet(
    id: 'pet_005',
    name: 'Bug',
    traits: [
      TraitLibrary.bugHorn,
      TraitLibrary.bugBack,
      TraitLibrary.bugTail,
    ],
  );

  final reptile = Pet(
    id: 'pet_006',
    name: 'Reptile',
    traits: [
      TraitLibrary.reptileHorn,
      TraitLibrary.reptileBack,
      TraitLibrary.reptileTail,
    ],
  );

  // ── Run ───────────────────────────────────────────────────────────────────

  final engine = BattleEngine(
    teamA: [beast, plant, aquatic],
    teamB: [bird, bug, reptile],
    teamAName: 'Team Alpha',
    teamBName: 'Team Beta',
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
