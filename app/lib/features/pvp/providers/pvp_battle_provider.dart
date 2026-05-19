import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../../../features/battle/widgets/pet_character_widget.dart'
    show PetCharacterAnimState;
import '../../../features/battle/widgets/pet_sprite_widget.dart'
    show PetSpriteConfig;
import '../../../features/pets/models/owned_pet.dart';
import '../../../features/pets/models/team_composition.dart';
import '../models/battle_action_log.dart';
import '../models/pvp_message.dart';
import '../services/pvp_socket.dart';
import '../services/authenticated_pvp_validation_service.dart';
import '../services/pvp_firestore_service.dart';

// ── Args ──────────────────────────────────────────────────────────────────────

class PvpBattleArgs {
  final PvpMatchFound matchFound;
  final List<OwnedPet> myTeam;
  final List<TeamSlot> myTeamSlots;
  final String myTeamName;
  const PvpBattleArgs({
    required this.matchFound,
    required this.myTeam,
    this.myTeamSlots = const [],
    this.myTeamName = 'My Team',
  });
}

// ── Notifier ──────────────────────────────────────────────────────────────────

// ── Animation timing constants (must match pve_battle_provider.dart) ──────────
const _kPvpDashWaitMs       = 480;
const _kPvpImpactWaitMs     = 700;
const _kPvpHitWaitMs        = 480;
const _kPvpRecoilWaitMs     = 480;
const _kPvpGapMs            = 100;
const _kPvpProjectileWaitMs = 620;
const _kPvpEffectWindupMs   = 500;
const _kPvpEffectResultMs   = 480;

class PvpBattleNotifier extends StateNotifier<PveBattleViewModel> {
  static const String _audioOwner = 'pvp_battle';
  static const String _normalBgm = 'audio/battle/battle_sound.ogg';
  static const String _bloodMoonBgm = 'audio/battle/blood_moon_bg.ogg';
  static const double _normalBgmVolume = 0.22;
  static const double _bloodMoonBgmVolume = 0.24;

  late final InteractiveBattleEngine _engine;
  // Built incrementally so UID→Pet mapping is always 1-to-1 (no index drift).
  final List<Pet> _playerPets = [];
  late final List<Pet> _enemyPets;
  late final String _myUserId;
  late final String _opponentUserId;
  late final String _matchId;

  List<Offset> _playerBattlePos = const [
    Offset(0.30, 0.34),
    Offset(0.15, 0.18),
    Offset(0.10, 0.50),
  ];
  List<Offset> _enemyBattlePos = const [
    Offset(0.50, 0.34),
    Offset(0.65, 0.18),
    Offset(0.75, 0.50),
  ];

  final Map<String, CreatureDefinition> _petDefs = {};
  int _visualEventCounter = 0;

  // Maps the UUID submitted to the server → local Pet object.
  // This avoids ID collisions when both teams have the same creature type
  // (e.g., both players have "aquatic-02" — CreatureDefinition.id is not unique
  // across teams, but OwnedPet.uid always is).
  final Map<String, Pet> _submitUidToPet = {};

  // ── Action logging for PvP validation ───────────────────────────────────
  final List<BattleActionLog> _actionLog = [];
  late final int _battleStartTime;
  late final AuthenticatedPvpValidationService _validationService;
  late final PvpFirestoreService _firestoreService;
  late final int _battleSeed;
  late final String _myTeamName;
  late final bool _isAlpha; // true = this client is Team A on the server
  final List<OwnedPet> _myOwnedTeam = []; // parallel to _playerPets, same order

  // Buffers a match:end that arrives while round animation is still playing.
  PvpMatchEndData? _pendingMatchEnd;
  PvpRoundResult? _pendingRoundResult;
  Timer? _pendingRoundResultTimer;

  StreamSubscription<PvpMessage>? _wsSub;
  Completer<Map<String, List<String>>>? _opponentChoicesCompleter;
  PvpRoundLocked? _pendingRoundLocked;
  int? _awaitingRound;

  void _trace(String event, [Map<String, Object?> data = const {}]) {
    final payload = {
      'matchId': _matchId,
      'round': _engine.round,
      'event': event,
      ...data,
    };
    print('[PvPTrace] ${jsonEncode(payload)}');
    if (kIsWeb && _matchId.isNotEmpty) {
      PvpSocket.instance.send({
        'type': 'client:trace',
        'matchId': _matchId,
        'event': event,
        'details': payload,
      });
    }
  }

  void _syncBloodMoonAudio(bool nextIsBloodMoon) {
    if (state.isBloodMoon == nextIsBloodMoon) return;
    BattleAudioService.instance.playOwnedBgm(
      _audioOwner,
      nextIsBloodMoon ? _bloodMoonBgm : _normalBgm,
      baseVolume: nextIsBloodMoon ? _bloodMoonBgmVolume : _normalBgmVolume,
    );
  }

  Future<void> _animateDrawnCards(
    Set<String> handBeforeIds,
    List<CardViewModel> fullHand,
  ) async {
    final newIds = fullHand
        .map((c) => c.instanceId)
        .where((id) => !handBeforeIds.contains(id))
        .toList();

    if (newIds.isEmpty) {
      state = state.copyWith(
        hand: fullHand,
        deckDrawSize: _engine.playerDeckDrawSize,
        deckDiscardSize: _engine.playerDeckDiscardSize,
        newCardIds: const {},
      );
      return;
    }

    final indexById = <String, int>{
      for (var i = 0; i < fullHand.length; i++) fullHand[i].instanceId: i,
    };
    final cardById = {for (final c in fullHand) c.instanceId: c};

    final visible = fullHand
        .where((c) => !newIds.contains(c.instanceId))
        .toList(growable: true);

    state = state.copyWith(
      hand: List<CardViewModel>.from(visible),
      deckDrawSize: _engine.playerDeckDrawSize,
      deckDiscardSize: _engine.playerDeckDiscardSize,
      newCardIds: const {},
    );

    for (final id in newIds) {
      if (!mounted) return;
      final card = cardById[id];
      if (card == null) continue;

      final targetIndex = indexById[id] ?? visible.length;
      final insertIndex = visible
          .where((c) => (indexById[c.instanceId] ?? 9999) < targetIndex)
          .length;
      visible.insert(insertIndex, card);

      state = state.copyWith(
        hand: List<CardViewModel>.from(visible),
        deckDrawSize: _engine.playerDeckDrawSize,
        deckDiscardSize: _engine.playerDeckDiscardSize,
        newCardIds: {id},
      );
      BattleAudioService.instance.playCardDraw();
      await Future.delayed(const Duration(milliseconds: 190));
    }

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    state = state.copyWith(newCardIds: const {});
  }

  void _bufferRoundResult(PvpRoundResult result) {
    _pendingRoundResult = result;
    _pendingRoundResultTimer?.cancel();
    _pendingRoundResultTimer = Timer(
      const Duration(milliseconds: 260),
      _flushPendingRoundResult,
    );
  }

  void _flushPendingRoundResult() {
    final pending = _pendingRoundResult;
    if (!mounted || pending == null) return;
    _pendingRoundResult = null;
    _pendingRoundResultTimer?.cancel();
    _pendingRoundResultTimer = null;
    unawaited(_commitServerRoundResult(pending));
  }

