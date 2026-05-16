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
import '../../../features/battle/services/mixed_skeleton_service.dart';
import '../../../features/battle/widgets/pet_character_widget.dart'
    show PetCharacterAnimState, PetCharacterConfig;
import '../../../features/pets/models/owned_pet.dart';
import '../models/pvp_message.dart';
import '../services/pvp_socket.dart';

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

  StreamSubscription<PvpMessage>? _wsSub;
  Completer<Map<String, List<String>>>? _opponentChoicesCompleter;
  PvpRoundLocked? _pendingRoundLocked;
  int? _awaitingRound;

  PvpBattleNotifier(PvpBattleArgs args) : super(PveBattleViewModel.initial()) {
    final match = args.matchFound;
    _myUserId = match.you.userId;
    _opponentUserId = match.opponent.userId;
    _matchId = match.matchId;

    // Decode own team from OwnedPet list
    _playerPets = args.myTeam
        .where((p) => kBodyCatalogue.containsKey(p.bodyId))
        .map((p) => p.toCreatureDefinition().toPet())
        .toList();
    for (final p in args.myTeam) {
      _petDefs[p.uid] = p.toCreatureDefinition();
    }

    // Decode opponent team from server-provided DNA refs
    _enemyPets = match.opponent.team.map((ref) {
      final owned = OwnedPet(
        uid: ref.uid,
        name: 'Opponent',
        dna: ref.dna,
        createdAt: DateTime.now(),
      );
      if (kBodyCatalogue.containsKey(owned.bodyId)) {
        final def = owned.toCreatureDefinition();
        _petDefs[owned.uid] = def;
        return def.toPet();
      }
      // Fallback to a default pet if DNA is unrecognised
      return kCreatureRegistry.values.first.toPet();
    }).toList();

    _engine = InteractiveBattleEngine(
      playerTeam: _playerPets,
      enemyTeam: _enemyPets,
      playerTeamName: 'You',
      enemyTeamName: match.opponent.displayName.isNotEmpty
          ? match.opponent.displayName
          : 'Opponent',
      battleSeed: match.seed,
      mode: BattleMode.pvp,
    );

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
          .timeout(const Duration(seconds: 70), onTimeout: () => {});
    } catch (_) {
      opponentSelections = {};
    }
    _opponentChoicesCompleter = null;
    _awaitingRound = null;
    if (!mounted) return;
    state = state.copyWith(awaitingOpponent: false);

    // Feed opponent choices into engine, then run round
    _engine.setOpponentChoices(opponentSelections);
    final started = _engine.prepareRound(mySelections);

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
            await Future.delayed(const Duration(milliseconds: 300));
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
        await Future.delayed(const Duration(milliseconds: 300));
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
        state = state.copyWith(
          petAnimStates:
              Map<String, PetCharacterAnimState>.from(state.petAnimStates)
                ..addAll(targetAnims),
        );
      }

      await Future.delayed(
          Duration(milliseconds: action.actor.isFainted ? 120 : 500));
      if (!mounted) return;

      state = state.copyWith(
        petAnimStates: const {},
        petEffectVfx: const {},
        petAttackSlots: const {},
        petDashOffsets: const {},
        petDashTargets: const {},
      );
      await Future.delayed(const Duration(milliseconds: 120));
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
    return PvpBattleNotifier(args);
  },
);
