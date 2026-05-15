import 'pet.dart';
import 'trait.dart';
import 'action_resolver.dart';
import 'ai_controller.dart';
import 'turn_manager.dart';
import 'battle_logger.dart';
import 'battle_state.dart';

const int kMaxRounds = 30;

// ── Outcome ───────────────────────────────────────────────────────────────────

enum BattleOutcome { teamAWins, teamBWins, draw }

// ── Result ────────────────────────────────────────────────────────────────────

/// The complete output of a finished battle.
///
/// Firebase/PvP integration:
///   The Cloud Function returns BattleResult.outcome and writes it to
///   battles/{id}.outcome. Clients read outcome from onSnapshot.
///
/// PvE validation:
///   The client POSTs outcome + totalRounds to pveValidateResult CF.
///   The CF re-runs BattleEngine with the same inputs and compares.
///
/// Flutter UI:
///   BattleResultScreen displays outcome and totalRounds.
///   RoundLogPanel plays back events[] for animated replay.
///   stateHistory[] feeds a future "round replay" scrubber feature.
class BattleResult {
  final BattleOutcome outcome;
  final int totalRounds;

  /// Full human-readable transcript of the battle.
  final String log;

  /// Typed event stream for Flutter animation.
  /// One event per significant game moment (damage, heal, faint, etc.).
  final List<BattleEvent> events;

  /// One snapshot per completed round. Index 0 = state after round 1.
  /// Used for PvE replay validation and a future "rewind" feature.
  final List<BattleState> stateHistory;

  const BattleResult({
    required this.outcome,
    required this.totalRounds,
    required this.log,
    required this.events,
    required this.stateHistory,
  });
}

// ── Engine ────────────────────────────────────────────────────────────────────

/// Orchestrates a complete 3v3 battle from start to finish.
///
/// Usage:
///   final engine = BattleEngine(teamA: [...], teamB: [...], ...);
///   final result = engine.run();
///
/// The engine is NOT reusable after run() completes — create a new instance
/// for each battle.
///
/// PvP mode:
///   The Cloud Function instantiates BattleEngine with team snapshots from
///   Firestore and calls run() after both players have submitted actions.
///
/// PvE mode:
///   PveBattleNotifier (Flutter) instantiates BattleEngine locally and calls
///   run(). The result is submitted to the validation CF for reward granting.
///
/// Architecture invariant:
///   BattleEngine never calls Firebase, never imports Flutter, and has no
///   side effects beyond mutating the Pet objects passed in.
class BattleEngine {
  final List<Pet> teamA;
  final List<Pet> teamB;
  final String teamAName;
  final String teamBName;

  final BattleLogger _logger = BattleLogger();
  final TurnManager _turns = TurnManager();
  final AiController _ai = AiController();
  final List<BattleState> _history = [];

  BattleEngine({
    required this.teamA,
    required this.teamB,
    this.teamAName = 'Team A',
    this.teamBName = 'Team B',
  });

  BattleResult run() {
    _logger.separator();
    _logger.header('LIKHA PET BATTLE');
    _logger.header('$teamAName  vs  $teamBName');
    _logger.separator();
    _printTeamStatus();

    int round = 0;

    while (round < kMaxRounds) {
      round++;
      _logger.roundBanner(round);

      // ── Phase 1: Status effects tick ──────────────────────────────────────
      _logger.phase('Status Phase');
      for (final pet in [...teamA, ...teamB]) {
        if (!pet.isFainted) pet.processStatusEffects(_logger);
      }

      // Check for a win caused by poison damage
      final midRoundWin = _checkWin();
      if (midRoundWin != null) {
        _captureState(round, '(battle ended during status phase)');
        _announceWinner(midRoundWin, round);
        return _buildResult(midRoundWin, round);
      }

      // ── Phase 2: Energy regeneration ──────────────────────────────────────
      for (final pet in [...teamA, ...teamB]) {
        if (!pet.isFainted) pet.regenEnergy();
      }

      // ── Phase 3: AI selects actions for all living pets ───────────────────
      final slotsA = _turns.buildSlots(teamA, (p) => _ai.selectTrait(p, teamA, teamB));
      final slotsB = _turns.buildSlots(teamB, (p) => _ai.selectTrait(p, teamB, teamA));

      // ── Phase 4: Resolve actions in turn order ────────────────────────────
      _logger.phase('Action Phase');
      final resolver   = ActionResolver(_logger);
      final ordered    = _turns.buildResolutionOrder(slotsA, slotsB);
      final comboCount = <String, int>{}; // petId → cards played this round

      for (final action in ordered) {
        if (action.actor.isFainted) continue;

        if (action.actor.isStunned) {
          _logger.stunSkip(action.actor.name);
          action.actor.debuffs.removeWhere(
            (d) => d.type == DebuffType.stunned,
          );
          continue;
        }

        final petId      = action.actor.id;
        final comboIndex = comboCount[petId] ?? 0;
        comboCount[petId] = comboIndex + 1;
        resolver.resolve(
          action,
          _teamOf(action.actor),
          _enemyTeamOf(action.actor),
          comboIndex: comboIndex,
        );
      }

      // ── Phase 5: End-of-round bookkeeping ─────────────────────────────────
      _logger.phase('End of Round $round');
      _printTeamStatus();
      _logger.roundEnd();

      _captureState(round, _logger.transcript);

      final postRoundWin = _checkWin();
      if (postRoundWin != null) {
        _announceWinner(postRoundWin, round);
        return _buildResult(postRoundWin, round);
      }
    }

    // Max rounds reached
    _logger.draw(kMaxRounds);
    return _buildResult(BattleOutcome.draw, round);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _captureState(int round, String roundLog) {
    _history.add(BattleState.fromLive(
      round: round,
      teamA: teamA,
      teamB: teamB,
      roundLog: roundLog,
    ));
  }

  BattleOutcome? _checkWin() {
    final aAlive = teamA.any((p) => !p.isFainted);
    final bAlive = teamB.any((p) => !p.isFainted);
    if (!aAlive && !bAlive) return BattleOutcome.draw;
    if (!aAlive) return BattleOutcome.teamBWins;
    if (!bAlive) return BattleOutcome.teamAWins;
    return null;
  }

  void _announceWinner(BattleOutcome outcome, int round) {
    switch (outcome) {
      case BattleOutcome.teamAWins:
        _logger.winner(teamAName);
      case BattleOutcome.teamBWins:
        _logger.winner(teamBName);
      case BattleOutcome.draw:
        _logger.draw(round);
    }
  }

  BattleResult _buildResult(BattleOutcome outcome, int totalRounds) {
    return BattleResult(
      outcome: outcome,
      totalRounds: totalRounds,
      log: _logger.transcript,
      events: List.unmodifiable(_logger.events),
      stateHistory: List.unmodifiable(_history),
    );
  }

  List<Pet> _teamOf(Pet pet) => teamA.contains(pet) ? teamA : teamB;
  List<Pet> _enemyTeamOf(Pet pet) => teamA.contains(pet) ? teamB : teamA;

  void _printTeamStatus() {
    _logger.teamStatus(
      teamAName,
      teamA.map((p) => '${p.isFainted ? "✗" : "·"} $p').toList(),
    );
    _logger.teamStatus(
      teamBName,
      teamB.map((p) => '${p.isFainted ? "✗" : "·"} $p').toList(),
    );
  }
}
