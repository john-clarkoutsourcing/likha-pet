import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/owned_pet.dart';
import '../models/player_data.dart';
import '../models/team_composition.dart';
import '../repositories/player_repository.dart';

// ── PlayerNotifier ────────────────────────────────────────────────────────────
//
// Owns all player-persistent state: roster, active team, soul crystals.
//
// Lifecycle:
//   1. App starts → call initialize() → loads from storage or generates starters
//   2. All mutations auto-persist via _persist()
//   3. Battle results → call awardCrystals(n)
//   4. Team builder → call setActiveTeam([uid, uid, uid])

class PlayerNotifier extends StateNotifier<PlayerData> {
  PlayerNotifier() : super(PlayerData.empty());

  final _repo = PlayerRepository();
  final _uuid = const Uuid();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    final saved = await _repo.load();
    if (saved != null && saved.hasStarters) {
      state = saved;
    }
    // If no saved data: leave roster empty.
    // HomeScreen detects roster.isEmpty and redirects to StarterPackScreen,
    // which calls addPet() interactively for each hatched egg.
    _initialized = true;
  }

  /// Wipe all saved data and re-hatch 3 fresh random pets.
  /// Useful for testing or a "reset account" flow.
  Future<void> resetAndRehatch() async {
    await _repo.clear();
    state = PlayerData.empty();
    // No auto-generation — StarterPackScreen handles the hatching flow
  }

  // ── Team management ────────────────────────────────────────────────────────

  void setActiveTeam(List<String> petUids) {
    assert(petUids.length == 3, 'Active team must have exactly 3 pets');
    state = state.copyWith(activeTeam: petUids);
    _persist();
  }

  /// Save the current active team as a new team composition.
  /// Auto-generates team name from pet classes (e.g., "PPR").
  void saveTeamComposition(String? customName) {
    if (state.activeTeam.length != 3) return;
    
    final teamId = _uuid.v4();
    final roster = state.roster;
    
    // Generate auto name from pet classes
    final petClasses = state.activeTeam
        .map((uid) => roster.firstWhere((p) => p.uid == uid))
        .map((p) => p.classLabel.isNotEmpty ? p.classLabel[0] : '?')
        .join('');
    
    final teamName = customName?.isEmpty == false 
        ? customName! 
        : petClasses.isNotEmpty ? petClasses : 'Team ${state.savedTeams.length + 1}';
    
    final newTeam = TeamComposition(
      id: teamId,
      name: teamName,
      petUids: state.activeTeam,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    state = state.copyWith(
      savedTeams: [...state.savedTeams, newTeam],
    );
    _persist();
  }

  /// Load a saved team composition as the active team.
  void loadTeamComposition(String teamId) {
    final team = state.savedTeams.cast<TeamComposition?>().firstWhere(
      (t) => t?.id == teamId,
      orElse: () => null,
    );
    if (team != null) {
      state = state.copyWith(activeTeam: team.petUids);
      _persist();
    }
  }

  /// Update the name of a saved team.
  void renameTeamComposition(String teamId, String newName) {
    final updated = state.savedTeams.map((t) {
      if (t.id == teamId) {
        return t.copyWith(
          name: newName,
          updatedAt: DateTime.now(),
        );
      }
      return t;
    }).toList();
    
    state = state.copyWith(savedTeams: updated);
    _persist();
  }

  /// Delete a saved team composition.
  void deleteTeamComposition(String teamId) {
    final updated = state.savedTeams.where((t) => t.id != teamId).toList();
    state = state.copyWith(savedTeams: updated);
    _persist();
  }

  // ── Pet management ─────────────────────────────────────────────────────────

  void addPet(OwnedPet pet) {
    state = state.copyWith(roster: [...state.roster, pet]);
    _persist();
  }

  /// Replace roster with server-authoritative pets (inventory sync).
  /// Keeps valid active team members when possible, then fills remaining slots.
  void replaceRosterFromServer(List<OwnedPet> pets) {
    final roster = List<OwnedPet>.from(pets);
    final rosterIds = roster.map((p) => p.uid).toSet();

    final keptActive = state.activeTeam.where(rosterIds.contains).toList();
    final fill = roster
        .map((p) => p.uid)
        .where((id) => !keptActive.contains(id))
        .toList();
    final nextActive = [...keptActive, ...fill].take(3).toList();

    state = state.copyWith(
      roster: roster,
      activeTeam: nextActive,
    );
    _persist();
  }

  void renamePet(String uid, String newName) {
    final updated = state.roster
        .map((p) => p.uid == uid ? p.copyWith(name: newName) : p)
        .toList();
    state = state.copyWith(roster: updated);
    _persist();
  }

  // ── Resources ─────────────────────────────────────────────────────────────

  void awardCrystals(int amount) {
    state = state.copyWith(soulCrystals: state.soulCrystals + amount);
    _persist();
  }

  bool spendCrystals(int amount) {
    if (state.soulCrystals < amount) return false;
    state = state.copyWith(soulCrystals: state.soulCrystals - amount);
    _persist();
    return true;
  }

  // ── Stage progress ────────────────────────────────────────────────────────

  void completeStage(String stageId) {
    if (state.completedStages.contains(stageId)) return;
    state =
        state.copyWith(completedStages: {...state.completedStages, stageId});
    _persist();
  }

  // ── Breeding ──────────────────────────────────────────────────────────────
  //
  // Breeding cost: 100 crystals × (parentA.breedCount + parentB.breedCount + 2)
  // Each parent's breedCount increments after a successful breed.
  // Offspring's dominant gene for each slot is inherited probabilistically:
  //   37.5% parent A dominant  |  37.5% parent B dominant
  //   9.375% parent A R1       |  9.375% parent B R1
  //   3.125% parent A R2       |  3.125% parent B R2

  int breedCost(String uidA, String uidB) {
    final a = state.petById(uidA);
    final b = state.petById(uidB);
    if (a == null || b == null) return 0;
    return 100 * (a.breedCount + b.breedCount + 2);
  }

  OwnedPet? breed(String uidA, String uidB, String offspringName) {
    final a = state.petById(uidA);
    final b = state.petById(uidB);
    if (a == null || b == null) return null;
    if (!a.canBreed || !b.canBreed) return null;

    final cost = breedCost(uidA, uidB);
    if (!spendCrystals(cost)) return null;

    // Offspring hatches with inherited DNA — blend parent DNA with probabilistic inheritance.
    // This implements a simplified version of Axie genetics using DNA bytes.
    final offspringDNA = _breedDNA(a.dna, b.dna);

    final offspring = OwnedPet(
      uid: _uuid.v4(),
      name: offspringName,
      dna: offspringDNA,
      generation: _max(a.generation, b.generation) + 1,
      parentAId: uidA,
      parentBId: uidB,
      createdAt: DateTime.now(),
    );

    // Increment breed counts
    final updatedRoster = state.roster.map((p) {
      if (p.uid == uidA) return p.copyWith(breedCount: p.breedCount + 1);
      if (p.uid == uidB) return p.copyWith(breedCount: p.breedCount + 1);
      return p;
    }).toList()
      ..add(offspring);

    state = state.copyWith(roster: updatedRoster);
    _persist();
    return offspring;
  }

  // ── Breeding helpers ───────────────────────────────────────────────────────

  /// Breed two DNA strings to create offspring DNA.
  /// Implements simplified Axie genetics: offspring DNA is blended from parents.
  ///
  /// Strategy:
  ///   - Body class (byte 0): 50/50 from each parent
  ///   - Part classes (bytes 1-4): probabilistically inherit from each parent
  ///   - Other attributes (bytes 5-11): blend from parents with randomness
  String _breedDNA(String parentADNA, String parentBDNA) {
    final aBytes = _dnaBytesFromHex(parentADNA);
    final bBytes = _dnaBytesFromHex(parentBDNA);
    final offspring = <int>[];

    // Byte 0: Body class (50/50 from parents)
    offspring.add(_rng.nextBool() ? aBytes[0] : bBytes[0]);

    // Bytes 1-4: Part classes (probabilistically from parents)
    for (int i = 1; i < 5; i++) {
      offspring.add(_rng.nextBool() ? aBytes[i] : bBytes[i]);
    }

    // Bytes 5-11: Blend from parents with slight randomness
    for (int i = 5; i < 12; i++) {
      final avg = ((aBytes[i] + bBytes[i]) ~/ 2);
      final mutated = avg + _rng.nextInt(-10, 10); // Small mutation
      offspring.add(mutated.clamp(0, 255));
    }

    return offspring.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// Extract 12 bytes from a 24-char hex DNA string.
  List<int> _dnaBytesFromHex(String dna) {
    final bytes = <int>[];
    for (int i = 0; i < 24; i += 2) {
      bytes.add(int.parse(dna.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  int _max(int a, int b) => a > b ? a : b;

  static final _rng = _RNG();

  // ── Persistence ───────────────────────────────────────────────────────────

  void _persist() {
    _repo.save(state);
  }
}

// Tiny wrapper for pseudo-random number generation
class _RNG {
  bool nextBool() => DateTime.now().microsecond.isEven;

  int nextInt(int min, int max) {
    final t = DateTime.now();
    final range = max - min;
    final rand = ((t.microsecond * 1000 + t.millisecond) % 100000) / 100000.0;
    return min + (rand * range).toInt();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerData>(
  (ref) => PlayerNotifier(),
);
