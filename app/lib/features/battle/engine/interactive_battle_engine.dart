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
  final List<BattleEvent> events;
  final bool isRoundComplete;

  const ActionStepResult({
    required this.action,
    required this.state,
    required this.log,
    required this.events,
    required this.isRoundComplete,
  });
}

enum BattleMode { pve, pvp }

class _RoundExecution {
  final BattleLogger logger;
  final List<Action> orderedActions;
  final Map<String, List<String>> cardChoices;
  final Map<String, Pet?> comboTargetByPetId;
  final Map<String, int> comboSizeByPetId;
  final String? lastActorId;
  final List<({bool classChainActive, Set<String> activeChainFamilies})>
      chainContexts;
  // PvP: enemy card instance IDs played this round — so finishRound can discard them.
  final List<String> enemyPlayedCards;
  int actionIndex;

  _RoundExecution({
    required this.logger,
    required this.orderedActions,
    required this.cardChoices,
    required this.comboTargetByPetId,
    required this.comboSizeByPetId,
    required this.lastActorId,
    required this.chainContexts,
    List<String>? enemyPlayedCards,
  })  : actionIndex = 0,
        enemyPlayedCards = enemyPlayedCards ?? [];
}

/// Interactive wrapper around the battle engine that processes one round at a time.
///
/// Skill draw integration:
///   - Each team owns a 24-card [SkillDeck] (3 pets × 4 traits × 2 copies).
///   - The player's hand is drawn at construction and after each executeRound().
///   - Enemy AI draws and selects from its own hand during executeRound().
///   - [currentPlayerHand] always reflects the live hand the UI should display.
///
/// Phase 2 (PvP):
///   Replace [_buildAiActions] with submitted Firestore actions.
///   The deck system remains identical for both sides.
class InteractiveBattleEngine {
  static const int bloodMoonStartRound = 10;
  static const int bloodMoonBaseDamage = 20;
  static const int bloodMoonDamageStep = 10;

  final List<Pet> playerTeam;
  final List<Pet> enemyTeam;
  final String playerTeamName;
  final String enemyTeamName;
  final BattleMode mode;

  final AiController _ai = AiController();
  final TurnManager _turns = TurnManager();
  int _round = 0;

  // PvP: set by the provider when a round:locked WS message arrives.
  Map<String, List<String>>? _opponentChoices;

  static const int maxRounds = 30;

  late final SkillDeck _playerDeck;
  late final SkillDeck _enemyDeck;
  late final Random _critRng;
  final PitySentinel _playerPity = PitySentinel();
  final PitySentinel _enemyPity = PitySentinel();

  final EnergyPool playerEnergy = EnergyPool();
  final EnergyPool enemyEnergy = EnergyPool();
  _RoundExecution? _roundExecution;
  Map<String, Trait> _roundTraitsByPetId = const {};

  // Tracks how many cards each pet has played in the current round for combo bonus.
  final Map<String, int> _roundComboCount = {};

  InteractiveBattleEngine({
    required this.playerTeam,
    required this.enemyTeam,
    required this.playerTeamName,
    required this.enemyTeamName,
    int? battleSeed,
    // PvP: pass explicit deck seeds so both clients draw identical cards.
    // Derive these from battleSeed + player identity (see PvpBattleNotifier).
    int? playerDeckSeed,
    int? enemyDeckSeed,
    this.mode = BattleMode.pve,
  }) {
    final seed = battleSeed ?? Random().nextInt(0xFFFFFF);
    _critRng = Random(seed ^ 0xC47F);
    _playerDeck = SkillDeck.fromTeam(playerTeam, seed: playerDeckSeed ?? seed);
    _enemyDeck = SkillDeck.fromTeam(enemyTeam, seed: enemyDeckSeed ?? (seed ^ 0x5A3C));

    // Link every pet to its team's shared energy pool.
    for (final p in playerTeam) {
      p.linkPool(playerEnergy);
    }
    for (final p in enemyTeam) {
      p.linkPool(enemyEnergy);
    }

    // Initial deal: 6 cards each (only happens once at battle start).
    _drawAliveOnly(_playerDeck, count: 6);
    _playerPity.update(_playerDeck.hand, _livePetIds(playerTeam));

    _drawAliveOnly(_enemyDeck, count: 6);
    _enemyPity.update(_enemyDeck.hand, _livePetIds(enemyTeam));
  }

