import 'dart:math' as math;
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:likha_pet_battle_engine/action.dart';
import 'package:likha_pet_battle_engine/battle_state.dart';
import 'package:likha_pet_battle_engine/pet.dart';
import 'package:likha_pet_battle_engine/skill_card.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../data/creature_registry.dart';
import '../engine/interactive_battle_engine.dart';
import '../screens/battle_screen.dart' show BattleScreenArgs;
import '../services/battle_audio_service.dart';
import '../services/mixed_skeleton_service.dart';
import '../widgets/pet_character_widget.dart'
    show PetCharacterAnimState, PetCharacterConfig;
import '../../pets/models/owned_pet.dart';
import '../../pets/providers/player_provider.dart';
import '../../pve/data/stage_registry.dart';
import 'battle_view_model.dart';

class PveBattleNotifier extends StateNotifier<PveBattleViewModel> {
  static const String _audioOwner = 'pve_battle';
  late final InteractiveBattleEngine _engine;
  late final List<Pet> _playerPets;
  late final List<Pet> _enemyPets;
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

  // instanceId → (petId, shieldAmount) for shields pre-applied during planning.
  final Map<String, ({String petId, int amount})> _preAppliedShields = {};

  // petId → PetCharacterConfig with mixed skeleton
  final Map<String, PetCharacterConfig> _mixedSkeletonConfigs = {};

  static const String _normalBgm = 'audio/battle/battle_sound.ogg';
  static const String _bloodMoonBgm = 'audio/battle/blood_moon_bg.ogg';
  static const double _normalBgmVolume = 0.22;
  static const double _bloodMoonBgmVolume = 0.24;