  PvpBattleNotifier(
    PvpBattleArgs args, {
    required AuthenticatedPvpValidationService validationService,
  }) : super(PveBattleViewModel.initial()) {
    _validationService = validationService;
    final match = args.matchFound;
    _myTeamName = args.myTeamName;
    _myUserId = match.you.userId;
    _opponentUserId = match.opponent.userId;
    _matchId = match.matchId;
    _battleSeed = match.seed;

    // Build _playerPets and _submitUidToPet in ONE pass so every UID maps to
    // the exact Pet object created from it.  Using separate loops caused index
    // drift when some OwnedPets were filtered (bodyId not in catalogue).
    for (var i = 0; i < args.myTeam.length; i++) {
      final owned = args.myTeam[i];
      if (!kBodyCatalogue.containsKey(owned.bodyId)) continue;
      final def = owned.toCreatureDefinition();
      _petDefs[owned.uid] = def;
      final slot = i < args.myTeamSlots.length ? args.myTeamSlots[i] : null;
      final pet = def.toPet(
        displayName: owned.name,
        row: slot?.row.index ?? i,
        lane: slot?.lane.index ?? 1,
      );
      _playerPets.add(pet);
      _submitUidToPet[owned.uid] = pet; // guaranteed 1-to-1 mapping
      _myOwnedTeam.add(owned); // parallel list for petStatesSnapshot
    }

    // Sort both parallel lists by row so list index 0=FRONT,1=MID,2=BACK,
    // matching the battlefield visual positions.
    if (_playerPets.length == _myOwnedTeam.length) {
      final paired = List.generate(
        _playerPets.length,
        (i) => (pet: _playerPets[i], owned: _myOwnedTeam[i]),
      )..sort((a, b) => a.pet.row.compareTo(b.pet.row));
      _playerPets
        ..clear()
        ..addAll(paired.map((p) => p.pet));
      _myOwnedTeam
        ..clear()
        ..addAll(paired.map((p) => p.owned));
    }

    // 🔍 DIAGNOSTIC: Log own team stats
    print('═' * 80);
    print('[PvP Match ${match.matchId}] BATTLE STARTED - Seed: ${match.seed}');
    print('═' * 80);
    print('[PvP DEBUG] Decoded ${_playerPets.length} pets from args.myTeam');
    if (_playerPets.isNotEmpty) {
      print('[PvP] My Team (${_playerPets.length} pets):');
      for (var i = 0; i < _playerPets.length; i++) {
        final pet = _playerPets[i];
        print(
            '  ➤ Pet $i: ${pet.name} | SPD:${pet.effectiveSpeed} HP:${pet.maxHp} SKL:${pet.skill} MOR:${pet.morale}');
      }
    } else {
      print('[PvP ERROR] No pets decoded! Check kBodyCatalogue');
    }

    // Decode opponent team — same 1-to-1 pass as own team.
    final enemyList = <Pet>[];
    for (var i = 0; i < match.opponent.team.length; i++) {
      final ref = match.opponent.team[i];
      final owned = OwnedPet(
        uid: ref.uid,
        name: 'Opponent ${i + 1}',
        dna: ref.dna,
        createdAt: ref.createdAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(ref.createdAtMs!)
            : DateTime.now(),
      );
      final Pet pet;
      if (kBodyCatalogue.containsKey(owned.bodyId)) {
        final def = owned.toCreatureDefinition();
        _petDefs[owned.uid] = def;
        pet = def.toPet(
          displayName: '${match.opponent.displayName}\'s ${def.className}',
          row: i,
          lane: 1,
        );
      } else {
        pet = kCreatureRegistry.values.first.toPet(row: i, lane: 1);
      }
      enemyList.add(pet);
      _submitUidToPet[ref.uid] = pet; // opponent UID → enemy Pet
    }
    _enemyPets = enemyList;

    // 🔍 DIAGNOSTIC: Log opponent team stats
    print('[PvP DEBUG] Decoded ${_enemyPets.length} pets from opponent');
    if (_enemyPets.isNotEmpty) {
      print('[PvP] Opponent Team (${_enemyPets.length} pets):');
      for (var i = 0; i < _enemyPets.length; i++) {
        final pet = _enemyPets[i];
        print(
            '  ➤ Pet $i: ${pet.name} | SPD:${pet.effectiveSpeed} HP:${pet.maxHp} SKL:${pet.skill} MOR:${pet.morale}');
      }
    } else {
      print('[PvP ERROR] No opponent pets decoded!');
    }
    print('═' * 80);

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
    _isAlpha = _myUserId.compareTo(_opponentUserId) < 0;
    final int playerDeckSeed = _isAlpha ? match.seed : match.seed ^ 0x5A3C;
    final int enemyDeckSeed = _isAlpha ? match.seed ^ 0x5A3C : match.seed;

    _engine = InteractiveBattleEngine(
      playerTeam: _playerPets,
      enemyTeam: _enemyPets,
      playerTeamName: _myTeamName,
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
    _trace('battle:init', {
      'myTeam': _playerPets.length,
      'enemyTeam': _enemyPets.length,
      'isAlpha': _isAlpha,
    });

    // Subscribe to WS messages
    _wsSub = PvpSocket.instance.messages.listen(_onWsMessage);

    state = PveBattleViewModel(
      currentRound: 1,
      playerTeam: _toViewModels(_playerPets, isPlayer: true),
      enemyTeam: _toViewModels(_enemyPets, isPlayer: false),
      roundLog: '',
      isBattleOver: false,
      playerTeamName: _myTeamName,
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
  }

  // ── WS message handling ────────────────────────────────────────────────────

  void _onWsMessage(PvpMessage msg) {
    if (msg is PvpRoundLocked) {
      _trace('ws:round:locked', {
        'round': msg.round,
        'waitingFor': _awaitingRound,
      });
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
    } else if (msg is PvpRoundAction) {
      _trace('ws:round:action', {
        'actorUid': msg.actorUid,
        'targetUid': msg.targetUid,
        'effectType': msg.effectType,
        'damage': msg.damage,
      });
      _applyServerAction(msg);
    } else if (msg is PvpRoundHit) {
      _trace('ws:round:hit', {
        'actorUid': msg.actorUid,
        'targetUid': msg.targetUid,
        'effectType': msg.effectType,
        'damage': msg.damage,
        'healAmount': msg.healAmount,
        'shieldAmount': msg.shieldAmount,
      });
      _applyServerHit(msg);
    } else if (msg is PvpRoundResult) {
      _trace('ws:round:result', {
        'round': msg.round,
        'battleComplete': msg.battleComplete,
        'petStates': msg.petStates.length,
      });
      // Final HP state from server — buffer so the last hit animation can paint
      // before we clear the playback state and advance the round bookkeeping.
      _bufferRoundResult(msg);
    } else if (msg is PvpMatchEnd) {
      _trace('ws:match:end', {
        'winnerUid': msg.winnerUid,
        'dispute': msg.dispute,
        'mmrDelta': msg.mmrDelta,
      });
      final matchEnd = PvpMatchEndData(
        winnerUid: msg.winnerUid,
        dispute: msg.dispute,
        mmrDelta: msg.mmrDelta,
      );
      // If round animation is playing, buffer — the buffered round result will
      // flush after the impact frame has had time to paint.
      // But if no round:result ever arrives (server error path), apply after a short
      // grace period so the client doesn't stay stuck forever.
      if (state.isResolving && state.awaitingOpponent) {
        // We're waiting for round:result that may never come — apply after 2 s.
        _pendingMatchEnd = matchEnd;
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted || state.pvpMatchEnd != null) return;
          state = state.copyWith(
            pvpMatchEnd: _pendingMatchEnd,
            isBattleOver: true,
            isResolving: false,
            awaitingOpponent: false,
          );
          _pendingMatchEnd = null;
        });
      } else if (state.isResolving) {
        // Animation in progress — buffer normally.
        _pendingMatchEnd = matchEnd;
      } else {
        state = state.copyWith(
          pvpMatchEnd: matchEnd,
          isBattleOver: true,
          awaitingOpponent: false,
        );
      }
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
    state = state.copyWith(
      hand: hand,
      pendingSkills: newPending,
      needsDiscard: false,
      excessDiscards: 0,
    );
  }

