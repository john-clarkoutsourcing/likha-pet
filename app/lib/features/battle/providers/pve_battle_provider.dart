import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:likha_pet_battle_engine/battle_state.dart';
import 'package:likha_pet_battle_engine/pet.dart';
import 'package:likha_pet_battle_engine/skill_card.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import '../engine/interactive_battle_engine.dart';
import '../widgets/pet_character_widget.dart';
import '../widgets/pet_sprite_widget.dart';
import 'battle_view_model.dart';

class PveBattleNotifier extends StateNotifier<PveBattleViewModel> {
  late final InteractiveBattleEngine _engine;
  late final List<Pet> _playerPets;
  late final List<Pet> _enemyPets;

  PveBattleNotifier({
    required String playerTeamName,
    required String enemyTeamName,
  }) : super(PveBattleViewModel.initial()) {
    _playerPets = _teamBayani();
    _enemyPets  = _teamDiwata();

    _engine = InteractiveBattleEngine(
      playerTeam:     _playerPets,
      enemyTeam:      _enemyPets,
      playerTeamName: playerTeamName,
      enemyTeamName:  enemyTeamName,
    );

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
      state = state.copyWith(
        pendingSkills: newPending,
        selectedPetId: petId,
        hand: _buildHandVMs(_engine.currentPlayerHand, newPending),
      );
      return;
    }

    // Add this card to the list.
    currentList.add(cardInstanceId);
    newPending[petId] = currentList;

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

    final actingPlayerIds = Set<String>.from(state.pendingSkills.keys);
    final handBeforeIds   = state.hand.map((c) => c.instanceId).toSet();

    // How many attack waves? = max cards assigned to any single pet.
    final maxWaves = state.pendingSkills.values
        .fold(0, (m, list) => list.length > m ? list.length : m)
        .clamp(1, 3);
    final pendingSnapshot = state.pendingSkills.map(
      (k, v) => MapEntry(k, List<String>.from(v)),
    );

    // ── Phase 1: Sequential attack waves ─────────────────────────────────────
    state = state.copyWith(isResolving: true);

    for (int wave = 0; wave < maxWaves; wave++) {
      final wavePlayerIds = actingPlayerIds
          .where((id) => (pendingSnapshot[id]?.length ?? 0) > wave)
          .toSet();
      final animStates = <String, PetCharacterAnimState>{
        for (final id in wavePlayerIds) id: PetCharacterAnimState.attack,
        if (wave == 0)
          for (final p in _enemyPets)
            if (!p.isFainted) p.id: PetCharacterAnimState.attack,
      };
      state = state.copyWith(petAnimStates: animStates);
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      state = state.copyWith(petAnimStates: const {});
      if (wave < maxWaves - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
      }
    }

    // Run the engine in the background while animations play.
    final result = _engine.executeRound(
      state.pendingSkills.map((k, v) => MapEntry(k, List<String>.from(v))),
    );

