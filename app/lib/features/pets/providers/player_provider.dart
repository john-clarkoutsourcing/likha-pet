import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/owned_pet.dart';
import '../models/player_data.dart';
import '../models/team_composition.dart';
import '../repositories/player_repository.dart';
import '../repositories/team_firestore_repository.dart';

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

  final _repo      = PlayerRepository();
  final _teamFs    = TeamFirestoreRepository();
  final _uuid      = const Uuid();

  // UID of the logged-in player — set via [setUserId] after auth resolves.
  String? _uid;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Call after auth resolves to wire Firestore sync and force re-init.
  /// Switches the repository to the user's own storage key so data is
  /// never shared between accounts on the same device.
  void setUserId(String uid) {
    if (_uid == uid) return; // same session, nothing to reset
    _uid = uid;
    _repo.setUid(uid); // point storage at this user's isolated key
    _initialized = false; // force full reload on next initialize()
  }

  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Load local state first (fast path — works offline)
    final saved = await _repo.load();
    if (saved != null && saved.hasStarters) {
      state = saved;
    }

    // 2. Firestore sync — roster is authoritative source across devices/browsers
    if (_uid != null) {
      try {
        final results = await Future.wait([
          _teamFs.loadRoster(_uid!),
          _teamFs.loadTeams(_uid!),
          _teamFs.loadActiveTeam(_uid!),
        ]);

        final fsRoster    = results[0] as List<OwnedPet>?;
        final fsTeams     = results[1] as List<TeamComposition>;
        final fsActiveTeam = results[2] as List<String>?;

        // Prefer Firestore roster over local when it has more pets —
        // handles the case where local storage was cleared or the user
        // is on a different device/browser.
        final bestRoster = (fsRoster != null && fsRoster.length >= state.roster.length)
            ? fsRoster
            : state.roster;

        state = state.copyWith(
          roster:     bestRoster,
          savedTeams: fsTeams.isNotEmpty ? fsTeams : state.savedTeams,
          activeTeam: fsActiveTeam ?? state.activeTeam,
        );
        await _repo.save(state);
      } catch (_) {
        // Firestore unavailable — local data is already loaded above.
      }
    }

    _initialized = true;
  }

  /// Reset in-memory session state on logout.
  /// Does NOT clear local storage — data is stored per-user via setUserId,
  /// so this user's pets are restored on the next login.
  Future<void> reset() async {
    _uid = null;
    _initialized = false;
    state = PlayerData.empty();
  }

  /// Wipe all saved data and re-hatch 3 fresh random pets.
  Future<void> resetAndRehatch() async {
    await _repo.clear();
    state = PlayerData.empty();
  }

  // ── Team management ────────────────────────────────────────────────────────

  void setActiveTeam(List<String> petUids) {
    assert(petUids.length == 3, 'Active team must have exactly 3 pets');
    state = state.copyWith(activeTeam: petUids);
    _persist();
    if (_uid != null) _teamFs.setActiveTeam(_uid!, petUids);
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

    final slots = List.generate(state.activeTeam.length, (i) => TeamSlot(
      petUid: state.activeTeam[i],
      row: BattleRow.fromIndex(i),
      lane: BattleLane.center,
    ));
    
    final newTeam = TeamComposition(
      id: teamId,
      name: teamName,
      slots: slots,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    state = state.copyWith(
      savedTeams: [...state.savedTeams, newTeam],
    );
    _persist();
    if (_uid != null) _teamFs.upsertTeam(_uid!, newTeam);
  }

  /// Load a saved team composition as the active team.
  void loadTeamComposition(String teamId) {
    final team = state.savedTeams.cast<TeamComposition?>().firstWhere(
      (t) => t?.id == teamId,
      orElse: () => null,
    );
    if (team != null) {
      state = state.copyWith(activeTeam: team.petUids, activeTeamId: teamId);
      _persist();
      if (_uid != null) _teamFs.setActiveTeam(_uid!, team.petUids);
    }
  }

  /// Update the name of a saved team.
  void renameTeamComposition(String teamId, String newName) {
    final updated = state.savedTeams.map((t) {
      if (t.id == teamId) {
        return t.copyWith(name: newName, updatedAt: DateTime.now());
      }
      return t;
    }).toList();
    state = state.copyWith(savedTeams: updated);
    _persist();
    final renamed = state.savedTeams.firstWhere((t) => t.id == teamId);
    if (_uid != null) _teamFs.upsertTeam(_uid!, renamed);
  }

  /// Delete a saved team composition.
  void deleteTeamComposition(String teamId) {
    final updated = state.savedTeams.where((t) => t.id != teamId).toList();
    // Clear activeTeamId if the deleted team was active.
    final wasActive = state.activeTeamId == teamId;
    state = state.copyWith(
      savedTeams:   updated,
      activeTeamId: wasActive ? null : state.activeTeamId,
    );
    _persist();
    if (_uid != null) _teamFs.deleteTeam(_uid!, teamId);
  }

  /// Create a new team composition directly from a name and pet UIDs.
  void createTeamComposition(String name, List<TeamSlot> slots) {
    if (slots.isEmpty) return;
    final petUids = slots.map((s) => s.petUid).toList();
    final newTeam = TeamComposition(
      id: _uuid.v4(),
      name: name,
      slots: slots,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    // Newly created team becomes active immediately.
    state = state.copyWith(
      savedTeams:   [...state.savedTeams, newTeam],
      activeTeam:   petUids,
      activeTeamId: newTeam.id,
    );
    _persist();
    if (_uid != null) _teamFs.upsertTeam(_uid!, newTeam);
  }

  /// Replace the pets and/or name of an existing saved team composition.
  void updateTeamComposition(String teamId, String name, List<TeamSlot> slots) {
    if (slots.isEmpty) return;
    final updated = state.savedTeams.map((t) {
      if (t.id != teamId) return t;
      return t.copyWith(name: name, slots: slots, updatedAt: DateTime.now());
    }).toList();
    state = state.copyWith(savedTeams: updated);
    _persist();
    final t = state.savedTeams.firstWhere((t) => t.id == teamId);
    if (_uid != null) _teamFs.upsertTeam(_uid!, t);
  }

  // ── Starter pack progress ──────────────────────────────────────────────────

  /// Save the 3 generated starter pets all at once (before any hatching).
  void saveStarterPets(List<OwnedPet> pets) {
    state = state.copyWith(roster: pets);
    _persist();
  }

  /// Mark one starter egg as revealed (hatching animation played).
  void revealStarterPet(String uid) {
    state = state.copyWith(
      revealedStarterUids: {...state.revealedStarterUids, uid},
    );
    _persist();
  }

  /// Called when the player presses "Start Adventure!" — marks pack as done.
  void completeStarterPack() {
    state = state.copyWith(starterComplete: true);
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
    final rng    = math.Random();
    final aBytes = _dnaBytesFromHex(parentADNA);
    final bBytes = _dnaBytesFromHex(parentBDNA);
    final offspring = <int>[];

    // Byte 0: Body class — 50/50 from each parent independently.
    offspring.add(rng.nextBool() ? aBytes[0] : bBytes[0]);

    // Bytes 1-4: Part classes — each slot independently 50/50.
    for (int i = 1; i < 5; i++) {
      offspring.add(rng.nextBool() ? aBytes[i] : bBytes[i]);
    }

    // Bytes 5-11: Visual attributes (color, rarity, element, pattern, variants).
    // Blend from both parents with a small ±10 mutation to allow novelty.
    for (int i = 5; i < 12; i++) {
      final avg     = (aBytes[i] + bBytes[i]) ~/ 2;
      final delta   = rng.nextInt(21) - 10; // uniform -10…+10
      offspring.add((avg + delta).clamp(0, 255));
    }

    return offspring.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  List<int> _dnaBytesFromHex(String dna) {
    final bytes = <int>[];
    for (int i = 0; i < 24; i += 2) {
      bytes.add(int.parse(dna.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  int _max(int a, int b) => a > b ? a : b;

  // ── Persistence ───────────────────────────────────────────────────────────

  void _persist() {
    _repo.save(state);
    if (_uid != null) {
      _teamFs.saveRoster(_uid!, state.roster);
    }
  }
}


// ── Provider ──────────────────────────────────────────────────────────────────

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerData>(
  (ref) => PlayerNotifier(),
);