  // ── Phase 1: Attack animation (dash + attack pose) ───────────────────────────
  // Called when round:action arrives.  NO HP change yet — this is purely visual:
  // the attacker dashes toward the target and plays their attack animation.
  // Damage lands 700 ms later via round:hit.

  // Finds a pet by its server submit UID (OwnedPet.uuid) or CreatureDefinition.id.
  // Returns (pet, isPlayerTeam). Checks the submit-UID map first to avoid
  // CreatureDefinition.id collisions between teams.
  (Pet?, bool) _findPet(String uid) {
    final mapped = _submitUidToPet[uid];
    if (mapped != null) {
      return (mapped, _playerPets.any((p) => p == mapped));
    }
    // Fallback: search by Pet.id (CreatureDefinition.id)
    final p = _playerPets.firstWhereOrNull((p) => p.id == uid);
    if (p != null) return (p, true);
    final e = _enemyPets.firstWhereOrNull((p) => p.id == uid);
    return (e, false);
  }

  // Ranged cards identified by their trait display name — these fire a projectile
  // instead of a melee dash. Kept in sync with _kRangedTraitIds in pve_battle_provider.
  static const _kRangedActionNames = {'All-out Shot', 'Smart Shot', 'Turnip Rocket'};

  void _applyServerAction(PvpRoundAction msg) {
    if (!mounted) return;

    final effectType = msg.effectType.isNotEmpty
        ? msg.effectType
        : (msg.damage > 0 ? 'damage' : 'buff');
    final damage = msg.damage;

    final (actorPet, isActorPlayer) = _findPet(msg.actorUid);
    final (targetPet, isTargetPlayer) =
        msg.targetUid.isNotEmpty ? _findPet(msg.targetUid) : (null, false);

    if (actorPet == null) {
      print('[PvP] ⚠️ round:action — actor not found: ${msg.actorUid}');
      state = state.copyWith(awaitingOpponent: false, isResolving: true);
      return;
    }

    final actorAnimId = actorPet.id;
    final targetAnimId = targetPet?.id ?? '';

    _trace('ui:round:action:apply', {
      'actorUid': msg.actorUid,
      'targetUid': msg.targetUid,
      'effectType': effectType,
      'damage': damage,
      'actionName': msg.actionName,
      'actorAnimId': actorAnimId,
    });

    BattleAudioService.instance.playAttack(effectType);

    final isDamage = effectType == 'damage' || effectType == 'aoe';
    final isRanged = isDamage && _kRangedActionNames.contains(msg.actionName);

    if (isDamage && !isRanged && damage > 0 && targetPet != null) {
      // ── MELEE: dash toward target ──────────────────────────────────────────
      final actorList = isActorPlayer ? _playerPets : _enemyPets;
      final targetList = isTargetPlayer ? _playerPets : _enemyPets;
      final actorIdx = actorList.indexOf(actorPet).clamp(0, 2);
      final targetIdx = targetList.indexOf(targetPet).clamp(0, 2);

      final actorBase = isActorPlayer
          ? _playerBattlePos[actorIdx]
          : _enemyBattlePos[actorIdx];
      final targetBase = isTargetPlayer
          ? _playerBattlePos[targetIdx]
          : _enemyBattlePos[targetIdx];

      final toTarget = targetBase - actorBase;
      final dist = toTarget.distance;
      Offset dashDir = Offset.zero;
      String? dashTarget;
      if (dist > 0.001) {
        const maxDash = 0.20;
        const minGap = 0.06;
        final d = math.min(maxDash, math.max(0.0, dist - minGap));
        dashDir = Offset(toTarget.dx / dist * d, toTarget.dy / dist * d);
        dashTarget = targetAnimId;
      }

      state = state.copyWith(
        awaitingOpponent: false,
        isResolving: true,
        petAnimStates: {actorAnimId: PetCharacterAnimState.attackMelee},
        petEffectVfx: {actorAnimId: effectType},
        petDashOffsets:
            dashDir != Offset.zero ? {actorAnimId: dashDir} : const {},
        petDashTargets:
            dashTarget != null ? {actorAnimId: dashTarget} : const {},
        petAttackSlots: const {},
      );
    } else if (isRanged && targetPet != null) {
      // ── RANGED: stay in place, spawn projectile ────────────────────────────
      state = state.copyWith(
        awaitingOpponent: false,
        isResolving: true,
        petAnimStates: {actorAnimId: PetCharacterAnimState.attackRanged},
        petEffectVfx: {actorAnimId: effectType},
        petDashOffsets: const {},
        petDashTargets: const {},
        petAttackSlots: const {},
        pendingProjectileToken: state.pendingProjectileToken + 1,
        pendingProjectileActorId: actorAnimId,
        pendingProjectileTargetId: targetAnimId,
        pendingProjectileClass: actorPet.creatureClass.name,
      );
    } else {
      // ── SUPPORT / AoE / no target ──────────────────────────────────────────
      state = state.copyWith(
        awaitingOpponent: false,
        isResolving: true,
        petAnimStates: {actorAnimId: _animStateForEffect(effectType)},
        petEffectVfx: {actorAnimId: effectType},
        petDashOffsets: const {},
        petDashTargets: const {},
        petAttackSlots: const {},
      );
    }
  }

  // ── Phase 2: Damage lands + HP reflects + hit/faint animation ────────────────
  // Called when round:hit arrives, 700 ms after round:action.
  // This is the "impact" moment: reduce HP now, show hit/faint reaction,
  // rebuild HP bars so the player sees the damage immediately.

