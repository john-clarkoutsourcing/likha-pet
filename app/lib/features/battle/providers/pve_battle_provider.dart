import 'dart:ui' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:likha_pet_battle_engine/action.dart';
import 'package:likha_pet_battle_engine/battle_logger.dart';
import 'package:likha_pet_battle_engine/battle_state.dart';
import 'package:likha_pet_battle_engine/pet.dart';
import 'package:likha_pet_battle_engine/skill_card.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../data/creature_registry.dart';
import '../engine/interactive_battle_engine.dart';
import '../screens/battle_screen.dart' show BattleScreenArgs;
import '../services/battle_audio_service.dart';
import '../widgets/pet_character_widget.dart' show PetCharacterAnimState;
import '../../pets/models/owned_pet.dart';
import '../../pets/models/player_data.dart';
import '../../pets/providers/player_provider.dart';
import '../../pve/data/stage_registry.dart';
import 'battle_view_model.dart';

// ── Animation timing constants ─────────────────────────────────────────────────
// All provider waits must be ≥ the corresponding HUD animation + 60 ms buffer.
// HUD AnimatedPositioned dash duration = 420 ms (see shared_battle_hud.dart).

const _kDashWaitMs       = 720; // 420 ms dash anim + 300 ms to let move clip finish
const _kImpactWaitMs     = 700; // Spine attack clips run up to ~650 ms
const _kHitWaitMs        = 480; // hit reaction (220 ms) + HP bar settle
const _kRecoilWaitMs     = 480; // same as dash forward (recoil = reverse dash)
const _kGapMs            = 260; // brief inter-card pause so each skill is readable
const _kProjectileWaitMs = 620; // projectile flight time
const _kEffectWindupMs   = 500; // AOE/support windup
const _kEffectResultMs   = 480; // effect settle + HP bar
const _kRoundPauseMs     = 500; // pause after all actions before card draw

class PveBattleNotifier extends StateNotifier<PveBattleViewModel> {
  static const String _audioOwner = 'pve_battle';
  late final InteractiveBattleEngine _engine;
  late final List<Pet> _playerPets;
  late final List<Pet> _enemyPets;
  List<Offset> _playerBattlePos = const [
    Offset(0.34, 0.34),
    Offset(0.20, 0.34),
    Offset(0.06, 0.34),
  ];
  List<Offset> _enemyBattlePos = const [
    Offset(0.46, 0.34),
    Offset(0.60, 0.34),
    Offset(0.74, 0.34),
  ];

