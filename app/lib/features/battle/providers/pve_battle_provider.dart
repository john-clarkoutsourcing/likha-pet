import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:likha_pet_battle_engine/battle_state.dart';
import 'package:likha_pet_battle_engine/pet.dart';
import 'package:likha_pet_battle_engine/skill_card.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../data/creature_registry.dart';
import '../engine/interactive_battle_engine.dart';
import '../screens/battle_screen.dart' show BattleScreenArgs;
import '../services/mixed_skeleton_service.dart';
import '../widgets/pet_character_widget.dart' show PetCharacterAnimState, PetCharacterConfig;
import '../../pets/models/owned_pet.dart';
import '../../pets/providers/player_provider.dart';
import '../../pve/data/stage_registry.dart';
import 'battle_view_model.dart';

class PveBattleNotifier extends StateNotifier<PveBattleViewModel> {
  late final InteractiveBattleEngine _engine;
  late final List<Pet> _playerPets;
  late final List<Pet> _enemyPets;

  // instanceId → (petId, shieldAmount) for shields pre-applied during planning.
  final Map<String, ({String petId, int amount})> _preAppliedShields = {};

  // petId → PetCharacterConfig with mixed skeleton
  final Map<String, PetCharacterConfig> _mixedSkeletonConfigs = {};

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
    _enemyPets  = enemyPets  ?? _teamBeta();
    if (activeRoster != null) _registerPlayerDefs(activeRoster);

    _engine = InteractiveBattleEngine(
      playerTeam:     _playerPets,
      enemyTeam:      _enemyPets,
      playerTeamName: playerTeamName,
      enemyTeamName:  enemyTeamName,
    );