  void _applyServerHit(PvpRoundHit msg) {
    if (!mounted) return;

    final effectType = msg.effectType;
    final targetId = msg.targetUid;
    final actorId = msg.actorUid;
    final damage = msg.damage;
    final healAmount = msg.healAmount;
    final shieldAmount = msg.shieldAmount;
    final statusApplied = msg.statusApplied;

    final (targetPet, _) =
        targetId.isNotEmpty ? _findPet(targetId) : (null, false);
    final (actorPet, _) =
        actorId.isNotEmpty ? _findPet(actorId) : (null, false);

    _trace('ui:round:hit:before', {
      'actorUid': actorId,
      'targetUid': targetId,
      'effectType': effectType,
      'damage': damage,
      'healAmount': healAmount,
      'shieldAmount': shieldAmount,
      'statusApplied': statusApplied,
      'targetHpBefore': targetPet?.hp,
      'targetShieldBefore': targetPet?.shield,
      'actorHpBefore': actorPet?.hp,
      'actorShieldBefore': actorPet?.shield,
      'serverTargetHpAfter': msg.targetHpAfter,
      'serverTargetShieldAfter': msg.targetShieldAfter,
    });

    if (targetPet == null && actorPet == null) {
      print('[PvP] ⚠️ round:hit — neither found. '
          'targetUid=${msg.targetUid} actorUid=${msg.actorUid} '
          'submitMap=${_submitUidToPet.keys.toList()}');
      state =
          state.copyWith(petDashOffsets: const {}, petDashTargets: const {});
      return;
    }

    // Use Pet.id (CreatureDefinition.id) for animation keys — the UI looks up
    // petAnimStates by vm.playerTeam[i].id which is Pet.id, not OwnedPet.uid.
    final targetAnimId = targetPet?.id ?? '';
    final actorAnimId = actorPet?.id ?? '';

    final animUpdates = <String, PetCharacterAnimState>{...state.petAnimStates};

    // ── Apply server-authoritative HP/shield values ──────────────────────────
    // The server sends exact post-action values — never recalculate locally.
    // This ensures both clients show identical state throughout the animation.
    var appliedAuthoritativeTargetState = false;
    if (targetPet != null && msg.targetHpAfter >= 0) {
      _applyAuthoritativePetState(
        targetPet,
        hpAfter: msg.targetHpAfter,
        shieldAfter: msg.targetShieldAfter,
        faintedAfter: msg.targetIsFainted,
      );
      appliedAuthoritativeTargetState = true;
    }
    if (actorPet != null && msg.actorHpAfter >= 0) {
      _applyAuthoritativePetState(
        actorPet,
        hpAfter: msg.actorHpAfter,
        shieldAfter: msg.actorShieldAfter,
        faintedAfter: false,
      );
    }

    final impactEvent = BattleImpactEvent(
      id: ++_visualEventCounter,
      actorId: actorId,
      targetId: targetId.isNotEmpty ? targetId : actorId,
      effectType: effectType,
      damage: damage,
      healAmount: healAmount,
      shieldAmount: shieldAmount,
      statusApplied: statusApplied,
      targetHpAfter: msg.targetHpAfter,
      targetShieldAfter: msg.targetShieldAfter,
      targetIsFainted: msg.targetIsFainted,
      actorHpAfter: msg.actorHpAfter,
      actorShieldAfter: msg.actorShieldAfter,
    );

    // Fallback for clients still receiving a legacy hit packet without the
    // post-action fields: apply the impact locally so HP changes on impact.
    if (!appliedAuthoritativeTargetState && targetPet != null) {
      switch (effectType) {
        case 'damage':
        case 'aoe':
        case 'shieldBreak':
        case 'poison':
        case 'burn':
        case 'stun':
        case 'sleep':
        case 'fear':
        case 'aroma':
        case 'chill':
        case 'jinx':
        case 'heal_block':
        case 'crit_block':
        case 'disabled':
        case 'reflect':
        case 'stench':
        case 'debuff':
        case 'atk_down':
        case 'def_down':
        case 'spd_down':
          if (damage > 0) {
            final absorbed = math.min(targetPet.shield, damage);
            targetPet.shield = (targetPet.shield - absorbed).clamp(0, 9999);
            targetPet.hp =
                (targetPet.hp - (damage - absorbed)).clamp(0, targetPet.maxHp);
            targetPet.isFainted = targetPet.hp <= 0;
          }
        case 'heal':
        case 'regen':
          if (healAmount > 0) {
            final pet = actorPet ?? targetPet;
            pet.hp = (pet.hp + healAmount).clamp(0, pet.maxHp);
          }
        case 'shield':
          if (shieldAmount > 0) {
            final pet = actorPet ?? targetPet;
            pet.shield = (pet.shield + shieldAmount).clamp(0, 9999);
          }
        case 'buff':
        case 'atk_up':
        case 'def_up':
        case 'spd_up':
        case 'energized':
          break;
        default:
          if (damage > 0) {
            final absorbed = math.min(targetPet.shield, damage);
            targetPet.shield = (targetPet.shield - absorbed).clamp(0, 9999);
            targetPet.hp =
                (targetPet.hp - (damage - absorbed)).clamp(0, targetPet.maxHp);
            targetPet.isFainted = targetPet.hp <= 0;
          }
      }
    }

    // ── Determine animation state from effect type ────────────────────────────
    switch (effectType) {
      case 'damage':
      case 'aoe':
      case 'shieldBreak':
      case 'poison':
      case 'burn':
        case 'stun':
        case 'sleep':
        case 'fear':
        case 'aroma':
        case 'chill':
        case 'jinx':
        case 'heal_block':
        case 'crit_block':
        case 'disabled':
        case 'reflect':
        case 'stench':
      case 'debuff':
      case 'atk_down':
      case 'def_down':
      case 'spd_down':
        if (targetPet != null) {
          final isFaint = targetPet.isFainted;
          if (targetAnimId.isNotEmpty) {
            animUpdates[targetAnimId] = isFaint
                ? PetCharacterAnimState.faint
                : PetCharacterAnimState.hit;
          }
        }

      case 'heal':
      case 'regen':
        final pet = targetPet ?? actorPet;
        if (pet != null) {
          animUpdates[pet.id] = PetCharacterAnimState.heal;
          BattleAudioService.instance.playAttack('heal');
        }

      case 'shield':
        final pet = targetPet ?? actorPet;
        if (pet != null) {
          animUpdates[pet.id] = PetCharacterAnimState.shield;
          BattleAudioService.instance.playAttack('shield');
        }

      case 'buff':
      case 'atk_up':
      case 'def_up':
      case 'spd_up':
      case 'energized':
        final pet = targetPet ?? actorPet;
        if (pet != null) {
          animUpdates[pet.id] = PetCharacterAnimState.buff;
          BattleAudioService.instance.playAttack('buff');
        }

      default:
        if (targetPet != null) {
          if (targetAnimId.isNotEmpty) {
            animUpdates[targetAnimId] = targetPet.isFainted
                ? PetCharacterAnimState.faint
                : PetCharacterAnimState.hit;
          }
        }
    }

    state = state.copyWith(
      petAnimStates: animUpdates,
      petDashOffsets: const {},
      petDashTargets: const {},
      clearPendingProjectile: true,
      lastImpactEvent: impactEvent,
      // Rebuild HP/shield bars with updated values immediately
      playerTeam: _toViewModels(_playerPets, isPlayer: true),
      enemyTeam: _toViewModels(_enemyPets, isPlayer: false),
    );

    if (_pendingRoundResult != null &&
        _pendingRoundResult!.round == msg.round) {
      _bufferRoundResult(_pendingRoundResult!);
    }

    _trace('ui:round:hit:after', {
      'targetUid': targetId,
      'targetAnimId': targetAnimId,
      'targetHp': targetPet?.hp,
      'targetShield': targetPet?.shield,
      'actorUid': actorId,
      'actorAnimId': actorAnimId,
      'actorHp': actorPet?.hp,
      'actorShield': actorPet?.shield,
    });
  }

