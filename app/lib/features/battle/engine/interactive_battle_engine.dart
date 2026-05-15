import 'dart:math';
import 'package:likha_pet_battle_engine/action.dart';
import 'package:likha_pet_battle_engine/action_resolver.dart';
import 'package:likha_pet_battle_engine/ai_controller.dart';
import 'package:likha_pet_battle_engine/battle_engine.dart';
import 'package:likha_pet_battle_engine/battle_logger.dart';
import 'package:likha_pet_battle_engine/battle_state.dart';
import 'package:likha_pet_battle_engine/energy_pool.dart';
import 'package:likha_pet_battle_engine/pet.dart';
import 'package:likha_pet_battle_engine/pity_sentinel.dart';
import 'package:likha_pet_battle_engine/skill_card.dart';
import 'package:likha_pet_battle_engine/skill_deck.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import 'package:likha_pet_battle_engine/turn_manager.dart';

/// Result of one resolved round.
class RoundResult {
  final BattleState state;
  final BattleOutcome? outcome; // null = battle ongoing
  final List<BattleEvent> events;
  final String log;

  const RoundResult({
    required this.state,
    required this.outcome,
    required this.events,
    required this.log,
  });

  bool get isBattleOver => outcome != null;
}

/// Result of preparing a round for step-by-step action resolution.
class RoundStartResult {
  final RoundResult? immediateResult;
  final List<Action> actionQueue;

  const RoundStartResult({
    required this.immediateResult,
    required this.actionQueue,
  });

  bool get hasImmediateResult => immediateResult != null;
}

/// Result of resolving one action from the prepared queue.
class ActionStepResult {
  final Action action;
  final BattleState state;
  final String log;
  final bool isRoundComplete;

  const ActionStepResult({
    required this.action,
    required this.state,
    required this.log,
    required this.isRoundComplete,
  });
}

class _RoundExecution {
  final BattleLogger logger;
  final List<Action> orderedActions;
  final Map<String, List<String>> cardChoices;
  int actionIndex;

  _RoundExecution({
    required this.logger,
    required this.orderedActions,
    required this.cardChoices,
  }) : actionIndex = 0;
}

/// Interactive wrapper around the battle engine that processes one round at a time.
///
/// Skill draw integration:
///   - Each team owns an 18-card [SkillDeck] (3 pets × 3 traits × 2 copies).
///   - The player's hand is drawn at construction and after each executeRound().
///   - Enemy AI draws and selects from its own hand during executeRound().
///   - [currentPlayerHand] always reflects the live hand the UI should display.
///
/// Phase 2 (PvP):
///   Replace [_buildAiActions] with submitted Firestore actions.
///   The deck system remains identical for both sides.
class InteractiveBattleEngine {
  final List<Pet> playerTeam;
  final List<Pet> enemyTeam;
  final String playerTeamName;
  final String enemyTeamName;

  final AiController _ai    = AiController();
  final TurnManager  _turns = TurnManager();
  int _round = 0;

  static const int maxRounds = 30;

  late final SkillDeck _playerDeck;
  late final SkillDeck _enemyDeck;
  final PitySentinel _playerPity = PitySentinel();
  final PitySentinel _enemyPity  = PitySentinel();

  final EnergyPool playerEnergy = EnergyPool();
  final EnergyPool enemyEnergy  = EnergyPool();
  _RoundExecution? _roundExecution;

  InteractiveBattleEngine({
    required this.playerTeam,
    required this.enemyTeam,
    required this.playerTeamName,
    required this.enemyTeamName,
    int? battleSeed,
  }) {
    final seed = battleSeed ?? Random().nextInt(0xFFFFFF);
    _playerDeck = SkillDeck.fromTeam(playerTeam, seed: seed);
    _enemyDeck  = SkillDeck.fromTeam(enemyTeam,  seed: seed ^ 0x5A3C);

    // Link every pet to its team's shared energy pool.
    for (final p in playerTeam) { p.linkPool(playerEnergy); }
    for (final p in enemyTeam)  { p.linkPool(enemyEnergy); }

    // Initial deal: 6 cards each (only happens once at battle start).
    _playerDeck.drawTurn(6);
    _playerPity.update(_playerDeck.hand, _livePetIds(playerTeam));

    _enemyDeck.drawTurn(6);
    _enemyPity.update(_enemyDeck.hand, _livePetIds(enemyTeam));
  }

  int get round => _round;
  bool get isOver => _checkWin() != null || _round >= maxRounds;

  /// Current player hand — cards the UI should display this turn.
  List<SkillCard> get currentPlayerHand => _playerDeck.hand;
  int get playerDeckDrawSize             => _playerDeck.drawPileSize;
  int get playerDeckDiscardSize          => _playerDeck.discardPileSize;
  bool get hasPendingActions =>
      _roundExecution != null &&
      _roundExecution!.actionIndex < _roundExecution!.orderedActions.length;