    // Initialize mixed skeletons asynchronously
    _initializeMixedSkeletons().then((_) {
      state = PveBattleViewModel(
        currentRound:     1,
        playerTeam:       _toViewModels(_playerPets, isPlayer: true),
        enemyTeam:        _toViewModels(_enemyPets,  isPlayer: false),
        roundLog:         '',
        isBattleOver:     false,
        playerTeamName:   playerTeamName,
        enemyTeamName:    enemyTeamName,
        turnOrder:        _buildTurnOrder(),
        selectedPetId:    _playerPets.first.id,
        pendingSkills:    const {},
        hand:             _buildHandVMs(_engine.currentPlayerHand, const {}),
        deckDrawSize:     _engine.playerDeckDrawSize,
        deckDiscardSize:  _engine.playerDeckDiscardSize,
        playerTeamEnergy: _engine.playerEnergy.energy,
        enemyTeamEnergy:  _engine.enemyEnergy.energy,
      );
    }).catchError((e) {
      // Fallback to pre-baked skeletons if mixer fails
      print('❌ Failed to initialize mixed skeletons: $e');
      state = PveBattleViewModel(
        currentRound:     1,
        playerTeam:       _toViewModels(_playerPets, isPlayer: true),
        enemyTeam:        _toViewModels(_enemyPets,  isPlayer: false),
        roundLog:         '',
        isBattleOver:     false,
        playerTeamName:   playerTeamName,
        enemyTeamName:    enemyTeamName,
        turnOrder:        _buildTurnOrder(),
        selectedPetId:    _playerPets.first.id,
        pendingSkills:    const {},
        hand:             _buildHandVMs(_engine.currentPlayerHand, const {}),
        deckDrawSize:     _engine.playerDeckDrawSize,
        deckDiscardSize:  _engine.playerDeckDiscardSize,
        playerTeamEnergy: _engine.playerEnergy.energy,
        enemyTeamEnergy:  _engine.enemyEnergy.energy,
      );
    });
  }

  // ── Player actions ─────────────────────────────────────────────────────────

  void selectPet(String petId) {
    if (state.isBattleOver || state.isResolving) return;
    state = state.copyWith(selectedPetId: petId);
  }

  /// Assign a drawn card to its owner pet.
  /// Multiple cards per pet are allowed — tapping again deselects.
  void assignSkill(String cardInstanceId) {
    if (state.isBattleOver || state.isResolving || state.needsDiscard) return;

    final card = _engine.currentPlayerHand
        .where((c) => c.instanceId == cardInstanceId)
        .firstOrNull;
    if (card == null) return;

    final petId     = card.ownerPetId;
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
        selectedPetId: petId,
        playerTeam: _livePlayerTeamVMs(),
        hand: _buildHandVMs(_engine.currentPlayerHand, newPending),
      );
      return;
    }

    // Add this card to the list.
    currentList.add(cardInstanceId);
    newPending[petId] = currentList;

    // Apply shield immediately so the HP bar reflects it during planning.
    _applyPreShield(card);

    // Auto-advance to next pet that has no cards assigned yet.
    final handPetIds = _engine.currentPlayerHand.map((c) => c.ownerPetId).toSet();
    final next = _playerPets
        .where((p) =>
            !p.isFainted &&
            handPetIds.contains(p.id) &&
            !newPending.containsKey(p.id))
        .firstOrNull;

    state = state.copyWith(
      pendingSkills: newPending,
      selectedPetId: next?.id ?? petId,
      playerTeam: _livePlayerTeamVMs(),
      hand: _buildHandVMs(_engine.currentPlayerHand, newPending),
    );
  }

  /// Discard a specific card from the player's hand (overflow discard phase).
  void discardCard(String cardInstanceId) {
    _engine.discardFromPlayerHand(cardInstanceId);
    // Remove this card from any pending assignment list.
    final newPending = state.pendingSkills.map(
      (k, v) => MapEntry(k, v.where((id) => id != cardInstanceId).toList()),
    )..removeWhere((_, v) => v.isEmpty);
    final hand   = _buildHandVMs(_engine.currentPlayerHand, newPending);
    final excess = (_engine.currentPlayerHand.length - 10).clamp(0, 100);
    state = state.copyWith(
      hand:           hand,
      pendingSkills:  newPending,
      needsDiscard:   excess > 0,
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
        currentRound:     immediate.state.round,
        playerTeam:       _snapshotsToVMs(immediate.state.teamA, _playerPets),
        enemyTeam:        _snapshotsToVMs(immediate.state.teamB, _enemyPets),
        roundLog:         immediate.log,
        isBattleOver:     immediate.isBattleOver,
        outcome:          immediate.outcome?.name,
        turnOrder:        _buildTurnOrder(),
        playerTeamEnergy: _engine.playerEnergy.energy,
        enemyTeamEnergy:  _engine.enemyEnergy.energy,
        pendingSkills:    const {},
        petAnimStates:    const {},
        petEffectVfx:     const {},
        isResolving:      false,
      );
      return;
    }

    // Resolve every queued action in strict turn order.
    for (final action in started.actionQueue) {
      if (!mounted) return;

      final actorId = action.actor.id;
      final effectType = (action.trait.effect.type == EffectType.buff &&
              action.trait.effect.buffType == BuffType.regen)
          ? 'heal'
          : action.trait.effect.type.name;
      final partSlot   = action.trait.part.name; // 'horn'|'back'|'tail'|'mouth'|'body'
      if (!action.actor.isFainted) {
        state = state.copyWith(
          petAnimStates:  {actorId: _animStateForEffect(effectType)},
          petEffectVfx:   {actorId: effectType},
          petAttackSlots: {actorId: partSlot},
        );
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
      }

      // Undo pre-applied shield for this pet just before the resolver
      // re-applies it, so the final shield value is correct (not doubled).
      _undoPreShieldIfNeeded(action.actor, action.trait);

      final step = _engine.executeNextAction();
      state = state.copyWith(
        currentRound:     step.state.round,
        playerTeam:       _snapshotsToVMs(step.state.teamA, _playerPets),
        enemyTeam:        _snapshotsToVMs(step.state.teamB, _enemyPets),
        roundLog:         step.log,
        turnOrder:        _buildTurnOrder(),
        playerTeamEnergy: _engine.playerEnergy.energy,
        enemyTeamEnergy:  _engine.enemyEnergy.energy,
      );

      if (!action.actor.isFainted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
      } else {
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
      }

      state = state.copyWith(petAnimStates: const {}, petEffectVfx: const {}, petAttackSlots: const {});
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
    }

    // Clear any remaining entries (pets that were stunned and skipped their action).
    _preAppliedShields.clear();

    final result = _engine.finishRound();

    // Drop cards of fainted pets before updating teams.
    final faintedIds = _playerPets.where((p) => p.isFainted).map((p) => p.id).toSet();
    for (final card in List.of(_engine.currentPlayerHand)) {
      if (faintedIds.contains(card.ownerPetId)) {
        _engine.discardFromPlayerHand(card.instanceId);
      }
    }

    state = state.copyWith(
      currentRound:     result.state.round,
      playerTeam:       _snapshotsToVMs(result.state.teamA, _playerPets),
      enemyTeam:        _snapshotsToVMs(result.state.teamB, _enemyPets),
      roundLog:         result.log,
      isBattleOver:     result.isBattleOver,
      outcome:          result.outcome?.name,
      turnOrder:        _buildTurnOrder(),
      playerTeamEnergy: _engine.playerEnergy.energy,
      enemyTeamEnergy:  _engine.enemyEnergy.energy,
      pendingSkills:    const {},
      petAnimStates:    const {},
      petEffectVfx:     const {},
    );

    if (result.isBattleOver) {
      state = state.copyWith(isResolving: false);
      return;
    }

    // Brief pause so the player can see damage results.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // ── Phase 3: Draw cards with entrance animation ───────────────────────────
    final newHand   = _buildHandVMs(_engine.currentPlayerHand, const {});
    final newIds    = newHand.map((c) => c.instanceId).toSet().difference(handBeforeIds);

    state = state.copyWith(
      hand:           newHand,
      deckDrawSize:   _engine.playerDeckDrawSize,
      deckDiscardSize: _engine.playerDeckDiscardSize,
      selectedPetId:  _playerPets.where((p) => !p.isFainted).firstOrNull?.id,
      newCardIds:     newIds,
    );

    // Let card entrance animations play.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // ── Phase 4: Clear animations, open discard modal if needed ──────────────
    final excess = (_engine.currentPlayerHand.length - 10).clamp(0, 100);
    state = state.copyWith(
      isResolving:    false,
      newCardIds:     const {},
      needsDiscard:   excess > 0,
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
      hand:           newHand,
      deckDiscardSize: _engine.playerDeckDiscardSize,
      needsDiscard:   false,
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
    return amount.clamp(0, 40);
  }

  void _applyPreShield(SkillCard card) {
    final amount = _shieldForCard(card);
    if (amount <= 0) return;
    final pet = _playerPets.where((p) => p.id == card.ownerPetId).firstOrNull;
    if (pet == null || pet.isFainted) return;
    pet.applyShield(amount);
    _preAppliedShields[card.instanceId] = (petId: card.ownerPetId, amount: amount);
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
    final isShieldAction = trait.effect.type == EffectType.shield ||
                           trait.effect.selfShield > 0;
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
    final remaining    = _engine.playerEnergy.energy - spent;
    final allAssigned  = pending.values.expand((ids) => ids).toSet();

    return hand.map((card) {
      final owner      = _playerPets.firstWhere((p) => p.id == card.ownerPetId);
      final isAssigned = allAssigned.contains(card.instanceId);
      return CardViewModel.fromCard(
        card, owner,
        availableEnergy: isAssigned ? null : remaining,
      );
    }).toList();
  }

  List<TurnOrderEntry> _buildTurnOrder() {
    final all = [
      for (final p in _playerPets)
        TurnOrderEntry(
          petId: p.id, name: p.name, speed: p.speed,
          isPlayer: true,  isFainted: p.isFainted,
          texturePath: _classIconPath(p.id),
        ),
      for (final p in _enemyPets)
        TurnOrderEntry(
          petId: p.id, name: p.name, speed: p.speed,
          isPlayer: false, isFainted: p.isFainted,
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

  PetCharacterAnimState _animStateForEffect(String effectType) =>
      switch (effectType) {
        'heal'   => PetCharacterAnimState.heal,
        'shield' => PetCharacterAnimState.shield,
        'buff'   => PetCharacterAnimState.buff,
        'debuff' => PetCharacterAnimState.debuff,
        _        => PetCharacterAnimState.attack,
      };

  List<PetViewModel> _toViewModels(List<Pet> pets, {required bool isPlayer}) {
    return [
      for (var i = 0; i < pets.length; i++)
        _petVM(pets[i], i),
    ];
  }

  List<PetViewModel> _snapshotsToVMs(
    List<PetSnapshot> snaps, List<Pet> livePets,
  ) {
    return [
      for (var i = 0; i < snaps.length; i++)
        _snapVM(snaps[i], livePets[i], i),
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
            print('✅ Mixed skeleton for ${pet.name} (${pet.id})');
          } catch (e) {
            print('⚠️  Failed to mix ${pet.name}: $e');
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
            print('✅ Mixed skeleton for ${pet.name} (${pet.id})');
          } catch (e) {
            print('⚠️  Failed to mix ${pet.name}: $e');
          }
        }
      }
    } catch (e) {
      print('❌ MixedSkeletonService failed to initialize: $e');
    }
  }

  CreatureDefinition? _defFor(String petId) =>
      _petDefs[petId] ?? kCreatureRegistry[petId];

  PetViewModel _petVM(Pet pet, int position) {
    final def = _defFor(pet.id);
    // Try to use mixed skeleton if available, otherwise fall back to pre-baked
    final characterConfig = _mixedSkeletonConfigs[pet.id] ?? def?.spineConfig;
    return PetViewModel.initial(
      pet.id, pet.name, pet.speed, position,
      pet.traits, pet,
      spriteConfig:    def?.spriteConfig,
      characterConfig: characterConfig,
      partCardArt:     def?.partCardArt ?? const {},
    );
  }

  PetViewModel _snapVM(PetSnapshot snap, Pet livePet, int position) {
    final def = _defFor(livePet.id);
    // Try to use mixed skeleton if available, otherwise fall back to pre-baked
    final characterConfig = _mixedSkeletonConfigs[livePet.id] ?? def?.spineConfig;
    return PetViewModel.fromSnapshot(
      snap, livePet.traits, livePet, position,
      spriteConfig:    def?.spriteConfig,
      characterConfig: characterConfig,
      partCardArt:     def?.partCardArt ?? const {},
    );
  }

  // ── Team builders ──────────────────────────────────────────────────────────

  /// Player team: built from the 3 active pets in the player's roster.
  /// Returns empty list if no roster — the HomeScreen blocks battle entry
  /// when the team isn't full, so this path should not normally be reached.
  static List<Pet> _buildPlayerTeam(List<OwnedPet> activeRoster) {
    return activeRoster
        .where((p) => kBodyCatalogue.containsKey(p.bodyId))
        .map((p) => p.toCreatureDefinition().toPet())
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

}

// args provider — set before creating pveBattleProvider
final battleArgsProvider = StateProvider<BattleScreenArgs?>((_) => null);

final pveBattleProvider =
    StateNotifierProvider.autoDispose<PveBattleNotifier, PveBattleViewModel>(
  (ref) {
    final args        = ref.read(battleArgsProvider);
    final playerData  = ref.read(playerProvider);
    final activeRoster = playerData.hasFullTeam
        ? playerData.activeRoster
        : <OwnedPet>[];
    final stage = args?.stageId != null ? stageById(args!.stageId!) : null;
    return PveBattleNotifier(
      playerTeamName: args?.playerTeamName ?? 'My Team',
      enemyTeamName:  stage?.name ?? (args?.enemyTeamName ?? 'Rivals'),
      playerPets:     PveBattleNotifier._buildPlayerTeam(activeRoster),
      enemyPets:      PveBattleNotifier._buildEnemyTeam(args?.stageId),
      activeRoster:   activeRoster,
    );
  },
);