  void _applyAuthoritativePetState(
    Pet pet, {
    required int hpAfter,
    required int shieldAfter,
    required bool faintedAfter,
  }) {
    final isDead = pet.isFainted || faintedAfter || hpAfter <= 0;
    if (isDead) {
      pet.hp = 0;
      pet.shield = 0;
      pet.isFainted = true;
      return;
    }

    pet.hp = hpAfter;
    pet.shield = shieldAfter;
    pet.isFainted = false;
  }

  // ── Apply final HP + draw cards after all actions have been streamed ────────
  // This is the authoritative "end of round" update.  The engine is advanced
  // locally (deterministic seed) purely for card-draw, energy reset and status
  // tick — HP values are always overridden by the server.

  Future<void> _commitServerRoundResult(PvpRoundResult result) async {
    if (!mounted) return;
    print(
        '[PvP] Round ${result.round} result received — applying buffered round result');
    _trace('ui:round:result:start', {
      'round': result.round,
      'battleComplete': result.battleComplete,
      'pendingSkills': state.pendingSkills.length,
    });

    final handBeforeIds = state.hand.map((c) => c.instanceId).toSet();

    // ── 1. Advance local engine for deck/energy management ────────────────────
    // Use the player's selections from this round so the right cards are
    // discarded from the deck.  Enemy selections are empty (server-side only).
    try {
      _engine.setOpponentChoices({});
      final playerPending =
          state.pendingSkills.map((k, v) => MapEntry(k, List<String>.from(v)));
      final started = _engine.prepareRound(playerPending);
      if (!started.hasImmediateResult) {
        while (_engine.hasPendingActions) {
          _engine.executeNextAction();
        }
      }
      _engine.finishRound(); // discard used cards + draw new hand
    } catch (e) {
      print('[PvP] ⚠️ Engine round advance failed (non-fatal): $e');
    }

    // ── 2. Override HP + status effects with server-authoritative values ─────
    for (final entry in result.petStates.entries) {
      final uid = entry.key;
      final data = entry.value as Map<String, dynamic>;
      final newHp = (data['hp'] as num).toInt();
      final newShield = (data['shield'] as num?)?.toInt() ?? 0;
      // Look up by submit UID first (OwnedPet.uid), then by Pet.id fallback
      final pet = _submitUidToPet[uid] ??
          _playerPets.firstWhereOrNull((p) => p.id == uid) ??
          _enemyPets.firstWhereOrNull((p) => p.id == uid);
      if (pet == null) continue;
      pet.hp = newHp;
      pet.shield = newShield;
      pet.isFainted = newHp <= 0;
    }

    // ── 3. Build new hand + round log ─────────────────────────────────────────
    final newHand = _buildHandVMs(_engine.currentPlayerHand, const {});

    final turnOrderStr = result.turnOrder.map((e) {
      final name = e['name'] as String? ?? e['actorUid'] as String? ?? '?';
      final dmg = e['damage'] as int?;
      return dmg != null ? '$name (dmg: $dmg)' : '$name';
    }).join(' → ');

    // ── 4. Commit state ───────────────────────────────────────────────────────
    state = state.copyWith(
      currentRound: result.round + 1,
      roundLog: '${state.roundLog}\nRound ${result.round}: $turnOrderStr',
      playerTeam: _toViewModels(_playerPets, isPlayer: true),
      enemyTeam: _toViewModels(_enemyPets, isPlayer: false),
      hand: state.hand,
      newCardIds: const {},
      deckDrawSize: _engine.playerDeckDrawSize,
      deckDiscardSize: _engine.playerDeckDiscardSize,
      playerTeamEnergy: _engine.playerEnergy.energy,
      enemyTeamEnergy: _engine.enemyEnergy.energy,
      isBloodMoon:
          (result.round + 1) >= InteractiveBattleEngine.bloodMoonStartRound,
      pendingSkills: const {},
      selectedPetId: null,
      awaitingOpponent: false,
      isResolving: false,
      petAnimStates: const {},
      petEffectVfx: const {},
      petAttackSlots: const {},
      petDashOffsets: const {},
      petDashTargets: const {},
      lastImpactEvent: null,
    );
    await _animateDrawnCards(handBeforeIds, newHand);
    if (!mounted) return;
    _syncBloodMoonAudio(state.isBloodMoon);

    print('[PvP] Round ${result.round} done — hand: ${newHand.length} cards, '
        'energy: ${_engine.playerEnergy.energy}');
    _trace('ui:round:result:done', {
      'round': result.round,
      'battleComplete': result.battleComplete,
      'newHand': newHand.length,
      'playerEnergy': _engine.playerEnergy.energy,
      'enemyEnergy': _engine.enemyEnergy.energy,
    });

    if (result.battleComplete || _pendingMatchEnd != null) {
      state = state.copyWith(isBattleOver: true);
      if (_pendingMatchEnd != null) {
        state = state.copyWith(pvpMatchEnd: _pendingMatchEnd);
        _pendingMatchEnd = null;
      }
    }

    _saveBattleLogToFirestore(result);
  }