  // ── Execute one round ─────────────────────────────────────────────────────

  /// Prepare one round for step-by-step execution.
  ///
  /// Returns either:
  ///   - [RoundStartResult.immediateResult] when status effects already ended battle
  ///   - [RoundStartResult.actionQueue] to be resolved via [executeNextAction]
  RoundStartResult prepareRound(Map<String, List<String>> cardChoices) {
    if (_roundExecution != null) {
      throw StateError('Round is already in progress. Call finishRound first.');
    }

    _round++;
    final logger = BattleLogger();
    logger.roundBanner(_round);

    // ── Status phase ──────────────────────────────────────────────────────
    logger.phase('Status Phase');
    for (final pet in [...playerTeam, ...enemyTeam]) {
      if (!pet.isFainted) pet.processStatusEffects(logger);
    }
    final midWin = _checkWin();
    if (midWin != null) {
      for (final pet in [...playerTeam, ...enemyTeam]) { pet.shield = 0; }
      return RoundStartResult(
        immediateResult: _buildResult(logger, midWin),
        actionQueue: const [],
      );
    }

    // ── Build actions ─────────────────────────────────────────────────────
    final playerActions = _buildPlayerActions(cardChoices);
    final aiActions     = _buildAiActions();

    logger.phase('Action Phase');
    final ordered = _turns.buildResolutionOrder(playerActions, aiActions);
    final frozenChoices = {
      for (final e in cardChoices.entries) e.key: List<String>.from(e.value),
    };

    _roundExecution = _RoundExecution(
      logger: logger,
      orderedActions: ordered,
      cardChoices: frozenChoices,
    );

    return RoundStartResult(
      immediateResult: null,
      actionQueue: List<Action>.unmodifiable(ordered),
    );
  }

  /// Resolve the next action from the prepared queue.
  ActionStepResult executeNextAction() {
    final execution = _roundExecution;
    if (execution == null) {
      throw StateError('No prepared round. Call prepareRound first.');
    }
    if (execution.actionIndex >= execution.orderedActions.length) {
      throw StateError('No pending actions. Call finishRound.');
    }

    final action = execution.orderedActions[execution.actionIndex++];
    final logger = execution.logger;
    final resolver = ActionResolver(logger);

    if (!action.actor.isFainted) {
      if (action.actor.isStunned) {
        logger.stunSkip(action.actor.name);
        action.actor.debuffs.removeWhere((d) => d.type == DebuffType.stunned);
      } else {
        resolver.resolve(
          action,
          _teamOf(action.actor),
          _enemyTeamOf(action.actor),
        );
      }
    }

    final isRoundComplete = execution.actionIndex >= execution.orderedActions.length;
    return ActionStepResult(
      action: action,
      state: BattleState.fromLive(
        round: _round,
        teamA: playerTeam,
        teamB: enemyTeam,
        roundLog: logger.transcript,
      ),
      log: logger.transcript,
      isRoundComplete: isRoundComplete,
    );
  }

  /// Finalize bookkeeping after all queued actions were resolved.
  RoundResult finishRound() {
    final execution = _roundExecution;
    if (execution == null) {
      throw StateError('No prepared round. Call prepareRound first.');
    }

    final logger = execution.logger;

    // ── Energy regen AFTER spending — accumulates into the next round ─────
    playerEnergy.regen();
    enemyEnergy.regen();

    // ── Discard used player cards ─────────────────────────────────────────
    for (final ids in execution.cardChoices.values) {
      for (final instanceId in ids) {
        _playerDeck.play(instanceId);
      }
    }

    // ── Prepare player's next hand ────────────────────────────────────────
    _playerPity.injectIfNeeded(_playerDeck, playerTeam);
    _playerDeck.drawTurn();
    _playerPity.update(_playerDeck.hand, _livePetIds(playerTeam));

    // ── Shields are round-scoped: reset to 0 at the end of every round ────
    // New shields must be earned each round by selecting shield cards.
    // This also ensures the opponent's shield is hidden during card selection.
    for (final pet in [...playerTeam, ...enemyTeam]) {
      pet.shield = 0;
    }

    logger.roundEnd();
    final result = _buildResult(logger, _checkWin());
    _roundExecution = null;
    return result;
  }

  /// [cardChoices] maps each living player pet's id → one or more cardInstanceIds
  /// to play this round.  A pet may play multiple cards if the team has enough
  /// energy.  Missing entries mean the pet waits (no energy spent).
  RoundResult executeRound(Map<String, List<String>> cardChoices) {
    final started = prepareRound(cardChoices);
    if (started.hasImmediateResult) {
      return started.immediateResult!;
    }
    while (hasPendingActions) {
      executeNextAction();
    }
    return finishRound();
  }

  /// All traits for a player pet (including on-cooldown ones — UI shows why).
  List<Trait> traitsFor(Pet pet) => pet.traits;