    // Wait for attack + projectile animations (lunge + travel).
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    // ── Phase 2: Reveal damage / deaths ──────────────────────────────────────
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
        ),
      for (final p in _enemyPets)
        TurnOrderEntry(
          petId: p.id, name: p.name, speed: p.speed,
          isPlayer: false, isFainted: p.isFainted,
        ),
    ];
    all.sort((a, b) => b.speed.compareTo(a.speed));
    return all;
  }

  List<PetViewModel> _toViewModels(List<Pet> pets, {required bool isPlayer}) {
    return [
      for (var i = 0; i < pets.length; i++)
        PetViewModel.initial(
          pets[i].id, pets[i].name,
          pets[i].speed, i,
          pets[i].traits, pets[i],
          spriteConfig: _kSprites[pets[i].id],
          characterConfig:   _kAxie[pets[i].id],
        ),
    ];
  }

  List<PetViewModel> _snapshotsToVMs(
    List<PetSnapshot> snaps, List<Pet> livePets,
  ) {
    return [
      for (var i = 0; i < snaps.length; i++)
        PetViewModel.fromSnapshot(
          snaps[i], livePets[i].traits, livePets[i], i,
          spriteConfig: _kSprites[livePets[i].id],
          characterConfig:   _kAxie[livePets[i].id],
        ),
    ];
  }

  // ── Sprite configs ─────────────────────────────────────────────────────────
  // frameSize must match the per-frame pixel size used when generating sheets
  // (120×120 — see the spritesheet generation script).
  // Axie Infinity Spine skeletal animations (Spine 3.8 JSON).
  static const Map<String, PetCharacterConfig> _kAxie = {
    'bayani_1': PetCharacterConfig(texturePath: 'assets/sprites/aquatic_full.png'),
    'bayani_2': PetCharacterConfig(texturePath: 'assets/sprites/beast_full.png'),
    'bayani_3': PetCharacterConfig(texturePath: 'assets/sprites/reptile_full.png'),
    'diwata_1': PetCharacterConfig(texturePath: 'assets/sprites/plant_full.png'),
    'diwata_2': PetCharacterConfig(texturePath: 'assets/sprites/bird_full.png'),
    'diwata_3': PetCharacterConfig(texturePath: 'assets/sprites/bug_full.png'),
  };

  // Fallback flat sprites (still used when Spine fails to load).
  static final Map<String, PetSpriteConfig> _kSprites = {
    'bayani_1': PetSpriteConfig(idle: PetAnimConfig(sheetFile: 'aquatic.png', frameSize: Vector2(64,64), frameCount: 1, stepTime: 1.0)),
    'bayani_2': PetSpriteConfig(idle: PetAnimConfig(sheetFile: 'beast.png',   frameSize: Vector2(64,64), frameCount: 1, stepTime: 1.0)),
    'bayani_3': PetSpriteConfig(idle: PetAnimConfig(sheetFile: 'reptile.png', frameSize: Vector2(64,64), frameCount: 1, stepTime: 1.0)),
    'diwata_1': PetSpriteConfig(idle: PetAnimConfig(sheetFile: 'plant.png',   frameSize: Vector2(64,64), frameCount: 1, stepTime: 1.0)),
    'diwata_2': PetSpriteConfig(idle: PetAnimConfig(sheetFile: 'bird.png',    frameSize: Vector2(64,64), frameCount: 1, stepTime: 1.0)),
    'diwata_3': PetSpriteConfig(idle: PetAnimConfig(sheetFile: 'bug.png',     frameSize: Vector2(64,64), frameCount: 1, stepTime: 1.0)),
  };

  // ── Team definitions ───────────────────────────────────────────────────────

  static List<Pet> _teamBayani() => [
    Pet(
      id: 'bayani_1', name: 'Bakunawa', speed: 35,
      traits: [
        TraitLibrary.aswangFang,
        TraitLibrary.enkantoFlash,
        TraitLibrary.tikbalangCharge,
      ],
    ),
    Pet(
      id: 'bayani_2', name: 'Tikbalang', speed: 28,
      traits: [
        TraitLibrary.tikbalangSnipe,
        TraitLibrary.anakngLupaSlam,
        TraitLibrary.kapreSmoke,
      ],
    ),
    Pet(
      id: 'bayani_3', name: 'Manananggal', speed: 22,
      traits: [
        TraitLibrary.manananggalDrain,
        TraitLibrary.bayanihanShield,
        TraitLibrary.amihanVeil,
      ],
    ),
  ];

  static List<Pet> _teamDiwata() => [
    Pet(
      id: 'diwata_1', name: 'Diwata', speed: 30,
      traits: [
        TraitLibrary.tikbalangCharge,
        TraitLibrary.lakanCounter,
        TraitLibrary.diwataBlessing,
      ],
    ),
    Pet(
      id: 'diwata_2', name: 'Sarimanok', speed: 34,
      traits: [
        TraitLibrary.bakunawaSwallow,
        TraitLibrary.sarimanokAura,
        TraitLibrary.amihanVeil,
      ],
    ),
    Pet(
      id: 'diwata_3', name: 'Amihan', speed: 25,
      traits: [
        TraitLibrary.anakngLupaSlam,
        TraitLibrary.manananggalDrain,
        TraitLibrary.bayanihanShield,
      ],
    ),
  ];
}

final pveBattleProvider =
    StateNotifierProvider.autoDispose<PveBattleNotifier, PveBattleViewModel>(
  (ref) => PveBattleNotifier(
    playerTeamName: 'Team Bayani',
    enemyTeamName:  'Team Diwata',
  ),
);