  // instanceId → (petId, shieldAmount) for shields pre-applied during planning.
  final Map<String, ({String petId, int amount})> _preAppliedShields = {};
  int _visualEventCounter = 0;

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
    state = state.copyWith(
      hand: hand,
      pendingSkills: newPending,
      needsDiscard: false,
      excessDiscards: 0,
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
    state = state.copyWith(
      isResolving: true,
      clearResolvingCardQueue: true,
    );

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
        clearResolvingCardQueue: true,
        isResolving: false,
      );
      _syncBloodMoonAudio(_engine.isBloodMoonRound);
      return;
    }

    String? anchoredActorId;
    Offset anchoredDashDir = Offset.zero;
    String? anchoredTargetId;
    String? queuedActorId;

    Future<void> recoilAnchoredActor() async {
      if (anchoredActorId == null) return;
      final actorId = anchoredActorId!;
      state = state.copyWith(
        petAnimStates: {actorId: PetCharacterAnimState.idle},
        petDashOffsets: const {},
        petDashTargets: const {},
      );
      await Future.delayed(const Duration(milliseconds: _kRecoilWaitMs));
      if (!mounted) return;
      anchoredActorId = null;
      anchoredDashDir = Offset.zero;
      anchoredTargetId = null;
    }

    void beginQueuedCardsForActor(String actorId, int fromIndex) {
      if (queuedActorId == actorId && state.resolvingCardQueue.isNotEmpty) {
        return;
      }
      queuedActorId = actorId;
      final queue = <ResolvingCardItem>[];
      for (var i = fromIndex; i < started.actionQueue.length; i++) {
        final queued = started.actionQueue[i];
        if (queued.actor.id != actorId) break;
        queue.add(
          ResolvingCardItem(
            id: '${queued.actor.id}-${queued.trait.id}-$i',
            name: queued.trait.name,
            imagePath: _resolveActionCardImagePath(queued),
          ),
        );
      }
      state = state.copyWith(
        resolvingCardPetId: actorId,
        resolvingCardQueue: queue,
      );
    }

    void consumeQueuedCardForActor(String actorId) {
      if (state.resolvingCardPetId != actorId || state.resolvingCardQueue.isEmpty) {
        return;
      }
      final queue = List<ResolvingCardItem>.from(state.resolvingCardQueue);
      queue.removeAt(0);
      BattleAudioService.instance.playCardDraw();
      state = state.copyWith(
        resolvingCardQueue: queue,
        clearResolvingCardQueue: queue.isEmpty,
      );
      if (queue.isEmpty) queuedActorId = null;
    }

    // Resolve every queued action in strict turn order, Axie-style.
    for (var i = 0; i < started.actionQueue.length; i++) {
      final action = started.actionQueue[i];
      final nextActorId =
          i + 1 < started.actionQueue.length ? started.actionQueue[i + 1].actor.id : null;
      if (!mounted) return;

      final actorId = action.actor.id;
      final partSlot = action.trait.part.name;
      final isPlayerActor = _playerPets.any((p) => p.id == actorId);
      final opposingTeam = isPlayerActor ? _enemyPets : _playerPets;

      beginQueuedCardsForActor(actorId, i);

      // Actor already fainted — execute silently, no anim.
      if (action.actor.isFainted) {
        _undoPreShieldIfNeeded(action.actor, action.trait);
        final step = _engine.executeNextAction();
        final impactEvent = _buildImpactEventFromStep(step);
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
          lastImpactEvent: impactEvent,
        );
        consumeQueuedCardForActor(actorId);
        if (anchoredActorId == actorId && nextActorId != actorId) {
          await recoilAnchoredActor();
          if (!mounted) return;
        }
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
          final actorPet = isPlayerActor
            ? _playerPets.firstWhere((p) => p.id == actorId)
            : _enemyPets.firstWhere((p) => p.id == actorId);
          final actorRow = actorPet.row.clamp(0, 2);
          final targetRow = targetPet.row.clamp(0, 2);
          final actorLane = actorPet.lane.clamp(0, 2);
          final targetLane = targetPet.lane.clamp(0, 2);
          final actorAnchor = isPlayerActor
            ? _playerBattlePos[actorRow]
            : _enemyBattlePos[actorRow];
          final targetAnchor = isPlayerActor
            ? _enemyBattlePos[targetRow]
            : _playerBattlePos[targetRow];
          // Keep dash vector in sync with HUD slot composition:
          // final position = row anchor + lane vertical offset.
          const laneSpacing = 0.10;
          final actorBase = Offset(
            actorAnchor.dx,
            actorAnchor.dy + (actorLane - 1) * laneSpacing,
          );
          final targetBase = Offset(
            targetAnchor.dx,
            targetAnchor.dy + (targetLane - 1) * laneSpacing,
          );
          final toTarget = Offset(
            targetBase.dx - actorBase.dx,
            targetBase.dy - actorBase.dy,
          );
          final distance = toTarget.distance;
          if (distance > 0.0001) {
            // Land face-to-face on the target lane (same Y), with a small
            // horizontal stop gap to prevent overlap.
            const stopGap = 0.08;
            final landingX = isPlayerActor
                ? (targetBase.dx - stopGap)
                : (targetBase.dx + stopGap);
            final landing = Offset(landingX, targetBase.dy);
            final toLanding = Offset(
              landing.dx - actorBase.dx,
              landing.dy - actorBase.dy,
            );
            final landingDistance = toLanding.distance;
            if (landingDistance > 0.0001) {
              final d = landingDistance;
              dashDir = Offset(
                toLanding.dx / landingDistance * d,
                toLanding.dy / landingDistance * d,
              );
            }
          }
        }
        final shouldDash =
            anchoredActorId != actorId ||
            anchoredDashDir == Offset.zero ||
            anchoredTargetId != dashTargetId;
        if (shouldDash) {
          anchoredActorId = actorId;
          anchoredDashDir = dashDir;
          anchoredTargetId = dashTargetId;
          // Phase 1: dash forward (HUD AnimatedPositioned = 420ms, wait = 480ms)
          state = state.copyWith(
            petAnimStates: {actorId: PetCharacterAnimState.move},
            petAttackSlots: {actorId: partSlot},
            petDashOffsets:
                dashDir != Offset.zero ? {actorId: dashDir} : const {},
            petDashTargets:
                dashTargetId != null ? {actorId: dashTargetId} : const {},
          );
          await Future.delayed(const Duration(milliseconds: _kDashWaitMs));
          if (!mounted) return;
        } else {
          dashDir = anchoredDashDir;
          dashTargetId = anchoredTargetId;
        }

        // Phase 2: impact — execute engine, play attack clip, show hit (500ms)
        final preHp = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.hp
        };
        final preShield = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.shield
        };
        _undoPreShieldIfNeeded(action.actor, action.trait);
        final step = _engine.executeNextAction();
        final impactEvent = _buildImpactEventFromStep(step);

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
              anchoredDashDir != Offset.zero ? {actorId: anchoredDashDir} : const {},
          petDashTargets:
              anchoredTargetId != null ? {actorId: anchoredTargetId!} : const {},
            lastImpactEvent: impactEvent,
        );
        consumeQueuedCardForActor(actorId);
        await Future.delayed(const Duration(milliseconds: _kImpactWaitMs));
        if (!mounted) return;

        if (_playerPets.every((p) => p.isFainted) ||
            _enemyPets.every((p) => p.isFainted)) {
          state = state.copyWith(
              petAnimStates: const {},
              petEffectVfx: const {},
              petAttackSlots: const {},
              petDashOffsets: const {},
              petDashTargets: const {});
          anchoredActorId = null;
          anchoredDashDir = Offset.zero;
          anchoredTargetId = null;
          break;
        }

        // Gap while staying advanced for same-actor follow-up cards.
        state = state.copyWith(
            petAnimStates: const {},
            petEffectVfx: const {},
            petAttackSlots: const {},
            petDashOffsets:
                anchoredDashDir != Offset.zero ? {actorId: anchoredDashDir} : const {},
            petDashTargets:
                anchoredTargetId != null ? {actorId: anchoredTargetId!} : const {});
        await Future.delayed(const Duration(milliseconds: _kGapMs));
        if (!mounted) return;

        if (anchoredActorId == actorId && nextActorId != actorId) {
          await recoilAnchoredActor();
          if (!mounted) return;
        }
      } else if (isRanged) {
        // ── RANGED: attack windup + projectile → impact ────────────────────
        final targetPet = _resolveAnimTarget(action, opposingTeam);

        // Phase 1: attack windup + spawn projectile
        state = state.copyWith(
          petAnimStates: {actorId: PetCharacterAnimState.attackRanged},
          petAttackSlots: {actorId: partSlot},
          petEffectVfx: {actorId: 'damage'},
          petDashOffsets:
            anchoredActorId == actorId && anchoredDashDir != Offset.zero
              ? {actorId: anchoredDashDir}
              : const {},
          petDashTargets:
            anchoredActorId == actorId && anchoredTargetId != null
              ? {actorId: anchoredTargetId!}
              : const {},
          pendingProjectileToken: state.pendingProjectileToken + 1,
          pendingProjectileActorId: actorId,
          pendingProjectileTargetId: targetPet?.id ?? '',
          pendingProjectileClass: action.actor.creatureClass.name,
        );
        BattleAudioService.instance.playAttack('damage');
        await Future.delayed(const Duration(milliseconds: _kProjectileWaitMs));
        if (!mounted) return;

        // Phase 2: projectile lands — execute engine, hit anim
        final preHp = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.hp
        };
        final preShield = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.shield
        };
        _undoPreShieldIfNeeded(action.actor, action.trait);
        final step = _engine.executeNextAction();
        final impactEvent = _buildImpactEventFromStep(step);

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
            petDashOffsets:
              anchoredActorId == actorId && anchoredDashDir != Offset.zero
                ? {actorId: anchoredDashDir}
                : const {},
            petDashTargets:
              anchoredActorId == actorId && anchoredTargetId != null
                ? {actorId: anchoredTargetId!}
                : const {},
          clearPendingProjectile: true,
          lastImpactEvent: impactEvent,
        );
        consumeQueuedCardForActor(actorId);
        await Future.delayed(const Duration(milliseconds: _kHitWaitMs));
        if (!mounted) return;

        if (_playerPets.every((p) => p.isFainted) ||
            _enemyPets.every((p) => p.isFainted)) {
          state = state.copyWith(
              petAnimStates: const {},
              petEffectVfx: const {},
              petAttackSlots: const {},
              petDashOffsets: const {},
              petDashTargets: const {});
          anchoredActorId = null;
          anchoredDashDir = Offset.zero;
          anchoredTargetId = null;
          break;
        }

        // Gap
        state = state.copyWith(
            petAnimStates: const {},
            petEffectVfx: const {},
            petDashOffsets:
                anchoredActorId == actorId && anchoredDashDir != Offset.zero
                    ? {actorId: anchoredDashDir}
                    : const {},
            petDashTargets:
                anchoredActorId == actorId && anchoredTargetId != null
                    ? {actorId: anchoredTargetId!}
                    : const {});
        await Future.delayed(const Duration(milliseconds: _kGapMs));
        if (!mounted) return;

        if (anchoredActorId == actorId && nextActorId != actorId) {
          await recoilAnchoredActor();
          if (!mounted) return;
        }
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
          petDashOffsets:
              anchoredActorId == actorId && anchoredDashDir != Offset.zero
                  ? {actorId: anchoredDashDir}
                  : const {},
          petDashTargets:
              anchoredActorId == actorId && anchoredTargetId != null
                  ? {actorId: anchoredTargetId!}
                  : const {},
        );
        BattleAudioService.instance.playAttack(effectType);
        await Future.delayed(const Duration(milliseconds: _kEffectWindupMs));
        if (!mounted) return;

        final preHp = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.hp
        };
        final preShield = {
          for (final p in [..._playerPets, ..._enemyPets]) p.id: p.shield
        };
        _undoPreShieldIfNeeded(action.actor, action.trait);
        final step = _engine.executeNextAction();
        final impactEvent = _buildImpactEventFromStep(step);

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
          petDashOffsets:
              anchoredActorId == actorId && anchoredDashDir != Offset.zero
                  ? {actorId: anchoredDashDir}
                  : const {},
          petDashTargets:
              anchoredActorId == actorId && anchoredTargetId != null
                  ? {actorId: anchoredTargetId!}
                  : const {},
            lastImpactEvent: impactEvent,
        );
          consumeQueuedCardForActor(actorId);
        await Future.delayed(const Duration(milliseconds: _kEffectResultMs));
        if (!mounted) return;

        if (_playerPets.every((p) => p.isFainted) ||
            _enemyPets.every((p) => p.isFainted)) {
          state = state.copyWith(
              petAnimStates: const {},
              petEffectVfx: const {},
              petAttackSlots: const {},
              petDashOffsets: const {},
              petDashTargets: const {});
          anchoredActorId = null;
          anchoredDashDir = Offset.zero;
          anchoredTargetId = null;
          break;
        }

        // Gap
        state = state.copyWith(
            petAnimStates: const {},
            petEffectVfx: const {},
            petAttackSlots: const {},
            petDashOffsets:
                anchoredActorId == actorId && anchoredDashDir != Offset.zero
                    ? {actorId: anchoredDashDir}
                    : const {},
            petDashTargets:
                anchoredActorId == actorId && anchoredTargetId != null
                    ? {actorId: anchoredTargetId!}
                    : const {});
        await Future.delayed(const Duration(milliseconds: _kGapMs));
        if (!mounted) return;

        if (anchoredActorId == actorId && nextActorId != actorId) {
          await recoilAnchoredActor();
          if (!mounted) return;
        }
      }
    }

    // Clear any remaining entries (pets that were stunned and skipped their action).
    _preAppliedShields.clear();

    final result = _engine.finishRound();

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
      clearResolvingCardQueue: true,
      lastImpactEvent: null,
    );
    _syncBloodMoonAudio(_engine.isBloodMoonRound);

    if (result.isBattleOver) {
      state = state.copyWith(isResolving: false);
      return;
    }

    // Brief pause so the player can see damage results.
    await Future.delayed(const Duration(milliseconds: _kRoundPauseMs));
    if (!mounted) return;

    // ── Phase 3: Draw cards with entrance animation ───────────────────────────
    final newHand = _buildHandVMs(_engine.currentPlayerHand, const {});
    await _animateDrawnCards(handBeforeIds, newHand);
    if (!mounted) return;

    // ── Phase 4: Clear animations, open discard modal if needed ──────────────
    state = state.copyWith(
      isResolving: false,
      newCardIds: const {},
      needsDiscard: false,
      excessDiscards: 0,
      clearResolvingCardQueue: true,
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
    final owner = _playerPets.where((p) => p.id == card.ownerPetId).firstOrNull;
    final sameClass = owner != null &&
        card.trait.partClass != null &&
        card.trait.partClass == owner.creatureClass;
    if (sameClass) {
      amount = (amount * 1.10).round();
    }
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
          _snapVM(PetSnapshot.fromLive(_playerPets[i]), _playerPets[i], _playerPets[i].row),
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
          speed: p.effectiveSpeed,
          hp: p.hp,
          skill: p.skill,
          morale: p.morale,
          isPlayer: true,
          isFainted: p.isFainted,
          texturePath: _avatarPath(p.id),
        ),
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
          texturePath: _avatarPath(p.id),
        ),
    ];
    // Spec §3: speed desc → hp asc → skill desc → morale desc → id asc
    all.sort((a, b) {
      if (a.speed != b.speed) return b.speed.compareTo(a.speed);
      if (a.hp != b.hp) return a.hp.compareTo(b.hp);
      if (a.skill != b.skill) return b.skill.compareTo(a.skill);
      if (a.morale != b.morale) return b.morale.compareTo(a.morale);
      return a.petId.compareTo(b.petId);
    });
    return all;
  }

  /// Returns a part-card image path to use as a pet avatar thumbnail.
  /// Prefers the horn card art (most visually distinct per class/variant).
  /// Falls back to any available part card, then class icon.
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

  // ── Attack-style classification ────────────────────────────────────────────

  /// Back-part cards fire a projectile; specific trait IDs also classified ranged.
  static const _kRangedTraitIds = {'bird_tail', 'bird_horn'};

  bool _isRangedCard(Trait trait) =>
      trait.part == TraitPart.back || _kRangedTraitIds.contains(trait.id);

  String? _resolveActionCardImagePath(Action action) {
    final part = action.trait.part.name;
    final def = _defFor(action.actor.id);
    final partCard = def?.partCardArt[part];
    return (partCard != null && partCard.isNotEmpty) ? partCard : null;
  }

  /// Resolve which enemy pet the animation should track (melee dash or
  /// ranged projectile target). Handles all targeting specs from effect.target.
  Pet? _resolveAnimTarget(Action action, List<Pet> opposingTeam) {
    if (action.primaryTarget != null) {
      if (!action.primaryTarget!.isFainted) {
        return action.primaryTarget;
      }
    }
    final alive = opposingTeam.where((p) => !p.isFainted).toList();
    if (alive.isEmpty) return null;
    final spec = action.trait.effect.target;

    Pet pickByRow(int row, {int? preferLane}) {
      final inRow = alive.where((p) => p.row == row).toList();
      if (inRow.isEmpty) return alive.first;
      if (preferLane == null) return inRow.first;
      inRow.sort((a, b) {
        final da = (a.lane - preferLane).abs();
        final db = (b.lane - preferLane).abs();
        if (da != db) return da.compareTo(db);
        return a.id.compareTo(b.id);
      });
      return inRow.first;
    }

    final actorLane = action.actor.lane;

    if (spec == 'furthest_enemy' || spec == 'back_enemy') {
      final backRow = alive
          .map((p) => p.row)
          .reduce((a, b) => a > b ? a : b);
      return pickByRow(backRow, preferLane: actorLane);
    }
    if (spec == 'lowest_hp_enemy') {
      alive.sort((a, b) => a.hp.compareTo(b.hp));
      return alive.first;
    }
    if (spec == 'fastest_enemy') {
      alive.sort((a, b) => b.speed.compareTo(a.speed));
      return alive.first;
    }

    // Default enemy targeting tracks the front-most row, lane-nearest to actor.
    final frontRow = alive
        .map((p) => p.row)
        .reduce((a, b) => a < b ? a : b);
    return pickByRow(frontRow, preferLane: actorLane);
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

  Pet? _petByName(String name) {
    for (final p in [..._playerPets, ..._enemyPets]) {
      if (p.name == name) return p;
    }
    return null;
  }

  BattleImpactEvent? _buildImpactEventFromStep(ActionStepResult step) {
    final actorPet = step.action.actor;
    Pet? targetPet = step.action.primaryTarget;
    var effectType = step.action.trait.effect.type.name;
    var statusApplied = '';
    var damage = 0;
    var healAmount = 0;
    var shieldAmount = 0;
    var isCritical = false;
    var found = false;
    var hasStunApplied = false;

    for (final event in step.events) {
      switch (event) {
        case DamageEvent e:
          found = true;
          damage = e.amount;
          isCritical = e.isCrit;
          effectType = e.isPoisonTick
              ? 'poison'
              : e.isBurnTick
                  ? 'burn'
                  : 'damage';
          targetPet = targetPet ?? _petByName(e.targetName);
          break;
        case HealEvent e:
          found = true;
          healAmount = e.amount;
          effectType = 'heal';
          targetPet = targetPet ?? _petByName(e.targetName);
          break;
        case ShieldEvent e:
          found = true;
          shieldAmount = e.amount;
          effectType = 'shield';
          targetPet = targetPet ?? _petByName(e.targetName);
          break;
        case DebuffAppliedEvent e:
          found = true;
          effectType = 'debuff';
          statusApplied = e.debuffType;
          if (e.debuffType == 'stunned') {
            hasStunApplied = true;
          }
          targetPet = targetPet ?? _petByName(e.targetName);
          break;
        case BuffAppliedEvent e:
          found = true;
          effectType = 'buff';
          statusApplied = e.buffType;
          targetPet = targetPet ?? _petByName(e.targetName);
          break;
        case StunSkipEvent _:
          // Skip-turn stun events happen on the stunned pet's own turn.
          // Floating "Stunned!" should be shown when stun is applied by an attacker,
          // not when the victim loses a turn.
          break;
        case ShieldBreakEvent e:
          found = true;
          effectType = 'shieldBreak';
          targetPet = targetPet ?? _petByName(e.targetName);
          break;
        case EnergyStealEvent e:
          found = true;
          if (statusApplied.isEmpty) statusApplied = 'energy_steal';
          if (effectType.isEmpty) effectType = 'energySteal';
          targetPet = targetPet ?? _petByName(e.targetName);
          break;
        case CardDiscardEvent e:
          found = true;
          if (statusApplied.isEmpty) statusApplied = 'card_discard';
          if (effectType.isEmpty) effectType = 'discard';
          targetPet = targetPet ?? _petByName(e.targetName);
          break;
        default:
          break;
      }
    }

    if (hasStunApplied) {
      effectType = 'debuff';
      statusApplied = 'stunned';
    }

    if (!found) return null;

    final resolvedTarget = targetPet ?? actorPet;
    return BattleImpactEvent(
      id: ++_visualEventCounter,
      actorId: actorPet.id,
      targetId: resolvedTarget.id,
      effectType: effectType,
      isCritical: isCritical,
      damage: damage,
      healAmount: healAmount,
      shieldAmount: shieldAmount,
      statusApplied: statusApplied,
      targetHpAfter: resolvedTarget.hp,
      targetShieldAfter: resolvedTarget.shield,
      targetIsFainted: resolvedTarget.isFainted,
      actorHpAfter: actorPet.hp,
      actorShieldAfter: actorPet.shield,
    );
  }

  PetCharacterAnimState _animStateForEffect(String effectType) =>
      switch (effectType) {
        'heal' => PetCharacterAnimState.heal,
        'shield' => PetCharacterAnimState.shield,
        'buff' => PetCharacterAnimState.buff,
        'debuff' => PetCharacterAnimState.debuff,
        _ => PetCharacterAnimState.attack,
      };

  // position = pet.row so the HUD renders each pet at its actual formation row
  List<PetViewModel> _toViewModels(List<Pet> pets, {required bool isPlayer}) =>
      [for (final pet in pets) _petVM(pet, pet.row)];

  List<PetViewModel> _snapshotsToVMs(
    List<PetSnapshot> snaps,
    List<Pet> livePets,
  ) => [for (var i = 0; i < snaps.length; i++) _snapVM(snaps[i], livePets[i], livePets[i].row)];

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

  CreatureDefinition? _defFor(String petId) =>
      _petDefs[petId] ?? kCreatureRegistry[petId];

  PetViewModel _petVM(Pet pet, int position) {
    final def = _defFor(pet.id);
    return PetViewModel.initial(
      pet.id,
      pet.name,
      pet.speed,
      position,
      pet.traits,
      pet,
      spriteConfig: def?.spriteConfig,
      partCardArt: def?.partCardArt ?? const {},
      creatureDef: def,
    );
  }

  PetViewModel _snapVM(PetSnapshot snap, Pet livePet, int position) {
    final def = _defFor(livePet.id);
    return PetViewModel.fromSnapshot(
      snap,
      livePet.traits,
      livePet,
      position,
      spriteConfig: def?.spriteConfig,
      partCardArt: def?.partCardArt ?? const {},
      creatureDef: def,
    );
  }

  // ── Team builders ──────────────────────────────────────────────────────────

  /// Player team: built from the 3 active pets and their saved formation.
  /// Uses OwnedPet display names to strengthen pet identity in battle.
  /// Returns empty list if no roster — the HomeScreen blocks battle entry
  /// when the team isn't full, so this path should not normally be reached.
  static List<Pet> _buildPlayerTeam(PlayerData playerData) {
    // Path 1: composition with slots (preferred — respects 3×3 formation)
    final slots = playerData.activeComposition?.slots;
    if (slots != null && slots.length == 3) {
      final pets = <Pet>[];
      for (final slot in slots) {
        final owned = playerData.petById(slot.petUid);
        if (owned == null || !kBodyCatalogue.containsKey(owned.bodyId)) continue;
        pets.add(owned.toCreatureDefinition().toPet(
          displayName: owned.name,
          row: slot.row.index,
          lane: slot.lane.index,
        ));
      }
      if (pets.isNotEmpty) {
        pets.sort((a, b) {
          final rowCompare = a.row.compareTo(b.row);
          if (rowCompare != 0) return rowCompare;
          return a.lane.compareTo(b.lane);
        });
        return pets;
      }
    }

    // Path 2: active roster (UIDs saved in activeTeam, now null-safe)
    // Falls back to full roster if activeRoster is empty due to stale UIDs.
    final candidates = playerData.activeRoster.isNotEmpty
        ? playerData.activeRoster
        : playerData.roster;

    return candidates
        .where((p) => kBodyCatalogue.containsKey(p.bodyId))
        .take(3)
        .toList()
        .asMap()
        .entries
        .map((e) => e.value.toCreatureDefinition().toPet(
              displayName: e.value.name,
              row: e.key,
              lane: 1,
            ))
        .toList();
  }

  /// Quick-battle enemy team (used when no stageId is given).
  static List<Pet> _teamBeta() => [
      kCreatureRegistry['reptile_1']!.toPet(row: 0, lane: 1),
      kCreatureRegistry['bird_1']!.toPet(row: 1, lane: 1),
      kCreatureRegistry['bug_1']!.toPet(row: 2, lane: 1),
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
    // activeRoster is now null-safe; fall back to full roster if stale UIDs.
    final activeRoster = playerData.activeRoster.isNotEmpty
        ? playerData.activeRoster
        : playerData.roster.take(3).toList();
    final stage = args?.stageId != null ? stageById(args!.stageId!) : null;
    return PveBattleNotifier(
      playerTeamName: args?.playerTeamName ?? 'My Team',
      enemyTeamName: stage?.name ?? (args?.enemyTeamName ?? 'Rivals'),
      playerPets: PveBattleNotifier._buildPlayerTeam(playerData),
      enemyPets: PveBattleNotifier._buildEnemyTeam(args?.stageId),
      activeRoster: activeRoster,
    );
  },
);