  /// Manually discard a card from the player's hand (overflow handling).
  void discardFromPlayerHand(String instanceId) =>
      _playerDeck.discardCard(instanceId);

  bool get playerHandOverCap =>
      _playerDeck.handSize > SkillDeck.kHandLimit;

  // ── Private ───────────────────────────────────────────────────────────────

  List<Action> _buildPlayerActions(Map<String, List<String>> cardChoices) {
    final actions = <Action>[];
    for (final pet in playerTeam) {
      if (pet.isFainted) continue;
      final instanceIds = cardChoices[pet.id];
      if (instanceIds == null || instanceIds.isEmpty) continue;
      for (final instanceId in instanceIds) {
        final trait = _resolveCardChoice(pet, instanceId);
        if (trait != null) actions.add(Action(actor: pet, trait: trait));
      }
    }
    return actions;
  }

  /// Returns the trait for an assigned card, or null if the card is
  /// invalid (not in hand, on cooldown, or team can't afford it).
  Trait? _resolveCardChoice(Pet pet, String cardInstanceId) {
    return _playerDeck.hand
        .where((c) =>
            c.instanceId == cardInstanceId &&
            c.ownerPetId == pet.id &&
            c.trait.isReady &&
            pet.canAfford(c.trait.energyCost))
        .firstOrNull
        ?.trait;
  }

  List<Action> _buildAiActions() {
    // Enemy pity + draw are done at the end of the previous round (or at init).
    // Here we just let the AI pick from whatever is in its hand.
    final usedCards = <String>[];

    final actions = <Action>[];
    for (final pet in enemyTeam) {
      if (pet.isFainted) continue;

      final card = _aiSelectCard(pet);
      Trait trait;
      if (card != null) {
        trait = card.trait;
        usedCards.add(card.instanceId);
      } else {
        trait = _ai.selectTrait(pet, enemyTeam, playerTeam);
      }
      actions.add(Action(actor: pet, trait: trait));
    }

    // Discard enemy's used cards, then draw next enemy hand.
    for (final id in usedCards) {
      _enemyDeck.play(id);
    }
    _enemyPity.injectIfNeeded(_enemyDeck, enemyTeam);
    _enemyDeck.drawTurn();
    _enemyPity.update(_enemyDeck.hand, _livePetIds(enemyTeam));

    return actions;
  }

  SkillCard? _aiSelectCard(Pet actor) {
    final available = _enemyDeck
        .handFor(actor.id)
        .where((c) => c.trait.isReady && actor.canAfford(c.trait.energyCost))
        .toList();
    if (available.isEmpty) return null;

    SkillCard? best;
    double     bestScore = -999;
    for (final card in available) {
      final score = _aiScoreTrait(card.trait, actor);
      if (score > bestScore) { bestScore = score; best = card; }
    }
    return best;
  }

  double _aiScoreTrait(Trait t, Pet actor) {
    final e = t.effect;
    if (e.type == EffectType.heal) {
      return enemyTeam.any((p) => !p.isFainted && p.hp / kBaseHp < 0.4) ? 90 : 20;
    }
    if (e.debuffType == DebuffType.stunned) {
      return playerTeam.any((p) => !p.isFainted && !p.isStunned) ? 80 : 5;
    }
    if (e.type == EffectType.shield && actor.hp < kBaseHp * 0.4) return 75;
    if (e.type == EffectType.aoe) {
      return playerTeam.where((p) => !p.isFainted).length >= 2 ? 65 : 30;
    }
    if (e.type == EffectType.buff && e.target == 'all_allies') {
      return enemyTeam.any((p) => p.buffs.isNotEmpty) ? 15 : 55;
    }
    if (e.type == EffectType.damage) return e.value.toDouble();
    return 10;
  }

  RoundResult _buildResult(BattleLogger logger, BattleOutcome? outcome) {
    return RoundResult(
      state: BattleState.fromLive(
        round: _round,
        teamA: playerTeam,
        teamB: enemyTeam,
        roundLog: logger.transcript,
      ),
      outcome: outcome,
      events:  List.of(logger.events),
      log:     logger.transcript,
    );
  }

  BattleOutcome? _checkWin() {
    final aAlive = playerTeam.any((p) => !p.isFainted);
    final bAlive = enemyTeam.any((p) => !p.isFainted);
    if (!aAlive && !bAlive) return BattleOutcome.draw;
    if (!aAlive) return BattleOutcome.teamBWins;
    if (!bAlive) return BattleOutcome.teamAWins;
    return null;
  }

  List<Pet> _teamOf(Pet p)      => playerTeam.contains(p) ? playerTeam : enemyTeam;
  List<Pet> _enemyTeamOf(Pet p) => playerTeam.contains(p) ? enemyTeam  : playerTeam;

  List<String> _livePetIds(List<Pet> pets) =>
      pets.where((p) => !p.isFainted).map((p) => p.id).toList();
}