  void _saveBattleLogToFirestore(PvpRoundResult result) {
    // Capture current team snapshots
    final playerTeamSnapshot = <String, dynamic>{};
    for (final pet in _playerPets) {
      playerTeamSnapshot[pet.id] = {
        'hp': pet.hp,
        'shield': pet.shield,
        'isFainted': pet.isFainted,
      };
    }
    final opponentTeamSnapshot = <String, dynamic>{};
    for (final pet in _enemyPets) {
      opponentTeamSnapshot[pet.id] = {
        'hp': pet.hp,
        'shield': pet.shield,
        'isFainted': pet.isFainted,
      };
    }

    // This is async and non-blocking
    try {
      _firestoreService.saveLiveRoundLog(
        matchId: _matchId,
        roundNumber: result.round,
        roundLog: state.roundLog,
        playerTeamState: playerTeamSnapshot,
        opponentTeamState: opponentTeamSnapshot,
        turnOrder: result.turnOrder,
        isBattleComplete: result.battleComplete,
      );
    } catch (e) {
      print('[PvP] Failed to save battle log: $e');
    }
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
    _trace('submit:round', {
      'round': expectedRound,
      'selectedPets': mySelections.length,
      'selectedCards':
          mySelections.values.fold<int>(0, (sum, ids) => sum + ids.length),
    });

    // ── PvP fast path: server is authoritative, no round:locked needed ────────
    // The server now runs the battle and sends round:result directly.
    // We just submit selections and wait — the buffered round result unblocks us.
    if (_matchId.isNotEmpty) {
      // Only submit OWN 3 pets. Server uses statesA as playerATeam, statesB as
      // playerBTeam — submitting all 6 would make the server run a 6v6 battle
      // with duplicate IDs and return UIDs that don't match either client's lists.
      // Use OwnedPet.uid as the server-side identifier (unique across both teams).
      // CreatureDefinition.id would collide if both players have the same creature type.
      final petStatesSnapshot = List.generate(
        math.min(_myOwnedTeam.length, _playerPets.length),
        (i) => {
          'uid': _myOwnedTeam[i].uid, // OwnedPet UUID — guaranteed unique
          'name': _playerPets[i].name,
          'hp': _playerPets[i].hp,
          'maxHp': _playerPets[i].maxHp,
          'shield': _playerPets[i].shield,
          'isFainted': _playerPets[i].isFainted,
          'spd': _playerPets[i].speed,
          'skl': _playerPets[i].skill,
          'mor': _playerPets[i].morale,
          'row': _playerPets[i].row,
          'lane': _playerPets[i].lane,
          'dex': 0,
          'def': 0,
          'statusEffects': [],
        },
      );

      // Build card effect map so server knows what each card does.
      final cardEffects = <String, dynamic>{};
      final cardTraits = <String, String>{};
      for (final card in _engine.currentPlayerHand) {
        final petPending = mySelections[card.ownerPetId] ?? [];
        if (!petPending.contains(card.instanceId)) continue;
        final eff = card.trait.effect;
        final effType = switch (eff.type) {
          EffectType.damage => 'damage',
          EffectType.heal => 'heal',
          EffectType.shield => 'shield',
          EffectType.shieldBreak => 'shieldBreak',
          EffectType.buff => switch (eff.buffType) {
              BuffType.regen => 'regen',
              BuffType.energized => 'energized',
              BuffType.attackUp => 'atk_up',
              BuffType.defenseUp => 'def_up',
              BuffType.speedUp => 'spd_up',
              BuffType.moraleUp => 'morale_up',
              null => 'buff',
            },
          EffectType.debuff => switch (eff.debuffType) {
              DebuffType.poisoned => 'poison',
              DebuffType.burned => 'burn',
              DebuffType.stunned => 'stun',
              DebuffType.sleep => 'sleep',
              DebuffType.fear => 'fear',
              DebuffType.aroma => 'aroma',
              DebuffType.chill => 'chill',
              DebuffType.jinx => 'jinx',
              DebuffType.healBlocked => 'heal_block',
              DebuffType.critBlocked => 'crit_block',
              DebuffType.disabled => 'disabled',
              DebuffType.reflect => 'reflect',
              DebuffType.stench => 'stench',
              DebuffType.attackDown => 'atk_down',
              DebuffType.defenseDown => 'def_down',
              DebuffType.speedDown => 'spd_down',
              DebuffType.isolate => 'isolate',
              DebuffType.moraleDown => 'morale_down',
              DebuffType.fragile => 'fragile',
              DebuffType.lethal => 'lethal',
              null => 'debuff',
            },
        };
        cardEffects[card.instanceId] = {
          'effectType': effType,
          'effectValue': eff.value,
          'target': eff.target,
        };
        cardTraits[card.instanceId] = card.trait.id;
      }

      PvpSocket.instance.send(OutRoundSubmit(
        matchId: _matchId,
        round: expectedRound,
        selections: mySelections,
        petStates: petStatesSnapshot,
        cardEffects: cardEffects,
        cardTraits: cardTraits,
      ).toJson());

      print(
          '[PvP] Submitted round $expectedRound — awaiting server round:result');
      _trace('submit:round:sent', {
        'round': expectedRound,
        'selectedPets': mySelections.length,
      });
      state = state.copyWith(awaitingOpponent: true, isResolving: true);
      return; // _commitServerRoundResult will set awaitingOpponent: false, isResolving: false
    }

    // ── PvE path: wait for round:locked then run local engine ─────────────────

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

    final petStatesSnapshot = [..._playerPets, ..._enemyPets]
        .map((pet) => {
              'uid': pet.id,
              'name': pet.name,
              'hp': pet.hp,
              'maxHp': pet.maxHp,
              'shield': pet.shield,
              'isFainted': pet.isFainted,
              'spd': pet.speed,
              'skl': pet.skill,
              'mor': pet.morale,
              'dex': 0,
              'def': 0,
              'statusEffects': [],
            })
        .toList();

    PvpSocket.instance.send(OutRoundSubmit(
      matchId: _matchId,
      round: expectedRound,
      selections: mySelections,
      petStates: petStatesSnapshot,
    ).toJson());

    state = state.copyWith(awaitingOpponent: true);
    Map<String, List<String>> opponentSelections;
    try {
      opponentSelections = await waiter.future
          .timeout(const Duration(seconds: 70), onTimeout: () {
        print('[PvP] Round timeout — proceeding with empty selections');
        return {};
      });
    } catch (e) {
      print('[PvP] Error waiting for opponent: $e');
      _trace('submit:round:wait:error', {'error': e.toString()});
      opponentSelections = {};
    }
    _opponentChoicesCompleter = null;
    _awaitingRound = null;
    if (!mounted) return;

    state = state.copyWith(awaitingOpponent: false);

    // Feed opponent choices into engine, then run round (PvE only)
    _engine.setOpponentChoices(opponentSelections);
    final started = _engine.prepareRound(mySelections);

    // 🔍 DIAGNOSTIC: Log turn order for sync debugging
    if (started.hasImmediateResult) {
      final roundState = started.immediateResult!.state;
      print('\n[PvP] ═══ ROUND ${roundState.round} EXECUTED ═══');
      print('[PvP] Round Log: ${roundState.roundLog}');
      print('[PvP] Player Team after round:');
      for (var i = 0; i < roundState.teamA.length; i++) {
        final pet = roundState.teamA[i];
        print(
            '  Pet $i: ${pet.name} | HP: ${pet.hp}/${pet.maxHp} | Fainted: ${pet.isFainted}');
      }
      print('[PvP] Enemy Team after round:');
      for (var i = 0; i < roundState.teamB.length; i++) {
        final pet = roundState.teamB[i];
        print(
            '  Pet $i: ${pet.name} | HP: ${pet.hp}/${pet.maxHp} | Fainted: ${pet.isFainted}');
      }
      print('═' * 80);
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
        isBloodMoon: _engine.isBloodMoonRound,
        pendingSkills: const {},
        petAnimStates: const {},
        petEffectVfx: const {},
        isResolving: false,
      );
      _syncBloodMoonAudio(_engine.isBloodMoonRound);
      if (immediate.isBattleOver)
        _sendClientResult(immediate.log, immediate.outcome);
      return;
    }