  int get round => _round;
  bool get isOver => _checkWin() != null || _round >= maxRounds;
  bool get isBloodMoonRound => _round >= bloodMoonStartRound;
  int get currentBloodMoonDamage =>
      bloodMoonBaseDamage + ((_round - bloodMoonStartRound) * bloodMoonDamageStep);

  /// Current player hand — cards the UI should display this turn.
  List<SkillCard> get currentPlayerHand => _playerDeck.hand;
  int get playerDeckDrawSize => _playerDeck.drawPileSize;
  int get playerDeckDiscardSize => _playerDeck.discardPileSize;
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

    _roundComboCount.clear(); // reset combo counter each round

    // ── Status phase ──────────────────────────────────────────────────────
    logger.phase('Status Phase');
    for (final pet in [...playerTeam, ...enemyTeam]) {
      if (!pet.isFainted) pet.processStatusEffects(logger);
    }
    final midWin = _checkWin();
    if (midWin != null) {
      for (final pet in [...playerTeam, ...enemyTeam]) {
        pet.shield = 0;
      }
      return RoundStartResult(
        immediateResult: _buildResult(logger, midWin),
        actionQueue: const [],
      );
    }

    // ── Build actions ─────────────────────────────────────────────────────
    final playerActions = _buildPlayerActions(cardChoices);
    final List<Action> opponentActions;
    final List<String> enemyPlayed;

    if (mode == BattleMode.pvp) {
      final result = _buildEnemyActionsFromChoices(_opponentChoices ?? {});
      opponentActions = result.$1;
      enemyPlayed = result.$2;
      _opponentChoices = null;
    } else {
      opponentActions = _buildAiActions();
      enemyPlayed = [];
    }

    logger.phase('Action Phase');
    final ordered = _turns.buildResolutionOrder(playerActions, opponentActions);
    final resolver = ActionResolver(
      logger,
      rng: _critRng,
      roundTraitsByPetId: _roundTraitsByPetId,
      onDrawCard: _handleDrawCard,
    );
    _roundTraitsByPetId = {
      for (final action in ordered) action.actor.id: action.trait,
    };
    final comboTargetByPetId =
        resolver.precomputeComboTargets(ordered, playerTeam, enemyTeam);
    final comboSizeByPetId = <String, int>{};
    for (final action in ordered) {
      comboSizeByPetId[action.actor.id] =
          (comboSizeByPetId[action.actor.id] ?? 0) + 1;
    }
    final chainContexts =
        resolver.precomputeChainContexts(ordered, playerTeam, enemyTeam);
    final lastActorId = ordered.isNotEmpty ? ordered.last.actor.id : null;

    final frozenChoices = {
      for (final e in cardChoices.entries) e.key: List<String>.from(e.value),
    };

