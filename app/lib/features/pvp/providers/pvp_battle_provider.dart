import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:likha_pet_battle_engine/action.dart';
import 'package:likha_pet_battle_engine/battle_engine.dart' show BattleOutcome;
import 'package:likha_pet_battle_engine/battle_state.dart';
import 'package:likha_pet_battle_engine/pet.dart';
import 'package:likha_pet_battle_engine/skill_card.dart';
import 'package:likha_pet_battle_engine/trait.dart';

import '../../../features/battle/data/creature_registry.dart';
import '../../../features/battle/engine/interactive_battle_engine.dart';
import '../../../features/battle/providers/battle_view_model.dart';
import '../../../features/battle/services/battle_audio_service.dart';
import '../../../features/battle/services/mixed_skeleton_service.dart';
import '../../../features/battle/widgets/pet_character_widget.dart'
    show PetCharacterAnimState, PetCharacterConfig;
import '../../../features/pets/models/owned_pet.dart';
import '../models/battle_action_log.dart';
import '../models/pvp_message.dart';
import '../services/pvp_socket.dart';
import '../services/authenticated_pvp_validation_service.dart';
import '../services/pvp_firestore_service.dart';

// ── Args ──────────────────────────────────────────────────────────────────────

class PvpBattleArgs {
  final PvpMatchFound matchFound;
  final List<OwnedPet> myTeam;
  const PvpBattleArgs({required this.matchFound, required this.myTeam});
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PvpBattleNotifier extends StateNotifier<PveBattleViewModel> {
  late final InteractiveBattleEngine _engine;
  late final List<Pet> _playerPets;
  late final List<Pet> _enemyPets;
  late final String _myUserId;
  late final String _opponentUserId;
  late final String _matchId;

  List<Offset> _playerBattlePos = const [
    Offset(0.30, 0.22),
    Offset(0.15, 0.03),
    Offset(0.10, 0.48),
  ];
  List<Offset> _enemyBattlePos = const [
    Offset(0.50, 0.22),
    Offset(0.65, 0.03),
    Offset(0.75, 0.48),
  ];

  final Map<String, ({String petId, int amount})> _preAppliedShields = {};
  final Map<String, PetCharacterConfig> _mixedSkeletonConfigs = {};
  final Map<String, CreatureDefinition> _petDefs = {};

  // ── Action logging for PvP validation ───────────────────────────────────
  final List<BattleActionLog> _actionLog = [];
  late final int _battleStartTime;
  late final AuthenticatedPvpValidationService _validationService;
  late final PvpFirestoreService _firestoreService;
  late final int _battleSeed;

  StreamSubscription<PvpMessage>? _wsSub;
  Completer<Map<String, List<String>>>? _opponentChoicesCompleter;
  PvpRoundLocked? _pendingRoundLocked;
  int? _awaitingRound;

  PvpBattleNotifier(
    PvpBattleArgs args, {
    required AuthenticatedPvpValidationService validationService,
  }) : super(PveBattleViewModel.initial()) {
    _validationService = validationService;
    final match = args.matchFound;
    _myUserId = match.you.userId;
    _opponentUserId = match.opponent.userId;
    _matchId = match.matchId;
    _battleSeed = match.seed;

    // Decode own team from OwnedPet list
    _playerPets = args.myTeam
        .where((p) => kBodyCatalogue.containsKey(p.bodyId))
        .map((p) => p.toCreatureDefinition().toPet(displayName: p.name))
        .toList();
    for (final p in args.myTeam) {
      _petDefs[p.uid] = p.toCreatureDefinition();
    }
    
    // 🔍 DIAGNOSTIC: Log own team stats
    print('═' * 60);
    print('[PvP Match ${match.matchId}] BATTLE STARTED');
    print('═' * 60);
    print('[PvP] My Team (${_playerPets.length} pets):');
    for (final pet in _playerPets) {
      print('  • ${pet.name} | ID: ${pet.id} | SPD: ${pet.effectiveSpeed} | HP: ${pet.maxHp} | SKL: ${pet.skill} | MOR: ${pet.morale}');
    }

    // Decode opponent team from server-provided DNA refs
    // Note: Server doesn't send pet names, so we use generic names based on position and class
    _enemyPets = match.opponent.team.asMap().entries.map((e) {
      final index = e.key;
      final ref = e.value;
      final owned = OwnedPet(
        uid: ref.uid,
        name: 'Opponent ${index + 1}', // Generic fallback name
        dna: ref.dna,
        createdAt: ref.createdAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(ref.createdAtMs!)
            : DateTime.now(), // Fallback if server doesn't provide it
      );
      if (kBodyCatalogue.containsKey(owned.bodyId)) {
        final def = owned.toCreatureDefinition();
        _petDefs[owned.uid] = def;
        // Use creature class name as display name for clarity
        return def.toPet(
            displayName: '${match.opponent.displayName}\'s ${def.className}');
      }
      // Fallback to a default pet if DNA is unrecognised
      return kCreatureRegistry.values.first.toPet();
    }).toList();
    
    // 🔍 DIAGNOSTIC: Log opponent team stats
    print('[PvP] Opponent Team (${_enemyPets.length} pets):');
    for (final pet in _enemyPets) {
      print('  • ${pet.name} | ID: ${pet.id} | SPD: ${pet.effectiveSpeed} | HP: ${pet.maxHp} | SKL: ${pet.skill} | MOR: ${pet.morale}');
    }
    print('═' * 60);

    // ── Deck seed assignment ──────────────────────────────────────────────────
    // Both clients must draw identical cards for the same logical team so that
    // card instance IDs submitted by one player are found in the other's deck.
    //
    // Rule: the player whose userId is lexicographically smaller ("alpha") uses
    //   playerDeck = seed,         enemyDeck = seed ^ 0x5A3C
    // The other player ("beta") uses the swapped assignment:
    //   playerDeck = seed ^ 0x5A3C, enemyDeck = seed
    //
    // Result: alpha._enemyDeck and beta._playerDeck share the same seed → same
    // instance IDs for beta's cards. Likewise for alpha's cards.
    final bool isAlpha = _myUserId.compareTo(_opponentUserId) < 0;
    final int playerDeckSeed = isAlpha ? match.seed : match.seed ^ 0x5A3C;
    final int enemyDeckSeed = isAlpha ? match.seed ^ 0x5A3C : match.seed;

    _engine = InteractiveBattleEngine(
      playerTeam: _playerPets,
      enemyTeam: _enemyPets,
      playerTeamName: 'You',
      playerDeckSeed: playerDeckSeed,
      enemyDeckSeed: enemyDeckSeed,
      enemyTeamName: match.opponent.displayName.isNotEmpty
          ? match.opponent.displayName
          : 'Opponent',
      battleSeed: match.seed,
      mode: BattleMode.pvp,
    );

    // Initialize action logging with provided validation service
    _battleStartTime = DateTime.now().millisecondsSinceEpoch;
    _firestoreService = PvpFirestoreService();

    // Subscribe to WS messages
    _wsSub = PvpSocket.instance.messages.listen(_onWsMessage);

    _initializeMixedSkeletons().then((_) {
      state = PveBattleViewModel(
        currentRound: 1,
        playerTeam: _toViewModels(_playerPets, isPlayer: true),
        enemyTeam: _toViewModels(_enemyPets, isPlayer: false),
        roundLog: '',
        isBattleOver: false,
        playerTeamName: 'You',
        enemyTeamName: match.opponent.displayName,
        turnOrder: _buildTurnOrder(),
        selectedPetId: null,
        pendingSkills: const {},
        hand: _buildHandVMs(_engine.currentPlayerHand, const {}),
        deckDrawSize: _engine.playerDeckDrawSize,
        deckDiscardSize: _engine.playerDeckDiscardSize,
        playerTeamEnergy: _engine.playerEnergy.energy,
        enemyTeamEnergy: _engine.enemyEnergy.energy,
      );
    }).catchError((_) {
      state = PveBattleViewModel(
        currentRound: 1,
        playerTeam: _toViewModels(_playerPets, isPlayer: true),
        enemyTeam: _toViewModels(_enemyPets, isPlayer: false),
        roundLog: '',
        isBattleOver: false,
        playerTeamName: 'You',
        enemyTeamName: match.opponent.displayName,
        turnOrder: _buildTurnOrder(),
        selectedPetId: null,
        pendingSkills: const {},
        hand: _buildHandVMs(_engine.currentPlayerHand, const {}),
        deckDrawSize: _engine.playerDeckDrawSize,
        deckDiscardSize: _engine.playerDeckDiscardSize,
        playerTeamEnergy: _engine.playerEnergy.energy,
        enemyTeamEnergy: _engine.enemyEnergy.energy,
      );
    });
  }

  // ── WS message handling ────────────────────────────────────────────────────

  void _onWsMessage(PvpMessage msg) {
    if (msg is PvpRoundLocked) {
      if (msg.matchId != _matchId) return;
      if (_awaitingRound != null && msg.round != _awaitingRound) {
        _pendingRoundLocked = msg;
        return;
      }
      final opponentSelections =
          msg.selections[_opponentUserId] ?? <String, List<String>>{};
      final waiter = _opponentChoicesCompleter;
      if (waiter != null && !waiter.isCompleted) {
        waiter.complete(opponentSelections);
        _opponentChoicesCompleter = null;
      } else {
        // round:locked can arrive before executeRound starts waiting.
        _pendingRoundLocked = msg;
      }
    } else if (msg is PvpMatchEnd) {
      state = state.copyWith(
        pvpMatchEnd: PvpMatchEndData(
          winnerUid: msg.winnerUid,
          dispute: msg.dispute,
          mmrDelta: msg.mmrDelta,
        ),
        isBattleOver: true,
        awaitingOpponent: false,
      );
    } else if (msg is PvpOpponentDisconnected) {
      // Optionally show a toast — for now just update round log
      state = state.copyWith(
        roundLog: '${state.roundLog}\nOpponent disconnected — waiting...',
      );
    }
  }

  // ── Player actions (same as PvE) ───────────────────────────────────────────

  void selectPet(String petId) {
    if (state.isBattleOver || state.isResolving) return;
    state = state.copyWith(selectedPetId: petId);
  }

  void clearSelectedPet() {
    if (state.isBattleOver || state.isResolving) return;
    state = state.copyWith(selectedPetId: null);
  }

  void setBattlePositions(
      {required List<Offset> playerPos, required List<Offset> enemyPos}) {
    if (playerPos.length < 3 || enemyPos.length < 3) return;
    _playerBattlePos = List<Offset>.from(playerPos);
    _enemyBattlePos = List<Offset>.from(enemyPos);
  }

  void assignSkill(String cardInstanceId) {
    if (state.isBattleOver || state.isResolving || state.needsDiscard) return;
    final card = _engine.currentPlayerHand
        .where((c) => c.instanceId == cardInstanceId)
        .firstOrNull;
    if (card == null) return;

    final petId = card.ownerPetId;
    final newPending =
        state.pendingSkills.map((k, v) => MapEntry(k, List<String>.from(v)));
    final currentList = List<String>.from(newPending[petId] ?? []);

    if (currentList.contains(cardInstanceId)) {
      currentList.remove(cardInstanceId);
      if (currentList.isEmpty) {
        newPending.remove(petId);
      } else {
        newPending[petId] = currentList;
      }
      _removePreAppliedShield(cardInstanceId);
      state = state.copyWith(
        pendingSkills: newPending,
        playerTeam: _livePlayerTeamVMs(),
        hand: _buildHandVMs(_engine.currentPlayerHand, newPending),
      );
      BattleAudioService.instance.playCardUnplay();
      return;
    }

    currentList.add(cardInstanceId);
    newPending[petId] = currentList;
    _applyPreShield(card);
    state = state.copyWith(
      pendingSkills: newPending,
      playerTeam: _livePlayerTeamVMs(),
      hand: _buildHandVMs(_engine.currentPlayerHand, newPending),
    );
    BattleAudioService.instance.playCardPlay();
  }

  void discardCard(String cardInstanceId) {
    _engine.discardFromPlayerHand(cardInstanceId);
    final newPending = state.pendingSkills.map(
      (k, v) => MapEntry(k, v.where((id) => id != cardInstanceId).toList()),
    )..removeWhere((_, v) => v.isEmpty);
    final hand = _buildHandVMs(_engine.currentPlayerHand, newPending);
    final excess = (_engine.currentPlayerHand.length - 10).clamp(0, 100);
    state = state.copyWith(
      hand: hand,
      pendingSkills: newPending,
      needsDiscard: excess > 0,
      excessDiscards: excess,
    );
  }

  // ── PvP round execution ────────────────────────────────────────────────────

  Future<void> executeRound() async {
    if (state.isResolving || state.isBattleOver || state.awaitingOpponent)
      return;

    final handBeforeIds = state.hand.map((c) => c.instanceId).toSet();
    final mySelections =
        state.pendingSkills.map((k, v) => MapEntry(k, List<String>.from(v)));
    final expectedRound = _engine.round + 1;

    state = state.copyWith(isResolving: true);

    // Prepare waiter before sending submit to avoid race with fast round:locked.
    final waiter = Completer<Map<String, List<String>>>();
    _opponentChoicesCompleter = waiter;
    _awaitingRound = expectedRound;

    final cached = _pendingRoundLocked;
    if (cached != null &&
        cached.matchId == _matchId &&
        cached.round == expectedRound &&
        !waiter.isCompleted) {
      waiter.complete(
          cached.selections[_opponentUserId] ?? <String, List<String>>{});
      _pendingRoundLocked = null;
    }

    // Submit this player's selections to the server
    PvpSocket.instance.send(OutRoundSubmit(
      matchId: _matchId,
      round: expectedRound,
      selections: mySelections,
    ).toJson());

    // Wait for the server to broadcast round:locked (opponent's selections)
    state = state.copyWith(awaitingOpponent: true);
    Map<String, List<String>> opponentSelections;
    try {
      // 70 s timeout (server is 60 s, give 10 s slack)
      opponentSelections = await waiter.future
          .timeout(const Duration(seconds: 70), onTimeout: () {
            print('[PvP] Round timeout - opponent did not submit in time, proceeding with empty selections');
            return {};
          });
    } catch (e) {
      print('[PvP] Error waiting for opponent: $e');
      opponentSelections = {};
    }
    _opponentChoicesCompleter = null;
    _awaitingRound = null;
    if (!mounted) return;
    
    if (opponentSelections.isEmpty) {
      print('[PvP] Opponent selections empty - proceeding with default choices');
    }
    
    state = state.copyWith(awaitingOpponent: false);

    // Feed opponent choices into engine, then run round
    _engine.setOpponentChoices(opponentSelections);
    final started = _engine.prepareRound(mySelections);
    
    // 🔍 DIAGNOSTIC: Log turn order for sync debugging
    if (started.hasImmediateResult) {
      final state = started.immediateResult!.state;
      print('[PvP] Round ${state.round} log: ${state.roundLog}');
    }

    if (started.hasImmediateResult) {
      final immediate = started.immediateResult!;
      state = state.copyWith(
        currentRound: immediate.state.round,
        playerTeam: _snapshotsToVMs(immediate.state.teamA, _playerPets),
        enemyTeam: _snapshotsToVMs(immediate.state.teamB, _enemyPets),
        roundLog: immediate.log,
        isBattleOver: immediate.isBattleOver,
        outcome: immediate.outcome?.name,
        turnOrder: _buildTurnOrder(),
        playerTeamEnergy: _engine.playerEnergy.energy,
        enemyTeamEnergy: _engine.enemyEnergy.energy,
        pendingSkills: const {},
        petAnimStates: const {},
        petEffectVfx: const {},
        isResolving: false,
      );
      if (immediate.isBattleOver)
        _sendClientResult(immediate.log, immediate.outcome);
      return;
    }

    // Resolve each action with the same animation pacing as PvE
    for (final action in started.actionQueue) {
      if (!mounted) return;
      final actorId = action.actor.id;

      // Log action for validation
      _logAction(
        round: _engine.round,
        actorId: actorId,
        actionName: action.trait.name,
        targetId: action.primaryTarget?.id,
        energyUsed: action.trait.energyCost,
        damageDealt: null, // Will be updated if damage is dealt
      );

      final isNoTargetDamageAction =
          action.trait.effect.type == EffectType.damage &&
              action.primaryTarget != null &&
              action.primaryTarget!.isFainted;
      final effectType = (action.trait.effect.type == EffectType.buff &&
              action.trait.effect.buffType == BuffType.regen)
          ? 'heal'
          : action.trait.effect.type.name;
      final partSlot = action.trait.part.name;

      if (!action.actor.isFainted && !isNoTargetDamageAction) {
        final isPlayerActor = _playerPets.any((p) => p.id == actorId);
        final opposingTeam = isPlayerActor ? _enemyPets : _playerPets;
        final isMeleeDash = action.trait.effect.type == EffectType.damage;
        Offset dashDir = Offset.zero;
        String? dashTargetId;

        if (isMeleeDash) {
          final actorIdx = (isPlayerActor
                  ? _playerPets.indexWhere((p) => p.id == actorId)
                  : _enemyPets.indexWhere((p) => p.id == actorId))
              .clamp(0, 2);
          final targetPet = _resolveEnemyTargetForDash(action, opposingTeam);
          final targetIdx = targetPet != null
              ? opposingTeam.indexWhere((p) => p.id == targetPet.id)
              : -1;
          if (targetIdx >= 0 && targetPet != null) {
            dashTargetId = targetPet.id;
            final actorBase = isPlayerActor
                ? _playerBattlePos[actorIdx]
                : _enemyBattlePos[actorIdx];
            final targetBase = isPlayerActor
                ? _enemyBattlePos[targetIdx]
                : _playerBattlePos[targetIdx];
            final toTarget = Offset(
                targetBase.dx - actorBase.dx, targetBase.dy - actorBase.dy);
            final distance = toTarget.distance;
            if (distance > 0.0001) {
              const minGap = 0.06;
              const maxDash = 0.22;
              final dashDistance =
                  math.min(maxDash, math.max(0.0, distance - minGap));
              dashDir = Offset(toTarget.dx / distance * dashDistance,
                  toTarget.dy / distance * dashDistance);
            }
            state = state.copyWith(
              petAnimStates: {actorId: PetCharacterAnimState.move},
              petAttackSlots: {actorId: partSlot},
              petDashOffsets: {actorId: dashDir},
              petDashTargets: {actorId: dashTargetId},
            );
            await Future.delayed(const Duration(milliseconds: 600));
            if (!mounted) return;
          }
        }

        state = state.copyWith(
          petAnimStates: {actorId: _animStateForEffect(effectType)},
          petEffectVfx: {actorId: effectType},
          petAttackSlots: {actorId: partSlot},
          petDashOffsets: isMeleeDash && dashDir != Offset.zero
              ? {actorId: dashDir}
              : const {},
          petDashTargets:
              isMeleeDash && dashDir != Offset.zero && dashTargetId != null
                  ? {actorId: dashTargetId}
                  : const {},
        );
        BattleAudioService.instance.playAttack(effectType);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
      }

      final preHp = <String, int>{
        for (final p in [..._playerPets, ..._enemyPets]) p.id: p.hp,
      };
      final preShield = <String, int>{
        for (final p in [..._playerPets, ..._enemyPets]) p.id: p.shield,
      };
      _undoPreShieldIfNeeded(action.actor, action.trait);

      final step = _engine.executeNextAction();
      state = state.copyWith(
        currentRound: step.state.round,
        playerTeam: _snapshotsToVMs(step.state.teamA, _playerPets),
        enemyTeam: _snapshotsToVMs(step.state.teamB, _enemyPets),
        roundLog: step.log,
        turnOrder: _buildTurnOrder(),
        playerTeamEnergy: _engine.playerEnergy.energy,
        enemyTeamEnergy: _engine.enemyEnergy.energy,
      );

      final battleFinishedNow = _playerPets.every((p) => p.isFainted) ||
          _enemyPets.every((p) => p.isFainted);
      if (battleFinishedNow) {
        state = state.copyWith(
          petAnimStates: const {},
          petEffectVfx: const {},
          petAttackSlots: const {},
          petDashOffsets: const {},
          petDashTargets: const {},
        );
        break;
      }

      if (isNoTargetDamageAction) {
        state = state.copyWith(
          petAnimStates: const {},
          petEffectVfx: const {},
          petAttackSlots: const {},
          petDashOffsets: const {},
          petDashTargets: const {},
        );
        continue;
      }

      final targetAnims = <String, PetCharacterAnimState>{};
      for (final p in [..._playerPets, ..._enemyPets]) {
        if (p.id == actorId) continue;
        final hpDelta = p.hp - (preHp[p.id] ?? p.hp);
        final shieldDelta = p.shield - (preShield[p.id] ?? p.shield);
        if (hpDelta < 0 || shieldDelta < 0) {
          targetAnims[p.id] = p.isFainted
              ? PetCharacterAnimState.faint
              : PetCharacterAnimState.hit;
        }
      }
      if (targetAnims.isNotEmpty) {
        final hasFaint =
            targetAnims.values.any((s) => s == PetCharacterAnimState.faint);
        BattleAudioService.instance.playHit(faint: hasFaint);
        state = state.copyWith(
          petAnimStates:
              Map<String, PetCharacterAnimState>.from(state.petAnimStates)
                ..addAll(targetAnims),
        );
      }

      await Future.delayed(
          Duration(milliseconds: action.actor.isFainted ? 250 : 700));
      if (!mounted) return;

      state = state.copyWith(
        petAnimStates: const {},
        petEffectVfx: const {},
        petAttackSlots: const {},
        petDashOffsets: const {},
        petDashTargets: const {},
      );
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
    }

    _preAppliedShields.clear();
    final result = _engine.finishRound();

    final faintedIds =
        _playerPets.where((p) => p.isFainted).map((p) => p.id).toSet();
    for (final card in List.of(_engine.currentPlayerHand)) {
      if (faintedIds.contains(card.ownerPetId))
        _engine.discardFromPlayerHand(card.instanceId);
    }

    state = state.copyWith(
      currentRound: result.state.round,
      playerTeam: _snapshotsToVMs(result.state.teamA, _playerPets),
      enemyTeam: _snapshotsToVMs(result.state.teamB, _enemyPets),
      roundLog: result.log,
      isBattleOver: result.isBattleOver,
      outcome: result.outcome?.name,
      turnOrder: _buildTurnOrder(),
      playerTeamEnergy: _engine.playerEnergy.energy,
      enemyTeamEnergy: _engine.enemyEnergy.energy,
      pendingSkills: const {},
      petAnimStates: const {},
      petEffectVfx: const {},
    );

    if (result.isBattleOver) {
      _sendClientResult(result.log, result.outcome);
      state = state.copyWith(isResolving: false);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final newHand = _buildHandVMs(_engine.currentPlayerHand, const {});
    final newIds =
        newHand.map((c) => c.instanceId).toSet().difference(handBeforeIds);
    state = state.copyWith(
      hand: newHand,
      deckDrawSize: _engine.playerDeckDrawSize,
      deckDiscardSize: _engine.playerDeckDiscardSize,
      newCardIds: newIds,
    );
    if (newIds.isNotEmpty) BattleAudioService.instance.playCardDraw();
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final excess = (_engine.currentPlayerHand.length - 10).clamp(0, 100);
    state = state.copyWith(
      isResolving: false,
      newCardIds: const {},
      needsDiscard: excess > 0,
      excessDiscards: excess,
    );
  }

  void _sendClientResult(String log, BattleOutcome? outcome) {
    final winnerUid = switch (outcome) {
      BattleOutcome.teamAWins => _myUserId,
      BattleOutcome.teamBWins => _opponentUserId,
      _ => _myUserId, // draw → treat as tie; server sees matching results
    };
    final checksum =
        sha256.convert(utf8.encode(log)).toString().substring(0, 16);
    PvpSocket.instance.send(OutClientResult(
      matchId: _matchId,
      winnerUid: winnerUid,
      transcriptChecksum: checksum,
    ).toJson());

    // Submit battle log for server-side validation (async, don't wait)
    _submitBattleValidation(outcome);
  }

  /// Log an action during battle for validation
  void _logAction({
    required int round,
    required String actorId,
    required String actionName,
    String? targetId,
    required int energyUsed,
    int? damageDealt,
  }) {
    _actionLog.add(BattleActionLog(
      round: round,
      actor: actorId,
      action: actionName,
      target: targetId,
      energyUsed: energyUsed,
      damageDealt: damageDealt,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Capture final team state for validation
  List<PetTeamSnapshot> _captureFinalTeamState(List<Pet> team) {
    return team.map((pet) {
      // Capture both debuffs and buffs as status effects
      final effects = <StatusEffectSnapshot>[];

      // Add debuffs
      for (final debuff in pet.debuffs) {
        effects.add(StatusEffectSnapshot(
          type: debuff.type.name.toLowerCase(),
          duration: debuff.roundsRemaining,
          value: debuff.value,
        ));
      }

      // Add buffs
      for (final buff in pet.buffs) {
        effects.add(StatusEffectSnapshot(
          type: buff.type.name.toLowerCase(),
          duration: buff.roundsRemaining,
          value: buff.value,
        ));
      }

      return PetTeamSnapshot(
        petId: pet.id,
        hp: pet.hp.clamp(0, 999),
        statusEffects: effects,
      );
    }).toList();
  }

  /// Submit battle for server validation
  Future<void> _submitBattleValidation(BattleOutcome? outcome) async {
    try {
      final battleDurationMs =
          DateTime.now().millisecondsSinceEpoch - _battleStartTime;

      final validationRequest = BattleValidationRequest(
        playerId: _myUserId,
        playerTeam: _playerPets.map((p) => p.id).toList(),
        opponentTeam: _enemyPets.map((p) => p.id).toList(),
        winner: outcome == BattleOutcome.teamAWins ? 'player' : 'opponent',
        finalPlayerTeamState: _captureFinalTeamState(_playerPets),
        finalOpponentTeamState: _captureFinalTeamState(_enemyPets),
        actionLog: _actionLog,
        battleDurationMs: battleDurationMs,
        randomSeed: _battleSeed,
      );

      // Store battle log in Firestore
      final battleId = _matchId; // Use match ID as battle ID
      await _firestoreService.storeBattleLog(
        battleId: battleId,
        playerId: _myUserId,
        opponentId: _opponentUserId,
        playerTeam: validationRequest.playerTeam,
        opponentTeam: validationRequest.opponentTeam,
        actionLog: _actionLog,
        finalPlayerTeamState: validationRequest.finalPlayerTeamState,
        finalOpponentTeamState: validationRequest.finalOpponentTeamState,
        battleDurationMs: battleDurationMs,
        randomSeed: _battleSeed,
      );

      // Submit validation (async - don't block UI)
      unawaited(
        _validationService
            .submitBattleValidation(validationRequest)
            .then((result) async {
          // Store validation result in Firestore (with proper error handling)
          await _firestoreService.storeValidationResult(
            battleId: battleId,
            playerId: _myUserId,
            response: result,
            validationDetails:
                'Result: ${result.result}, Reason: ${result.reason ?? 'none'}',
          );

          if (result.isAccepted) {
            // MMR updated, battle accepted
            print(
                '[PvP] Battle validation: ACCEPTED (MMR: +${result.mmrChange})');
          } else if (result.isSuspicious) {
            // Flagged for review but accepted
            print('[PvP] Battle validation: SUSPICIOUS (${result.reason})');
          } else {
            // Rejected - possible cheat detected
            print('[PvP] Battle validation: REJECTED (${result.reason})');
          }
        }).catchError((e) {
          print('[PvP] Validation submission or storage error: $e');
        }),
      );
    } catch (e) {
      print('[PvP] Error preparing validation request: $e');
    }
  }

  // ── Shield pre-application (mirrors PvE) ───────────────────────────────────

  int _shieldForCard(SkillCard card) {
    int amount = 0;
    if (card.trait.effect.type == EffectType.shield)
      amount += card.trait.effect.value;
    amount += card.trait.effect.selfShield;
    return amount.clamp(0, 999);
  }

  void _applyPreShield(SkillCard card) {
    final amount = _shieldForCard(card);
    if (amount <= 0) return;
    final pet = _playerPets.where((p) => p.id == card.ownerPetId).firstOrNull;
    if (pet == null || pet.isFainted) return;
    pet.applyShield(amount);
    _preAppliedShields[card.instanceId] =
        (petId: card.ownerPetId, amount: amount);
  }

  void _removePreAppliedShield(String instanceId) {
    final entry = _preAppliedShields.remove(instanceId);
    if (entry == null) return;
    final pet = _playerPets.where((p) => p.id == entry.petId).firstOrNull;
    if (pet != null) pet.shield = (pet.shield - entry.amount).clamp(0, 999);
  }

  void _undoPreShieldIfNeeded(Pet actor, Trait trait) {
    final isShieldAction =
        trait.effect.type == EffectType.shield || trait.effect.selfShield > 0;
    if (!isShieldAction) return;
    final keys = _preAppliedShields.entries
        .where((e) => e.value.petId == actor.id)
        .map((e) => e.key)
        .toList();
    int total = 0;
    for (final k in keys) {
      total += _preAppliedShields.remove(k)!.amount;
    }
    if (total > 0) actor.shield = (actor.shield - total).clamp(0, 999);
  }

  List<PetViewModel> _livePlayerTeamVMs() => [
        for (var i = 0; i < _playerPets.length; i++)
          _snapVM(PetSnapshot.fromLive(_playerPets[i]), _playerPets[i], i),
      ];

  // ── Helpers (mirrors PvE) ──────────────────────────────────────────────────

  List<CardViewModel> _buildHandVMs(
      List<SkillCard> hand, Map<String, List<String>> pending) {
    int spent = 0;
    for (final ids in pending.values) {
      for (final instanceId in ids) {
        final c = hand.where((c) => c.instanceId == instanceId).firstOrNull;
        if (c != null) spent += c.trait.energyCost;
      }
    }
    final remaining = _engine.playerEnergy.energy - spent;
    final allAssigned = pending.values.expand((ids) => ids).toSet();
    return hand.map((card) {
      final owner = _playerPets.firstWhere((p) => p.id == card.ownerPetId);
      final isAssigned = allAssigned.contains(card.instanceId);
      return CardViewModel.fromCard(card, owner,
          availableEnergy: isAssigned ? null : remaining);
    }).toList();
  }

  List<TurnOrderEntry> _buildTurnOrder() {
    final all = [
      for (final p in _playerPets)
        TurnOrderEntry(
            petId: p.id,
            name: p.name,
            speed: p.speed,
            isPlayer: true,
            isFainted: p.isFainted,
            texturePath: null),
      for (final p in _enemyPets)
        TurnOrderEntry(
            petId: p.id,
            name: p.name,
            speed: p.speed,
            isPlayer: false,
            isFainted: p.isFainted,
            texturePath: null),
    ];
    all.sort((a, b) => b.speed.compareTo(a.speed));
    return all;
  }

  Pet? _resolveEnemyTargetForDash(Action action, List<Pet> opposingTeam) {
    if (action.primaryTarget != null) {
      return action.primaryTarget!.isFainted ? null : action.primaryTarget;
    }

    final alive = opposingTeam.where((p) => !p.isFainted).toList();
    if (alive.isEmpty) return null;

    final targetSpec = action.trait.effect.target;
    if (targetSpec == 'back_enemy') {
      return alive.last;
    }
    if (targetSpec == 'lowest_hp_enemy') {
      alive.sort((a, b) => a.hp.compareTo(b.hp));
      return alive.first;
    }
    return alive.first;
  }

  PetCharacterAnimState _animStateForEffect(String effectType) =>
      switch (effectType) {
        'heal' => PetCharacterAnimState.heal,
        'shield' => PetCharacterAnimState.shield,
        'buff' => PetCharacterAnimState.buff,
        'debuff' => PetCharacterAnimState.debuff,
        _ => PetCharacterAnimState.attack,
      };

  List<PetViewModel> _toViewModels(List<Pet> pets, {required bool isPlayer}) =>
      [for (var i = 0; i < pets.length; i++) _petVM(pets[i], i)];

  List<PetViewModel> _snapshotsToVMs(
          List<PetSnapshot> snaps, List<Pet> livePets) =>
      [
        for (var i = 0; i < snaps.length; i++) _snapVM(snaps[i], livePets[i], i)
      ];

  CreatureDefinition? _defFor(String petId) =>
      _petDefs[petId] ?? kCreatureRegistry[petId];

  PetViewModel _petVM(Pet pet, int position) {
    final def = _defFor(pet.id);
    final cfg = _mixedSkeletonConfigs[pet.id] ?? def?.spineConfig;
    return PetViewModel.initial(
        pet.id, pet.name, pet.speed, position, pet.traits, pet,
        spriteConfig: def?.spriteConfig,
        characterConfig: cfg,
        partCardArt: def?.partCardArt ?? const {},
        creatureDef: def);
  }

  PetViewModel _snapVM(PetSnapshot snap, Pet livePet, int position) {
    final def = _defFor(livePet.id);
    final cfg = _mixedSkeletonConfigs[livePet.id] ?? def?.spineConfig;
    return PetViewModel.fromSnapshot(snap, livePet.traits, livePet, position,
        spriteConfig: def?.spriteConfig,
        characterConfig: cfg,
        partCardArt: def?.partCardArt ?? const {},
        creatureDef: def);
  }

  Future<void> _initializeMixedSkeletons() async {
    try {
      final service = await MixedSkeletonService.instance();
      for (final pet in [..._playerPets, ..._enemyPets]) {
        final def = _defFor(pet.id);
        if (def == null) continue;
        try {
          final skeleton = await service.buildMixedSkeleton(def);
          _mixedSkeletonConfigs[pet.id] = PetCharacterConfig(
            texturePath: 'assets/spines/mixer/likha-2d-v3-all.png',
            spineAtlasPath: 'assets/spines/mixer/likha-2d-v3-all.atlas',
            skeletonJson: skeleton,
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _opponentChoicesCompleter?.completeError('disposed');
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final pvpBattleArgsProvider = StateProvider<PvpBattleArgs?>((_) => null);

final pvpBattleProvider =
    StateNotifierProvider.autoDispose<PvpBattleNotifier, PveBattleViewModel>(
  (ref) {
    final args = ref.read(pvpBattleArgsProvider);
    if (args == null) throw StateError('pvpBattleArgsProvider not set');

    // Get the authenticated validation service
    final validationService = ref.watch(pvpValidationServiceWithAuthProvider);

    // Create notifier with validated service
    return PvpBattleNotifier(
      args,
      validationService: validationService,
    );
  },
);
