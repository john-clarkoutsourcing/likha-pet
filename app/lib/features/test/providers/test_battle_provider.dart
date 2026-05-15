import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:likha_pet_battle_engine/battle_engine.dart';
import 'package:likha_pet_battle_engine/pet.dart';
import 'package:likha_pet_battle_engine/trait.dart';
import 'package:likha_pet_battle_engine/battle_state.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class TestPetCreatorState {
  final Map<TraitPart, String?> selectedTraitNames; // store trait names, not objects
  final bool petCreated;
  final Pet? testPet;
  final Pet? dummyEnemy;
  final BattleEngine? engine;
  final BattleState? battleState;
  final Map<String, String> petAnimStates;    // petId -> animStateName
  final Map<String, String> petEffectVfx;     // petId -> effectType
  final String actionLog;
  final bool isWaitingForAction;

  const TestPetCreatorState({
    this.selectedTraitNames = const {
      TraitPart.body: null,
      TraitPart.horn: null,
      TraitPart.back: null,
      TraitPart.mouth: null,
      TraitPart.tail: null,
    },
    this.petCreated = false,
    this.testPet,
    this.dummyEnemy,
    this.engine,
    this.battleState,
    this.petAnimStates = const {},
    this.petEffectVfx = const {},
    this.actionLog = '',
    this.isWaitingForAction = false,
  });

  TestPetCreatorState copyWith({
    Map<TraitPart, String?>? selectedTraitNames,
    bool? petCreated,
    Pet? testPet,
    Pet? dummyEnemy,
    BattleEngine? engine,
    BattleState? battleState,
    Map<String, String>? petAnimStates,
    Map<String, String>? petEffectVfx,
    String? actionLog,
    bool? isWaitingForAction,
  }) {
    return TestPetCreatorState(
      selectedTraitNames: selectedTraitNames ?? this.selectedTraitNames,
      petCreated: petCreated ?? this.petCreated,
      testPet: testPet ?? this.testPet,
      dummyEnemy: dummyEnemy ?? this.dummyEnemy,
      engine: engine ?? this.engine,
      battleState: battleState ?? this.battleState,
      petAnimStates: petAnimStates ?? this.petAnimStates,
      petEffectVfx: petEffectVfx ?? this.petEffectVfx,
      actionLog: actionLog ?? this.actionLog,
      isWaitingForAction: isWaitingForAction ?? this.isWaitingForAction,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class TestBattleNotifier extends StateNotifier<TestPetCreatorState> {
  TestBattleNotifier() : super(const TestPetCreatorState());

  /// Select a trait for a given part by name.
  void selectTrait(TraitPart part, String traitName) {
    final updated = Map<TraitPart, String?>.from(state.selectedTraitNames);
    updated[part] = traitName;
    state = state.copyWith(selectedTraitNames: updated);
  }

  /// Get a trait object by name.
  Trait? getTraitByName(String name) {
    final allTraits = _getAllTraits();
    try {
      return allTraits.firstWhere((t) => t.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Get all available traits for a specific part.
  /// For body, return a curated list of base character types.
  List<String> getTraitNamesForPart(TraitPart part) {
    final allTraits = _getAllTraits();
    
    // Body selector shows base character types (first trait of each archetype)
    if (part == TraitPart.body) {
      return [
        'Aswang Fang',    // offensive beast
        'Bakunawa Swallow', // aquatic
        'Manananggal Drain', // support/utility
        'Tikbalang Charge',  // tank/defensive
        'Sarimanok Aura',    // healer
      ];
    }
    
    return allTraits
        .where((t) => t.part == part)
        .map((t) => t.name)
        .toList();
  }

  /// Helper: get all trait objects from TraitLibrary.
  List<Trait> _getAllTraits() {
    return [
      TraitLibrary.aswangFang,
      TraitLibrary.amihanVeil,
      TraitLibrary.enkantoFlash,
      TraitLibrary.sarimanokAura,
      TraitLibrary.tikbalangSnipe,
      TraitLibrary.bayanihanShield,
      TraitLibrary.kapreSmoke,
      TraitLibrary.anakngLupaSlam,
      TraitLibrary.bakunawaSwallow,
      TraitLibrary.lakanCounter,
      TraitLibrary.manananggalDrain,
      TraitLibrary.nunoRegen,
      TraitLibrary.tikbalangCharge,
      TraitLibrary.diwataBlessing,
      TraitLibrary.perlasStrike,
      TraitLibrary.sigbinShadow,
      TraitLibrary.bathalaWrath,
      TraitLibrary.agimatWard,
      TraitLibrary.lambanaDance,
      TraitLibrary.kulamCurse,
    ];
  }

  /// Create test pet with selected traits and initialize battle.
  void createPetAndStartBattle() {
    // Collect selected traits: body + 4 parts
    final traits = <Trait>[];
    for (final traitName in state.selectedTraitNames.values) {
      if (traitName != null) {
        final trait = getTraitByName(traitName);
        if (trait != null) traits.add(trait);
      }
    }

    if (traits.length < 5) {
      state = state.copyWith(
        actionLog: 'Select all 5 traits (body, horn, back, mouth, tail)',
      );
      return;
    }

    final testPet = Pet(
      id: 'test_pet',
      name: 'Test Pet',
      traits: traits,
      speed: 30,
      hp: 150,
    );

    // Create dummy enemy team (3 pets)
    final dummyTeam = [
      Pet(
        id: 'dummy_1',
        name: 'Dummy Front',
        traits: [TraitLibrary.aswangFang],
        speed: 20,
        hp: 100,
      ),
      Pet(
        id: 'dummy_2',
        name: 'Dummy Mid',
        traits: [TraitLibrary.bayanihanShield],
        speed: 15,
        hp: 100,
      ),
      Pet(
        id: 'dummy_3',
        name: 'Dummy Back',
        traits: [TraitLibrary.nunoRegen],
        speed: 10,
        hp: 100,
      ),
    ];

    // Initialize battle with test pet vs dummy team
    final engine = BattleEngine(
      teamA: [testPet],
      teamB: dummyTeam,
    );

    state = state.copyWith(
      testPet: testPet,
      dummyEnemy: dummyTeam.first,
      engine: engine,
      battleState: null, // BattleEngine doesn't expose current state until battle runs
      petCreated: true,
      actionLog: 'Battle started! Select a skill to execute.',
      isWaitingForAction: true,
    );
  }

  /// Trigger a skill manually on the test pet (first trait as example).
  Future<void> executeTestAction(Trait trait) async {
    final engine = state.engine;
    if (engine == null || !state.isWaitingForAction) return;

    final testPet = state.testPet;
    if (testPet == null || testPet.isFainted) {
      state = state.copyWith(
        actionLog: 'Test pet is fainted!',
        isWaitingForAction: false,
      );
      return;
    }

    // Update animation state
    state = state.copyWith(
      petAnimStates: {'test_pet': _animStateForTrait(trait)},
      petEffectVfx: {'test_pet': trait.effect.type.name},
    );

    await Future.delayed(const Duration(milliseconds: 300));

    // Simulate action (in a real scenario, would call engine.nextRound with trait)
    final log = '${state.actionLog}\n→ ${trait.name} executed!';
    state = state.copyWith(
      actionLog: log,
      petAnimStates: const {},
      petEffectVfx: const {},
    );

    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Get animation state name based on effect type.
  String _animStateForTrait(Trait trait) {
    final effectType = trait.effect.type.name;
    if (effectType.contains('damage') || effectType.contains('attack')) return 'attack';
    if (effectType.contains('shield') || effectType.contains('barrier')) return 'shield';
    if (effectType.contains('heal') || effectType.contains('regen')) return 'heal';
    if (effectType.contains('poison') || effectType.contains('debuff')) return 'debuff';
    if (effectType.contains('buff') || effectType.contains('boost')) return 'buff';
    return 'attack';
  }

  /// Reset to pet creator.
  void reset() {
    state = const TestPetCreatorState();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final testBattleProvider =
    StateNotifierProvider<TestBattleNotifier, TestPetCreatorState>(
  (ref) => TestBattleNotifier(),
);