    _roundExecution = _RoundExecution(
      logger: logger,
      orderedActions: ordered,
      cardChoices: frozenChoices,
      comboTargetByPetId: comboTargetByPetId,
      comboSizeByPetId: comboSizeByPetId,
      lastActorId: lastActorId,
      chainContexts: chainContexts,
      enemyPlayedCards: enemyPlayed,
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

    final actionIndex = execution.actionIndex;
    final action = execution.orderedActions[actionIndex];
    execution.actionIndex++;
    final chainContext = execution.chainContexts[actionIndex];
    final logger = execution.logger;
    final prevEventCount = logger.events.length;
    final resolver = ActionResolver(
      logger,
      rng: _critRng,
      roundTraitsByPetId: _roundTraitsByPetId,
      onDrawCard: _handleDrawCard,
    );

    if (!action.actor.isFainted) {
        if (action.actor.isStunned || action.actor.isFeared || action.actor.isDisabled) {
          if (action.actor.isStunned) {
            logger.stunSkip(action.actor.name);
            action.actor.removeDebuff(DebuffType.stunned);
          } else if (action.actor.isFeared) {
            logger.debuff(action.actor.name, 'fear', 0, 1);
            action.actor.removeDebuff(DebuffType.fear);
          } else {
            logger.debuff(action.actor.name, 'disabled', 0, 1);
            action.actor.removeDebuff(DebuffType.disabled);
          }
        } else {
        final petId = action.actor.id;
        final comboIndex = _roundComboCount[petId] ?? 0;
        _roundComboCount[petId] = comboIndex + 1;
        resolver.resolve(
          action,
          _teamOf(action.actor),
          _enemyTeamOf(action.actor),
          comboIndex: comboIndex,
          roundTraitsByPetId: _roundTraitsByPetId,
          comboTarget: execution.comboTargetByPetId[petId],
          actorComboSize: execution.comboSizeByPetId[petId] ?? 1,
          isLastActor: petId == execution.lastActorId,
          isClassChainActive: chainContext.classChainActive,
          activeChainFamilies: chainContext.activeChainFamilies,
        );
      }
    }

    final isRoundComplete =
        execution.actionIndex >= execution.orderedActions.length;
    return ActionStepResult(
      action: action,
      state: BattleState.fromLive(
        round: _round,
        teamA: playerTeam,
        teamB: enemyTeam,
        roundLog: logger.transcript,
      ),
      log: logger.transcript,
      events: List<BattleEvent>.unmodifiable(
        logger.events.sublist(prevEventCount),
      ),
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
    // ── Discard used enemy cards (PvP — AI already discards during _buildAiActions) ──
    for (final instanceId in execution.enemyPlayedCards) {
      _enemyDeck.play(instanceId);
    }
    if (mode == BattleMode.pvp) {
      _enemyPity.injectIfNeeded(_enemyDeck, enemyTeam);
      _drawAliveOnly(_enemyDeck);
      _enemyPity.update(_enemyDeck.hand, _livePetIds(enemyTeam));
    }

    // ── Prepare player's next hand ────────────────────────────────────────
    _playerPity.injectIfNeeded(_playerDeck, playerTeam);
    _drawAliveOnly(_playerDeck);
    _playerPity.update(_playerDeck.hand, _livePetIds(playerTeam));

    // ── Round-end status + shield cleanup ──────────────────────────────────
    if (_round >= bloodMoonStartRound) {
      final damage = currentBloodMoonDamage;
      logger.bloodMoon(_round, damage);
      for (final pet in [...playerTeam, ...enemyTeam]) {
        if (pet.isFainted) continue;
        pet.takeDamage(damage, ignoreShield: true, ignoreLastStand: true);
        logger.damage(pet.name, damage, pet.hp);
        if (pet.isFainted) logger.fainted(pet.name);
      }
    }

    for (final pet in [...playerTeam, ...enemyTeam]) {
      if (!pet.isFainted) pet.tickRoundDurations();
    }

    // Shields are round-scoped in Classic: they do not carry into next round.
    // New shields must be earned each round by selecting shield cards.
    for (final pet in [...playerTeam, ...enemyTeam]) {
      pet.shield = 0;
    }

    _applyEndOfRoundDrawTriggers();

    logger.roundEnd();
    final result = _buildResult(logger, _checkWin());
    _roundExecution = null;
    _roundTraitsByPetId = const {};
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

  /// PvP only: supply the opponent's card selections before calling prepareRound.
  /// Called by PvpBattleNotifier when a `round:locked` WS message arrives.
  void setOpponentChoices(Map<String, List<String>> choices) {
    _opponentChoices = Map.of(choices);
  }

  bool get playerHandOverCap => false;

  void _handleDrawCard(String petId) {
    final isPlayer = playerTeam.any((p) => p.id == petId);
    final deck = isPlayer ? _playerDeck : _enemyDeck;
    _drawAliveOnly(deck, count: 1);
    _playerPity.update(_playerDeck.hand, _livePetIds(playerTeam));
    _enemyPity.update(_enemyDeck.hand, _livePetIds(enemyTeam));
  }

  void _applyEndOfRoundDrawTriggers() {
    for (final pet in [...playerTeam, ...enemyTeam]) {
      final trait = _roundTraitsByPetId[pet.id];
      if (trait == null) continue;
      if (trait.tags.contains('draw_if_shield_not_break') && pet.shield > 0) {
        _handleDrawCard(pet.id);
      }
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Pet? _lockedDamageTarget({
    required Pet actor,
    required Trait trait,
    required List<Pet> actorTeam,
    required List<Pet> enemyTeam,
  }) {
    if (trait.effect.type != EffectType.damage) return null;

    final alive = enemyTeam.where((p) => !p.isFainted).toList();
    if (alive.isEmpty) return null;

    if (trait.tags.contains('target_fastest_enemy')) {
      final fastest = [...alive]..sort((a, b) => b.effectiveSpeed.compareTo(a.effectiveSpeed));
      return _visibleFirst(fastest);
    }
    if (trait.tags.contains('skip_targets_in_last_stand')) {
      final filtered = alive.where((p) => !p.isInLastStand).toList();
      if (filtered.isNotEmpty) return _visibleFirst(filtered);
    }
    return switch (trait.effect.target) {
      'back_enemy'      => alive.last,
      'furthest_enemy'  => alive.last,
      'lowest_hp_enemy' => _visibleFirst(
          [...alive]..sort((a, b) => a.hp.compareTo(b.hp)),
        ),
      'enemy'           => _closestEnemyForLane(actor, actorTeam, enemyTeam),
      _ => null,
    };
  }

  Pet _closestEnemyForLane(Pet actor, List<Pet> actorTeam, List<Pet> enemyTeam) {
    final enemyFront = enemyTeam.isNotEmpty ? enemyTeam[0] : null;
    if (enemyFront != null && !enemyFront.isFainted) {
      return _visibleFirst([enemyFront]);
    }

    final enemyMid =
        enemyTeam.length > 1 && !enemyTeam[1].isFainted ? enemyTeam[1] : null;
    final enemyBack =
        enemyTeam.length > 2 && !enemyTeam[2].isFainted ? enemyTeam[2] : null;

    if (enemyMid != null && enemyBack != null) {
      final actorLane = actorTeam.indexWhere((p) => p.id == actor.id);
      if (actorLane == 1) return _visibleFirst([enemyMid, enemyBack]);
      if (actorLane == 2) return _visibleFirst([enemyBack, enemyMid]);

      final chooseMidFirst = _deterministicMidLaneChoice(actor, enemyMid, enemyBack);
      return chooseMidFirst
          ? _visibleFirst([enemyMid, enemyBack])
          : _visibleFirst([enemyBack, enemyMid]);
    }

    if (enemyMid != null) return _visibleFirst([enemyMid]);
    if (enemyBack != null) return _visibleFirst([enemyBack]);
    return _visibleFirst(enemyTeam.where((p) => !p.isFainted).toList());
  }

  bool _deterministicMidLaneChoice(Pet actor, Pet mid, Pet back) {
    final key = '${actor.id}|${mid.id}|${back.id}';
    var hash = 0;
    for (final code in key.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    return hash.isEven;
  }

  /// Returns the first non-Stench, non-Fainted pet; Aroma pets take priority.
  /// Falls back to first alive pet if all are Stench (target must be someone).
  Pet _visibleFirst(List<Pet> alive) {
    final aroma = alive.where((p) => p.isAromatized && !p.isFainted).toList();
    if (aroma.isNotEmpty) return aroma.first;
    final visible = alive.where((p) => !p.isStenched && !p.isFainted).toList();
    return visible.isNotEmpty ? visible.first : alive.first;
  }

  List<Action> _buildPlayerActions(Map<String, List<String>> cardChoices) {
    final actions = <Action>[];
    for (final pet in playerTeam) {
      if (pet.isFainted) continue;
      final instanceIds = cardChoices[pet.id];
      if (instanceIds == null || instanceIds.isEmpty) continue;
      for (final instanceId in instanceIds) {
        final trait = _resolveCardChoice(pet, instanceId);
        if (trait != null) {
          actions.add(Action(
            actor: pet,
            trait: trait,
            primaryTarget: _lockedDamageTarget(
              actor: pet,
              trait: trait,
              actorTeam: playerTeam,
              enemyTeam: enemyTeam,
            ),
          ));
        }
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

  /// PvP: build enemy actions from opponent's submitted card choices.
  /// Returns (actions, played card instance IDs) so finishRound can discard them.
  (List<Action>, List<String>) _buildEnemyActionsFromChoices(
      Map<String, List<String>> choices) {
    final actions = <Action>[];
    final played = <String>[];
    for (final pet in enemyTeam) {
      if (pet.isFainted) continue;
      final instanceIds = choices[pet.id];
      if (instanceIds == null || instanceIds.isEmpty) continue;
      for (final instanceId in instanceIds) {
        final trait = _enemyDeck.hand
            .where((c) =>
                c.instanceId == instanceId &&
                c.ownerPetId == pet.id &&
                c.trait.isReady &&
                pet.canAfford(c.trait.energyCost))
            .firstOrNull
            ?.trait;
        if (trait != null) {
          actions.add(Action(
            actor: pet,
            trait: trait,
            primaryTarget: _lockedDamageTarget(
              actor: pet,
              trait: trait,
              actorTeam: enemyTeam,
              enemyTeam: playerTeam,
            ),
          ));
          played.add(instanceId);
        }
      }
    }
    return (actions, played);
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
      actions.add(Action(
        actor: pet,
        trait: trait,
        primaryTarget: _lockedDamageTarget(
          actor: pet,
          trait: trait,
          actorTeam: enemyTeam,
          enemyTeam: playerTeam,
        ),
      ));
    }

    // Discard enemy's used cards, then draw next enemy hand.
    for (final id in usedCards) {
      _enemyDeck.play(id);
    }
    _enemyPity.injectIfNeeded(_enemyDeck, enemyTeam);
    _drawAliveOnly(_enemyDeck);
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
    double bestScore = -999;
    for (final card in available) {
      final score = _aiScoreTrait(card.trait, actor);
      if (score > bestScore) {
        bestScore = score;
        best = card;
      }
    }
    return best;
  }

  double _aiScoreTrait(Trait t, Pet actor) {
    final e = t.effect;
    if (e.type == EffectType.heal) {
      return enemyTeam.any((p) => !p.isFainted && p.hp / kBaseHp < 0.4)
          ? 90
          : 20;
    }
    if (e.debuffType == DebuffType.stunned) {
      return playerTeam.any((p) => !p.isFainted && !p.isStunned) ? 80 : 5;
    }
    if (e.type == EffectType.shield && actor.hp < kBaseHp * 0.4) return 75;
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
      events: List.of(logger.events),
      log: logger.transcript,
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

  List<Pet> _teamOf(Pet p) => playerTeam.contains(p) ? playerTeam : enemyTeam;
  List<Pet> _enemyTeamOf(Pet p) =>
      playerTeam.contains(p) ? enemyTeam : playerTeam;

  /// Draw cards exactly as the deck provides them.
  ///
  /// Classic behavior keeps cards from fainted pets in the cycle/hand until
  /// played or discarded by normal deck flow.
  void _drawAliveOnly(SkillDeck deck, {int count = SkillDeck.kDrawPerTurn}) {
    deck.drawTurn(count);
  }

  List<String> _livePetIds(List<Pet> pets) =>
      pets.where((p) => !p.isFainted).map((p) => p.id).toList();
}