    // Resolve each action in strict turn order — Axie-style animation pacing.
    for (final action in started.actionQueue) {
      if (!mounted) return;
      final actorId = action.actor.id;

      _logAction(
        round: _engine.round,
        actorId: actorId,
        actionName: action.trait.name,
        targetId: action.primaryTarget?.id,
        energyUsed: action.trait.energyCost,
        damageDealt: null,
      );

      final isNoTarget = action.trait.effect.type == EffectType.damage &&
          action.primaryTarget != null &&
          action.primaryTarget!.isFainted;
      final partSlot = action.trait.part.name;

      // Actor fainted or target fizzled — execute silently.
      if (action.actor.isFainted || isNoTarget) {
        final step = _engine.executeNextAction();
        state = state.copyWith(
          currentRound: step.state.round,
          playerTeam: _snapshotsToVMs(step.state.teamA, _playerPets),
          enemyTeam: _snapshotsToVMs(step.state.teamB, _enemyPets),
          roundLog: step.log,
          turnOrder: _buildTurnOrder(),
          playerTeamEnergy: _engine.playerEnergy.energy,
          enemyTeamEnergy: _engine.enemyEnergy.energy,
          petAnimStates: const {},
          petEffectVfx: const {},
          petAttackSlots: const {},
          petDashOffsets: const {},
          petDashTargets: const {},
        );
        continue;
      }

      final isPlayerActor = _playerPets.any((p) => p.id == actorId);
      final opposingTeam = isPlayerActor ? _enemyPets : _playerPets;
      final isDamage = action.trait.effect.type == EffectType.damage;
      final isRanged = isDamage && _isRangedCard(action.trait);
      final isMelee = isDamage && !isRanged;

      if (isMelee) {
        // ── MELEE ─────────────────────────────────────────────────────────
        final targetPet = _resolveAnimTarget(action, opposingTeam);
        Offset dashDir = Offset.zero;
        String? dashTargetId;

        if (targetPet != null) {
          dashTargetId = targetPet.id;
          final actorIdx = (isPlayerActor
                  ? _playerPets.indexWhere((p) => p.id == actorId)
                  : _enemyPets.indexWhere((p) => p.id == actorId))
              .clamp(0, 2);
          final targetIdx =
              opposingTeam.indexWhere((p) => p.id == targetPet.id).clamp(0, 2);
          final actorBase = isPlayerActor
              ? _playerBattlePos[actorIdx]
              : _enemyBattlePos[actorIdx];
          final targetBase = isPlayerActor
              ? _enemyBattlePos[targetIdx]
              : _playerBattlePos[targetIdx];
          final toTarget = Offset(
            targetBase.dx - actorBase.dx,
            targetBase.dy - actorBase.dy,
          );
          final distance = toTarget.distance;
          if (distance > 0.0001) {
            const minGap = 0.06;
            const maxDash = 0.22;
            final d = math.min(maxDash, math.max(0.0, distance - minGap));
            dashDir = Offset(
                toTarget.dx / distance * d, toTarget.dy / distance * d);
          }
        }

        state = state.copyWith(
          petAnimStates: {actorId: PetCharacterAnimState.move},
          petAttackSlots: {actorId: partSlot},
          petDashOffsets:
              dashDir != Offset.zero ? {actorId: dashDir} : const {},
          petDashTargets:
              dashTargetId != null ? {actorId: dashTargetId} : const {},
        );
        await Future.delayed(const Duration(milliseconds: _kPvpDashWaitMs));
        if (!mounted) return;

        final preHp = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.hp
        };
        final preShield = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.shield
        };
        final step = _engine.executeNextAction();
        final targetAnims = _pvpBuildTargetAnims(actorId, preHp, preShield);
        BattleAudioService.instance.playAttack('damage');

        state = state.copyWith(
          currentRound: step.state.round,
          playerTeam: _snapshotsToVMs(step.state.teamA, _playerPets),
          enemyTeam: _snapshotsToVMs(step.state.teamB, _enemyPets),
          roundLog: step.log,
          turnOrder: _buildTurnOrder(),
          playerTeamEnergy: _engine.playerEnergy.energy,
          enemyTeamEnergy: _engine.enemyEnergy.energy,
          petAnimStates: {
            actorId: PetCharacterAnimState.attackMelee,
            ...targetAnims,
          },
          petAttackSlots: {actorId: partSlot},
          petDashOffsets:
              dashDir != Offset.zero ? {actorId: dashDir} : const {},
        );
        await Future.delayed(const Duration(milliseconds: _kPvpImpactWaitMs));
        if (!mounted) return;

        if (_playerPets.every((p) => p.isFainted) ||
            _enemyPets.every((p) => p.isFainted)) {
          state = state.copyWith(
              petAnimStates: const {}, petEffectVfx: const {},
              petAttackSlots: const {}, petDashOffsets: const {},
              petDashTargets: const {});
          break;
        }