  PveBattleNotifier({
    required String playerTeamName,
    required String enemyTeamName,
    List<Pet>? playerPets,
    List<Pet>? enemyPets,
    List<OwnedPet>? activeRoster,
  }) : super(PveBattleViewModel.initial()) {
    // playerPets must be provided via activeRoster from playerProvider.
    // If somehow called without pets, fall back to an empty list and let
    // the battle engine handle it gracefully.
    _playerPets = playerPets ?? [];
    _enemyPets = enemyPets ?? _teamBeta();
    if (activeRoster != null) _registerPlayerDefs(activeRoster);

    _engine = InteractiveBattleEngine(
      playerTeam: _playerPets,
      enemyTeam: _enemyPets,
      playerTeamName: playerTeamName,
      enemyTeamName: enemyTeamName,
    );

    // Initialize mixed skeletons asynchronously
    _initializeMixedSkeletons().then((_) {
      state = PveBattleViewModel(
        currentRound: 1,
        playerTeam: _toViewModels(_playerPets, isPlayer: true),
        enemyTeam: _toViewModels(_enemyPets, isPlayer: false),
        roundLog: '',
        isBattleOver: false,
        playerTeamName: playerTeamName,
        enemyTeamName: enemyTeamName,
        turnOrder: _buildTurnOrder(),
        selectedPetId: null,
        pendingSkills: const {},
        hand: _buildHandVMs(_engine.currentPlayerHand, const {}),
        deckDrawSize: _engine.playerDeckDrawSize,
        deckDiscardSize: _engine.playerDeckDiscardSize,
        playerTeamEnergy: _engine.playerEnergy.energy,
        enemyTeamEnergy: _engine.enemyEnergy.energy,
      );
    }).catchError((e) {
      // Fallback to pre-baked skeletons if mixer fails
      _devLog('❌ Failed to initialize mixed skeletons: $e');
      state = PveBattleViewModel(
        currentRound: 1,
        playerTeam: _toViewModels(_playerPets, isPlayer: true),
        enemyTeam: _toViewModels(_enemyPets, isPlayer: false),
        roundLog: '',
        isBattleOver: false,
        playerTeamName: playerTeamName,
        enemyTeamName: enemyTeamName,
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

  // ── Player actions ─────────────────────────────────────────────────────────

  void selectPet(String petId) {
    if (state.isBattleOver || state.isResolving) return;
    state = state.copyWith(selectedPetId: petId);
  }

  void clearSelectedPet() {
    if (state.isBattleOver || state.isResolving) return;
    state = state.copyWith(selectedPetId: null);
  }

  void setBattlePositions({
    required List<Offset> playerPos,
    required List<Offset> enemyPos,
  }) {
    if (playerPos.length < 3 || enemyPos.length < 3) return;
    _playerBattlePos = List<Offset>.from(playerPos);
    _enemyBattlePos = List<Offset>.from(enemyPos);
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

  /// Assign a drawn card to its owner pet.
  /// Multiple cards per pet are allowed — tapping again deselects.
  void assignSkill(String cardInstanceId) {
    if (state.isBattleOver || state.isResolving || state.needsDiscard) return;

    final card = _engine.currentPlayerHand
        .where((c) => c.instanceId == cardInstanceId)
        .firstOrNull;
    if (card == null) return;

    final petId = card.ownerPetId;
    final newPending = state.pendingSkills.map(
      (k, v) => MapEntry(k, List<String>.from(v)),
    );
    final currentList = List<String>.from(newPending[petId] ?? []);

    if (currentList.contains(cardInstanceId)) {
      // Already assigned → toggle off.
      currentList.remove(cardInstanceId);
      if (currentList.isEmpty) {
        newPending.remove(petId);
      } else {
        newPending[petId] = currentList;
      }
      // Un-apply any pre-applied shield from this card.
      _removePreAppliedShield(cardInstanceId);
      state = state.copyWith(
        pendingSkills: newPending,
        playerTeam: _livePlayerTeamVMs(),
        hand: _buildHandVMs(_engine.currentPlayerHand, newPending),
      );
      BattleAudioService.instance.playCardUnplay();
      return;
    }

    // Add this card to the list.
    currentList.add(cardInstanceId);
    newPending[petId] = currentList;

    // Apply shield immediately so the HP bar reflects it during planning.
    _applyPreShield(card);

    state = state.copyWith(
      pendingSkills: newPending,
      playerTeam: _livePlayerTeamVMs(),
      hand: _buildHandVMs(_engine.currentPlayerHand, newPending),
    );
    BattleAudioService.instance.playCardPlay();
  }

  /// Discard a specific card from the player's hand (overflow discard phase).
  void discardCard(String cardInstanceId) {
    _engine.discardFromPlayerHand(cardInstanceId);
    // Remove this card from any pending assignment list.
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

  /// Execute one round in four paced phases so animations are clearly visible.
  Future<void> executeRound() async {
    if (state.isResolving || state.isBattleOver) return;

    final handBeforeIds = state.hand.map((c) => c.instanceId).toSet();
    final pendingSnapshot = state.pendingSkills.map(
      (k, v) => MapEntry(k, List<String>.from(v)),
    );

    // Keep pre-applied shields visible — they will be undone per-action just
    // before the resolver re-applies them so values stay correct.
    state = state.copyWith(isResolving: true);

    final started = _engine.prepareRound(pendingSnapshot);
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
      return;
    }

    // Resolve every queued action in strict turn order, Axie-style.
    for (final action in started.actionQueue) {
      if (!mounted) return;

      final actorId = action.actor.id;
      final partSlot = action.trait.part.name;
      final isPlayerActor = _playerPets.any((p) => p.id == actorId);
      final opposingTeam = isPlayerActor ? _enemyPets : _playerPets;

      final isNoTarget = action.trait.effect.type == EffectType.damage &&
          action.primaryTarget != null &&
          action.primaryTarget!.isFainted;

      // Actor already fainted or target fizzled — execute silently, no anim.
      if (action.actor.isFainted || isNoTarget) {
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
          petAnimStates: const {},
          petEffectVfx: const {},
          petAttackSlots: const {},
          petDashOffsets: const {},
          petDashTargets: const {},
        );
        continue;
      }

      final isDamage = action.trait.effect.type == EffectType.damage;
      final isRanged = isDamage && _isRangedCard(action.trait);
      final isMelee = isDamage && !isRanged;

      if (isMelee) {
        // ── MELEE: dash → impact → recoil ─────────────────────────────────
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
            dashDir =
                Offset(toTarget.dx / distance * d, toTarget.dy / distance * d);
          }
        }

        // Phase 1: dash forward (550ms — AnimatedPositioned is 500ms, +50ms buffer)
        state = state.copyWith(
          petAnimStates: {actorId: PetCharacterAnimState.move},
          petAttackSlots: {actorId: partSlot},
          petDashOffsets:
              dashDir != Offset.zero ? {actorId: dashDir} : const {},
          petDashTargets:
              dashTargetId != null ? {actorId: dashTargetId} : const {},
        );
        await Future.delayed(const Duration(milliseconds: 550));
        if (!mounted) return;

        // Phase 2: impact — execute engine, play attack clip, show hit (500ms)
        final preHp = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.hp
        };
        final preShield = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.shield
        };
        _undoPreShieldIfNeeded(action.actor, action.trait);
        final step = _engine.executeNextAction();

        final targetAnims = _buildTargetAnims(actorId, preHp, preShield);
        if (targetAnims.isNotEmpty) {
        }
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
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        if (_playerPets.every((p) => p.isFainted) ||
            _enemyPets.every((p) => p.isFainted)) {
          state = state.copyWith(
              petAnimStates: const {},
              petEffectVfx: const {},
              petAttackSlots: const {},
              petDashOffsets: const {},
              petDashTargets: const {});
          break;
        }

        // Phase 3: recoil back (450ms)
        state = state.copyWith(
          petAnimStates: {actorId: PetCharacterAnimState.idle},
          petDashOffsets: const {},
          petDashTargets: const {},
        );
        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;

        // Gap (200ms)
        state = state.copyWith(
            petAnimStates: const {},
            petEffectVfx: const {},
            petAttackSlots: const {});
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
      } else if (isRanged) {
        // ── RANGED: attack windup + projectile → impact ────────────────────
        final targetPet = _resolveAnimTarget(action, opposingTeam);

        // Phase 1: attack windup + spawn projectile (400ms travel)
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
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;

        // Phase 2: projectile lands — execute engine, hit anim (450ms)
        final preHp = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.hp
        };
        final preShield = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.shield
        };
        _undoPreShieldIfNeeded(action.actor, action.trait);
        final step = _engine.executeNextAction();

        final targetAnims = _buildTargetAnims(actorId, preHp, preShield);
        if (targetAnims.isNotEmpty) {
        }

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
        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;

        if (_playerPets.every((p) => p.isFainted) ||
            _enemyPets.every((p) => p.isFainted)) {
          state = state.copyWith(
              petAnimStates: const {},
              petEffectVfx: const {},
              petAttackSlots: const {});
          break;
        }

        // Gap (200ms)
        state = state.copyWith(
            petAnimStates: const {}, petEffectVfx: const {});
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
      } else {
        // ── AOE / SUPPORT (heal, shield, buff, debuff, aoe) ───────────────
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
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        final preHp = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.hp
        };
        final preShield = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.shield
        };
        _undoPreShieldIfNeeded(action.actor, action.trait);
        final step = _engine.executeNextAction();

        final targetAnims = _buildTargetAnims(actorId, preHp, preShield);
        if (targetAnims.isNotEmpty) {
        }

        state = state.copyWith(
          currentRound: step.state.round,
          playerTeam: _snapshotsToVMs(step.state.teamA, _playerPets),
          enemyTeam: _snapshotsToVMs(step.state.teamB, _enemyPets),
          roundLog: step.log,
          turnOrder: _buildTurnOrder(),
          playerTeamEnergy: _engine.playerEnergy.energy,
          enemyTeamEnergy: _engine.enemyEnergy.energy,
          petAnimStates: {
            actorId: _animStateForEffect(effectType),
            ...targetAnims,
          },
          petAttackSlots: {actorId: partSlot},
        );
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;

        if (_playerPets.every((p) => p.isFainted) ||
            _enemyPets.every((p) => p.isFainted)) {
          state = state.copyWith(
              petAnimStates: const {},
              petEffectVfx: const {},
              petAttackSlots: const {},
              petDashOffsets: const {},
              petDashTargets: const {});
          break;
        }

        // Gap (200ms)
        state = state.copyWith(
            petAnimStates: const {},
            petEffectVfx: const {},
            petAttackSlots: const {});
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
      }
    }

    // Clear any remaining entries (pets that were stunned and skipped their action).
    _preAppliedShields.clear();

    final result = _engine.finishRound();

    // Drop cards of fainted pets before updating teams.
    final faintedIds =
        _playerPets.where((p) => p.isFainted).map((p) => p.id).toSet();
    for (final card in List.of(_engine.currentPlayerHand)) {
      if (faintedIds.contains(card.ownerPetId)) {
        _engine.discardFromPlayerHand(card.instanceId);
      }
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
      state = state.copyWith(isResolving: false);
      return;
    }

    // Brief pause so the player can see damage results.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // ── Phase 3: Draw cards with entrance animation ───────────────────────────
    final newHand = _buildHandVMs(_engine.currentPlayerHand, const {});
    await _animateDrawnCards(handBeforeIds, newHand);
    if (!mounted) return;

    // ── Phase 4: Clear animations, open discard modal if needed ──────────────
    final excess = (_engine.currentPlayerHand.length - 10).clamp(0, 100);
    state = state.copyWith(
      isResolving: false,
      newCardIds: const {},
      needsDiscard: excess > 0,
      excessDiscards: excess,
    );

    // If the hand is over the cap, give the player 8 seconds to discard
    // manually. If they haven't acted by then, auto-discard for them.
    if (excess > 0) {
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && state.needsDiscard) _autoDiscard();
      });
    }
  }

  /// Auto-discard excess cards using a priority strategy:
  ///   1. On-cooldown cards (can't be used anyway)
  ///   2. Non-pity cards with lowest effect value
  void _autoDiscard() {
    final needed = (_engine.currentPlayerHand.length - 10).clamp(0, 100);
    if (needed <= 0) return;

    final candidates = List.of(_engine.currentPlayerHand)
      ..sort((a, b) {
        // On-cooldown = discard first
        final aCool = a.trait.isReady ? 1 : 0;
        final bCool = b.trait.isReady ? 1 : 0;
        if (aCool != bCool) return aCool.compareTo(bCool);
        // Pity cards = keep (sort to end)
        final aPity = a.isPity ? 1 : 0;
        final bPity = b.isPity ? 1 : 0;
        if (aPity != bPity) return aPity.compareTo(bPity);
        // Lowest effect value = discard first
        return a.trait.effect.value.compareTo(b.trait.effect.value);
      });

    for (int i = 0; i < needed && i < candidates.length; i++) {
      _engine.discardFromPlayerHand(candidates[i].instanceId);
    }

    final newHand = _buildHandVMs(_engine.currentPlayerHand, const {});
    state = state.copyWith(
      hand: newHand,
      deckDiscardSize: _engine.playerDeckDiscardSize,
      needsDiscard: false,
      excessDiscards: 0,
    );
  }

  // ── Shield pre-application ─────────────────────────────────────────────────

  /// Shield amount a card will grant (EffectType.shield + selfShield).
  int _shieldForCard(SkillCard card) {
    int amount = 0;
    if (card.trait.effect.type == EffectType.shield) {
      amount += card.trait.effect.value;
    }
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

  /// Undo the pre-applied shield for [actor] only when [trait] is a
  /// shield-granting action — called just before the resolver executes it so
  /// the resolver re-applies the correct amount without doubling.
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
    if (total > 0) {
      actor.shield = (actor.shield - total).clamp(0, 999);
    }
  }

  /// Snapshot of the live player pets — used to reflect pre-applied shields.
  List<PetViewModel> _livePlayerTeamVMs() => [
        for (var i = 0; i < _playerPets.length; i++)
          _snapVM(PetSnapshot.fromLive(_playerPets[i]), _playerPets[i], i),
      ];

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<CardViewModel> _buildHandVMs(
    List<SkillCard> hand,
    Map<String, List<String>> pending,
  ) {
    // Sum energy cost of all assigned cards across all pets.
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
      final ownerDef = _defFor(owner.id);
      final partSlot = card.trait.part.name;
      final cardArtPathOverride = ownerDef?.partCardArt[partSlot];
      return CardViewModel.fromCard(
        card,
        owner,
        availableEnergy: isAssigned ? null : remaining,
        cardArtPathOverride: cardArtPathOverride,
      );
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
          texturePath: _classIconPath(p.id),
        ),
      for (final p in _enemyPets)
        TurnOrderEntry(
          petId: p.id,
          name: p.name,
          speed: p.speed,
          isPlayer: false,
          isFainted: p.isFainted,
          texturePath: _classIconPath(p.id),
        ),
    ];
    all.sort((a, b) => b.speed.compareTo(a.speed));
    return all;
  }

  static String? _classIconPath(String petId) {
    final cls = kCreatureRegistry[petId]?.className;
    if (cls == null) return null;
    return 'assets/images/icons/mini-$cls.png';
  }

  // ── Attack-style classification ────────────────────────────────────────────

  /// Back-part cards fire a projectile; specific trait IDs also classified ranged.
  static const _kRangedTraitIds = {'bird_tail', 'bird_horn'};

  bool _isRangedCard(Trait trait) =>
      trait.part == TraitPart.back || _kRangedTraitIds.contains(trait.id);

  /// Resolve which enemy pet the animation should track (melee dash or
  /// ranged projectile target). Handles all targeting specs from effect.target.
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

  /// Build hit/faint anim map for all pets that lost HP or shield this step.
  Map<String, PetCharacterAnimState> _buildTargetAnims(
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

  List<PetViewModel> _toViewModels(List<Pet> pets, {required bool isPlayer}) {
    return [
      for (var i = 0; i < pets.length; i++) _petVM(pets[i], i),
    ];
  }

  List<PetViewModel> _snapshotsToVMs(
    List<PetSnapshot> snaps,
    List<Pet> livePets,
  ) {
    return [
      for (var i = 0; i < snaps.length; i++) _snapVM(snaps[i], livePets[i], i),
    ];
  }

  // Look up creature definition for view-model building.
  // Registry pets (enemy AI) are found by ID directly.
  // Player pets built from OwnedPet use the UUID as ID — no registry entry,
  // but we store a uid→definition map populated at construction.
  final Map<String, CreatureDefinition> _petDefs = {};

  void _registerPlayerDefs(List<OwnedPet> activeRoster) {
    for (final p in activeRoster) {
      _petDefs[p.uid] = p.toCreatureDefinition();
    }
  }

  /// Pre-mix all creature skeletons for both player and enemy teams.
  /// This runs async during battle initialization to avoid blocking the UI.
  Future<void> _initializeMixedSkeletons() async {
    try {
      final service = await MixedSkeletonService.instance();

      // Mix all player pets
      for (final pet in _playerPets) {
        final def = _defFor(pet.id);
        if (def != null) {
          try {
            final skeleton = await service.buildMixedSkeleton(def);
            _mixedSkeletonConfigs[pet.id] = PetCharacterConfig(
              texturePath: 'assets/spines/mixer/likha-2d-v3-all.png',
              spineAtlasPath: 'assets/spines/mixer/likha-2d-v3-all.atlas',
              skeletonJson: skeleton,
            );
            _devLog('✅ Mixed skeleton for ${pet.name} (${pet.id})');
          } catch (e) {
            _devLog('⚠️  Failed to mix ${pet.name}: $e');
          }
        }
      }

      // Mix all enemy pets
      for (final pet in _enemyPets) {
        final def = _defFor(pet.id);
        if (def != null) {
          try {
            final skeleton = await service.buildMixedSkeleton(def);
            _mixedSkeletonConfigs[pet.id] = PetCharacterConfig(
              texturePath: 'assets/spines/mixer/likha-2d-v3-all.png',
              spineAtlasPath: 'assets/spines/mixer/likha-2d-v3-all.atlas',
              skeletonJson: skeleton,
            );
            _devLog('✅ Mixed skeleton for ${pet.name} (${pet.id})');
          } catch (e) {
            _devLog('⚠️  Failed to mix ${pet.name}: $e');
          }
        }
      }
    } catch (e) {
      _devLog('❌ MixedSkeletonService failed to initialize: $e');
    }
  }

  CreatureDefinition? _defFor(String petId) =>
      _petDefs[petId] ?? kCreatureRegistry[petId];

  PetViewModel _petVM(Pet pet, int position) {
    final def = _defFor(pet.id);
    // Try to use mixed skeleton if available, otherwise fall back to pre-baked
    final characterConfig = _mixedSkeletonConfigs[pet.id] ?? def?.spineConfig;
    return PetViewModel.initial(
      pet.id,
      pet.name,
      pet.speed,
      position,
      pet.traits,
      pet,
      spriteConfig: def?.spriteConfig,
      characterConfig: characterConfig,
      partCardArt: def?.partCardArt ?? const {},
      creatureDef: def,
    );
  }

  PetViewModel _snapVM(PetSnapshot snap, Pet livePet, int position) {
    final def = _defFor(livePet.id);
    // Try to use mixed skeleton if available, otherwise fall back to pre-baked
    final characterConfig =
        _mixedSkeletonConfigs[livePet.id] ?? def?.spineConfig;
    return PetViewModel.fromSnapshot(
      snap,
      livePet.traits,
      livePet,
      position,
      spriteConfig: def?.spriteConfig,
      characterConfig: characterConfig,
      partCardArt: def?.partCardArt ?? const {},
      creatureDef: def,
    );
  }

  // ── Team builders ──────────────────────────────────────────────────────────

  /// Player team: built from the 3 active pets in the player's roster.
  /// Uses OwnedPet display names to strengthen pet identity in battle.
  /// Returns empty list if no roster — the HomeScreen blocks battle entry
  /// when the team isn't full, so this path should not normally be reached.
  static List<Pet> _buildPlayerTeam(List<OwnedPet> activeRoster) {
    return activeRoster
        .where((p) => kBodyCatalogue.containsKey(p.bodyId))
        .map((p) => p.toCreatureDefinition().toPet(displayName: p.name))
        .toList();
  }

  /// Quick-battle enemy team (used when no stageId is given).
  static List<Pet> _teamBeta() => [
        kCreatureRegistry['reptile_1']!.toPet(),
        kCreatureRegistry['bird_1']!.toPet(),
        kCreatureRegistry['bug_1']!.toPet(),
      ];

  /// Build enemy team from a stage config, or fall back to quick-battle default.
  static List<Pet> _buildEnemyTeam(String? stageId) {
    if (stageId == null) return _teamBeta();
    final stage = stageById(stageId);
    return stage?.buildEnemyTeam() ?? _teamBeta();
  }

  @override
  void dispose() {
    BattleAudioService.instance.stopOwnedBgm(_audioOwner);
    super.dispose();
  }
}

// args provider — set before creating pveBattleProvider
final battleArgsProvider = StateProvider<BattleScreenArgs?>((_) => null);

final pveBattleProvider =
    StateNotifierProvider.autoDispose<PveBattleNotifier, PveBattleViewModel>(
  (ref) {
    final args = ref.read(battleArgsProvider);
    final playerData = ref.read(playerProvider);
    final activeRoster =
        playerData.hasFullTeam ? playerData.activeRoster : <OwnedPet>[];
    final stage = args?.stageId != null ? stageById(args!.stageId!) : null;
    return PveBattleNotifier(
      playerTeamName: args?.playerTeamName ?? 'My Team',
      enemyTeamName: stage?.name ?? (args?.enemyTeamName ?? 'Rivals'),
      playerPets: PveBattleNotifier._buildPlayerTeam(activeRoster),
      enemyPets: PveBattleNotifier._buildEnemyTeam(args?.stageId),
      activeRoster: activeRoster,
    );
  },
);
void _devLog(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}
