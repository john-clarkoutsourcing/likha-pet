import 'dart:math';
import 'pet.dart';
import 'trait.dart';
import 'action_resolver.dart';
import 'ai_controller.dart';
import 'turn_manager.dart';
import 'battle_logger.dart';
import 'battle_state.dart';

const int kMaxRounds = 30;
const int kBloodMoonStartRound = 10;
const int kBloodMoonBaseDamage = 20;
const int kBloodMoonDamageStep = 10;

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
  late final Random _rng;

  BattleEngine({
    required this.teamA,
    required this.teamB,
    this.teamAName = 'Team A',
    this.teamBName = 'Team B',
    int? seed,
  }) {
    _rng = Random(seed);
  }

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
      final resolver   = ActionResolver(_logger, rng: _rng);
      final ordered    = _turns.buildResolutionOrder(slotsA, slotsB);
      final roundTraitsByPetId = {
        for (final action in ordered) action.actor.id: action.trait,
      };

      // Axie combo-lock: pre-compute the locked target for each actor ONCE,
      // before any card fires. All enemy-facing damage cards from the same actor
      // this round will hit this target (fallback on death via _resolveTarget).
      final comboTargetByPetId =
          resolver.precomputeComboTargets(ordered, teamA, teamB);

      // Total cards each actor plays this round — used for "3+ card combo" effects.
      final comboSizeByPetId = <String, int>{};
      for (final a in ordered) {
        comboSizeByPetId[a.actor.id] = (comboSizeByPetId[a.actor.id] ?? 0) + 1;
      }

      // The pet whose last action is last in the ordered list acts last this round.
      // Used for 'bonus_if_acts_last' (Prickly Trap).
      final lastActorId = ordered.isNotEmpty ? ordered.last.actor.id : null;

      final comboCount = <String, int>{}; // petId → cards played this round

      for (final action in ordered) {
        if (action.actor.isFainted) continue;

        if (action.actor.isStunned || action.actor.isFeared || action.actor.isDisabled) {
          if (action.actor.isStunned) {
            _logger.stunSkip(action.actor.name);
            action.actor.removeDebuff(DebuffType.stunned);
          } else if (action.actor.isFeared) {
            _logger.debuff(action.actor.name, 'fear', 0, 1);
            action.actor.removeDebuff(DebuffType.fear);
          } else {
            _logger.debuff(action.actor.name, 'disabled', 0, 1);
            action.actor.removeDebuff(DebuffType.disabled);
          }
          continue;
        }

        final petId      = action.actor.id;
        final comboIndex = comboCount[petId] ?? 0;
        comboCount[petId] = comboIndex + 1;
        resolver.resolve(
          action,
          _teamOf(action.actor),
          _enemyTeamOf(action.actor),
          comboIndex:        comboIndex,
          roundTraitsByPetId: roundTraitsByPetId,
          comboTarget:       comboTargetByPetId[petId],
          actorComboSize:    comboSizeByPetId[petId] ?? 1,
          isLastActor:       petId == lastActorId,
        );
      }

      // ── Phase 5: Blood Moon sudden-death damage ─────────────────────────
      if (round >= kBloodMoonStartRound) {
        final bloodMoonDamage =
            kBloodMoonBaseDamage + ((round - kBloodMoonStartRound) * kBloodMoonDamageStep);
        _logger.bloodMoon(round, bloodMoonDamage);
        for (final pet in [...teamA, ...teamB]) {
          if (pet.isFainted) continue;
          pet.takeDamage(bloodMoonDamage, ignoreShield: true, ignoreLastStand: true);
          _logger.damage(pet.name, bloodMoonDamage, pet.hp);
          if (pet.isFainted) {
            _logger.fainted(pet.name);
          }
        }

        final bloodMoonWin = _checkWin();
        if (bloodMoonWin != null) {
          _captureState(round, '(battle ended during blood moon phase)');
          _announceWinner(bloodMoonWin, round);
          return _buildResult(bloodMoonWin, round);
        }
      }

      // ── Phase 6: End-of-round bookkeeping ─────────────────────────────────
      _logger.phase('End of Round $round');
      
      // Track which pets played cards this round (for Last Stand idle ticks)
      final petsThatActed = <String>{};
      for (final action in ordered) {
        if (!action.actor.isStunned && !action.actor.isFeared && !action.actor.isDisabled) {
          petsThatActed.add(action.actor.id);
        }
      }
      
      for (final pet in [...teamA, ...teamB]) {
        if (!pet.isFainted) {
          // If in Last Stand and didn't act this round, consume 1 idle tick
          if (pet.isInLastStand && !petsThatActed.contains(pet.id)) {
            pet.lastStandTicks = (pet.lastStandTicks - 1).clamp(0, 999);
            if (pet.lastStandTicks <= 0) {
              pet.hp = 0;
              pet.isFainted = true;
              _logger.fainted(pet.name);
            }
          }
          pet.tickRoundDurations();
        }
        pet.shield = 0; // Classic-style: shield does not carry to next round.
      }
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