        state = state.copyWith(
          petAnimStates: {actorId: PetCharacterAnimState.idle},
          petDashOffsets: const {},
          petDashTargets: const {},
        );
        await Future.delayed(const Duration(milliseconds: _kPvpRecoilWaitMs));
        if (!mounted) return;
        state = state.copyWith(
            petAnimStates: const {}, petEffectVfx: const {}, petAttackSlots: const {});
        await Future.delayed(const Duration(milliseconds: _kPvpGapMs));
        if (!mounted) return;
      } else if (isRanged) {
        // ── RANGED ────────────────────────────────────────────────────────
        final targetPet = _resolveAnimTarget(action, opposingTeam);

        state = state.copyWith(
          petAnimStates: {actorId: PetCharacterAnimState.attackRanged},
          petAttackSlots: {actorId: partSlot},
          petEffectVfx: {actorId: 'damage'},
          pendingProjectileToken: state.pendingProjectileToken + 1,
          pendingProjectileActorId: actorId,
          pendingProjectileTargetId: targetPet?.id ?? '',
          pendingProjectileClass: action.actor.creatureClass.name,
        );
        BattleAudioService.instance.playAttack('damage');
        await Future.delayed(const Duration(milliseconds: _kPvpProjectileWaitMs));
        if (!mounted) return;

        final preHp = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.hp
        };
        final preShield = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.shield
        };
        final step = _engine.executeNextAction();
        final targetAnims = _pvpBuildTargetAnims(actorId, preHp, preShield);

        state = state.copyWith(
          currentRound: step.state.round,
          playerTeam: _snapshotsToVMs(step.state.teamA, _playerPets),
          enemyTeam: _snapshotsToVMs(step.state.teamB, _enemyPets),
          roundLog: step.log,
          turnOrder: _buildTurnOrder(),
          playerTeamEnergy: _engine.playerEnergy.energy,
          enemyTeamEnergy: _engine.enemyEnergy.energy,
          petAnimStates: {actorId: PetCharacterAnimState.idle, ...targetAnims},
          petAttackSlots: const {},
          petEffectVfx: const {},
          clearPendingProjectile: true,
        );
        await Future.delayed(const Duration(milliseconds: _kPvpHitWaitMs));
        if (!mounted) return;

        if (_playerPets.every((p) => p.isFainted) ||
            _enemyPets.every((p) => p.isFainted)) {
          state = state.copyWith(
              petAnimStates: const {}, petEffectVfx: const {}, petAttackSlots: const {});
          break;
        }
        state = state.copyWith(petAnimStates: const {}, petEffectVfx: const {});
        await Future.delayed(const Duration(milliseconds: _kPvpGapMs));
        if (!mounted) return;
      } else {
        // ── AOE / SUPPORT ─────────────────────────────────────────────────
        final effectType = (action.trait.effect.type == EffectType.buff &&
                action.trait.effect.buffType == BuffType.regen)
            ? 'heal'
            : action.trait.effect.type.name;

        state = state.copyWith(
          petAnimStates: {actorId: _animStateForEffect(effectType)},
          petEffectVfx: {actorId: effectType},
          petAttackSlots: {actorId: partSlot},
        );
        BattleAudioService.instance.playAttack(effectType);
        await Future.delayed(const Duration(milliseconds: _kPvpEffectWindupMs));
        if (!mounted) return;

        final preHp = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.hp
        };
        final preShield = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.shield
        };
        final step = _engine.executeNextAction();
        final targetAnims = _pvpBuildTargetAnims(actorId, preHp, preShield);

        state = state.copyWith(
          currentRound: step.state.round,
          playerTeam: _snapshotsToVMs(step.state.teamA, _playerPets),
          enemyTeam: _snapshotsToVMs(step.state.teamB, _enemyPets),
          roundLog: step.log,
          turnOrder: _buildTurnOrder(),
          playerTeamEnergy: _engine.playerEnergy.energy,
          enemyTeamEnergy: _engine.enemyEnergy.energy,
          petAnimStates: {actorId: _animStateForEffect(effectType), ...targetAnims},
          petAttackSlots: {actorId: partSlot},
        );
        await Future.delayed(const Duration(milliseconds: _kPvpEffectResultMs));
        if (!mounted) return;

        if (_playerPets.every((p) => p.isFainted) ||
            _enemyPets.every((p) => p.isFainted)) {
          state = state.copyWith(
              petAnimStates: const {}, petEffectVfx: const {},
              petAttackSlots: const {}, petDashOffsets: const {},
              petDashTargets: const {});
          break;
        }
        state = state.copyWith(
            petAnimStates: const {}, petEffectVfx: const {}, petAttackSlots: const {});
        await Future.delayed(const Duration(milliseconds: _kPvpGapMs));
        if (!mounted) return;
      }
    }

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
      isBloodMoon: _engine.isBloodMoonRound,
      pendingSkills: const {},
      petAnimStates: const {},
      petEffectVfx: const {},
    );
    _syncBloodMoonAudio(_engine.isBloodMoonRound);

    if (result.isBattleOver) {
      _sendClientResult(result.log, result.outcome);
      state = state.copyWith(isResolving: false);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final newHand = _buildHandVMs(_engine.currentPlayerHand, const {});
    await _animateDrawnCards(handBeforeIds, newHand);
    if (!mounted) return;

    state = state.copyWith(
      isResolving: false,
      newCardIds: const {},
      needsDiscard: false,
      excessDiscards: 0,
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

    // Fallback: if server doesn't send PvpMatchEnd within 8 s, resolve locally.
    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted || state.pvpMatchEnd != null) return;
      final localWinner = switch (outcome) {
        BattleOutcome.teamAWins => _myUserId,
        BattleOutcome.teamBWins => _opponentUserId,
        _ => null,
      };
      state = state.copyWith(
        pvpMatchEnd: PvpMatchEndData(
          winnerUid: localWinner,
          dispute: outcome == null,
          mmrDelta: 0,
        ),
        isBattleOver: true,
      );
    });
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

  // ── Shield pre-application disabled in PvP ─────────────────────────────────
  // PvP state must remain server-authoritative; card clicks only update pending
  // assignments and UI selection, never local HP/shield.

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
            speed: p.effectiveSpeed,
            hp: p.hp,
            skill: p.skill,
            morale: p.morale,
            isPlayer: true,
            isFainted: p.isFainted,
            texturePath: _avatarPath(p.id)),
      for (final p in _enemyPets)
        TurnOrderEntry(
            petId: p.id,
            name: p.name,
            speed: p.effectiveSpeed,
            hp: p.hp,
            skill: p.skill,
            morale: p.morale,
            isPlayer: false,
            isFainted: p.isFainted,
            texturePath: _avatarPath(p.id)),
    ];
    all.sort((a, b) {
      if (a.speed != b.speed) return b.speed.compareTo(a.speed);
      if (a.hp != b.hp) return a.hp.compareTo(b.hp);
      if (a.skill != b.skill) return b.skill.compareTo(a.skill);
      if (a.morale != b.morale) return b.morale.compareTo(a.morale);
      return a.petId.compareTo(b.petId);
    });
    return all;
  }

  String? _avatarPath(String petId) {
    final def = _defFor(petId);
    if (def != null) {
      return def.partCardArt['horn'] ??
          def.partCardArt['back'] ??
          def.partCardArt['tail'] ??
          def.partCardArt['mouth'];
    }
    final cls = kCreatureRegistry[petId]?.className;
    return cls != null ? 'assets/images/icons/mini-$cls.png' : null;
  }

  static const _kRangedTraitIds = {'bird_tail', 'bird_horn'};

  bool _isRangedCard(Trait trait) =>
      trait.part == TraitPart.back || _kRangedTraitIds.contains(trait.id);

  Pet? _resolveAnimTarget(Action action, List<Pet> opposingTeam) {
    if (action.primaryTarget != null) {
      return action.primaryTarget!.isFainted ? null : action.primaryTarget;
    }
    final alive = opposingTeam.where((p) => !p.isFainted).toList();
    if (alive.isEmpty) return null;
    final spec = action.trait.effect.target;
    if (spec == 'furthest_enemy' || spec == 'back_enemy') return alive.last;
    if (spec == 'lowest_hp_enemy') {
      alive.sort((a, b) => a.hp.compareTo(b.hp));
      return alive.first;
    }
    if (spec == 'fastest_enemy') {
      alive.sort((a, b) => b.speed.compareTo(a.speed));
      return alive.first;
    }
    return alive.first;
  }

  Map<String, PetCharacterAnimState> _pvpBuildTargetAnims(
    String actorId,
    Map<String, int> preHp,
    Map<String, int> preShield,
  ) {
    final anims = <String, PetCharacterAnimState>{};
    for (final p in [..._playerPets, ..._enemyPets]) {
      if (p.id == actorId) continue;
      if (p.hp < (preHp[p.id] ?? p.hp) ||
          p.shield < (preShield[p.id] ?? p.shield)) {
        anims[p.id] =
            p.isFainted ? PetCharacterAnimState.faint : PetCharacterAnimState.hit;
      }
    }
    return anims;
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
      [for (final pet in pets) _petVM(pet, pet.row)];

  List<PetViewModel> _snapshotsToVMs(
          List<PetSnapshot> snaps, List<Pet> livePets) =>
      [for (var i = 0; i < snaps.length; i++) _snapVM(snaps[i], livePets[i], livePets[i].row)];

  CreatureDefinition? _defFor(String petId) =>
      _petDefs[petId] ?? kCreatureRegistry[petId];

  PetViewModel _petVM(Pet pet, int position) {
    final def = _defFor(pet.id);
    return _snapVM(
      PetSnapshot.fromLive(pet),
      pet,
      position,
      spriteConfig: def?.spriteConfig,
      partCardArt: def?.partCardArt ?? const {},
      creatureDef: def,
    );
  }

  PetViewModel _snapVM(
    PetSnapshot snap,
    Pet livePet,
    int position, {
    PetSpriteConfig? spriteConfig,
    Map<String, String> partCardArt = const {},
    CreatureDefinition? creatureDef,
  }) {
    final def = _defFor(livePet.id);
    return PetViewModel.fromSnapshot(snap, livePet.traits, livePet, position,
        spriteConfig: spriteConfig ?? def?.spriteConfig,
        partCardArt:
            partCardArt.isNotEmpty ? partCardArt : def?.partCardArt ?? const {},
        creatureDef: creatureDef ?? def);
  }

  @override
  void dispose() {
    BattleAudioService.instance.stopOwnedBgm(_audioOwner);
    _wsSub?.cancel();
    _pendingRoundResultTimer?.cancel();
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
