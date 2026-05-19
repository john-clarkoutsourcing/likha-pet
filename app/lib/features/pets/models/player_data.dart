import 'dart:convert';
import 'owned_pet.dart';
import 'team_composition.dart';

// ── PlayerData ────────────────────────────────────────────────────────────────
//
// The full state persisted for one player session.
// [roster]     — all owned pets (ordered: newest last)
// [activeTeam] — UIDs of the 3 pets chosen for the next battle
// [soulCrystals] — SLP equivalent; earned from battles, spent on breeding

class PlayerData {
  final List<OwnedPet> roster;
  final List<String>   activeTeam;     // 3 OwnedPet UIDs [front, mid, back]
  final String?        activeTeamId;   // ID of the saved TeamComposition in use
  final int            soulCrystals;
  final Set<String>    completedStages; // stage IDs ('1', '2', …)
  final List<TeamComposition> savedTeams; // team presets

  // ── Starter pack progress ──────────────────────────────────────────────────
  // revealedStarterUids: UIDs of starter eggs already hatched by the player.
  //   Persisted so a mid-hatch page refresh restores correct egg states.
  // starterComplete: true once the player pressed "Start Adventure!" —
  //   HomeScreen uses this to skip the starter pack on re-login.
  final Set<String> revealedStarterUids;
  final bool        starterComplete;

  const PlayerData({
    required this.roster,
    required this.activeTeam,
    this.activeTeamId,
    this.soulCrystals        = 0,
    this.completedStages     = const {},
    this.savedTeams          = const [],
    this.revealedStarterUids = const {},
    this.starterComplete     = false,
  });

  factory PlayerData.empty() => const PlayerData(
    roster:               [],
    activeTeam:           [],
    activeTeamId:         null,
    soulCrystals:         0,
    completedStages:      {},
    savedTeams:           [],
    revealedStarterUids:  {},
    starterComplete:      false,
  );

  /// Returns the active saved team composition, or null if none is set.
  TeamComposition? get activeComposition => activeTeamId == null
      ? null
      : savedTeams.cast<TeamComposition?>()
            .firstWhere((t) => t?.id == activeTeamId, orElse: () => null);

  bool get hasStarters  => roster.isNotEmpty;
  /// True only when the starter pack animation is fully done.
  bool get starterPackDone => starterComplete;
  bool get hasFullTeam  => activeTeam.length == 3;

  bool isStageCompleted(String id) => completedStages.contains(id);

  /// Highest completed stage number (0 = none completed).
  int get highestStage => completedStages.isEmpty
      ? 0
      : completedStages.map(int.parse).reduce((a, b) => a > b ? a : b);

  List<OwnedPet> get activeRoster => activeTeam
      .map((uid) => roster.cast<OwnedPet?>()
          .firstWhere((p) => p?.uid == uid, orElse: () => null))
      .whereType<OwnedPet>()
      .toList();

  OwnedPet? petById(String uid) =>
      roster.cast<OwnedPet?>().firstWhere((p) => p?.uid == uid, orElse: () => null);

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory PlayerData.fromJson(Map<String, dynamic> j) => PlayerData(
    roster: (j['roster'] as List<dynamic>)
        .map((e) => OwnedPet.fromJson(e as Map<String, dynamic>))
        .toList(),
    activeTeam:      List<String>.from(j['activeTeam'] as List),
    activeTeamId:    j['activeTeamId'] as String?,
    soulCrystals:    (j['soulCrystals'] as int?) ?? 0,
    completedStages: Set<String>.from(
        (j['completedStages'] as List<dynamic>?) ?? []),
    savedTeams: (j['savedTeams'] as List<dynamic>?)
        ?.map((e) => TeamComposition.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    revealedStarterUids: Set<String>.from(
        (j['revealedStarterUids'] as List<dynamic>?) ?? []),
    starterComplete: (j['starterComplete'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => {
    'roster':               roster.map((p) => p.toJson()).toList(),
    'activeTeam':           activeTeam,
    if (activeTeamId != null) 'activeTeamId': activeTeamId,
    'soulCrystals':         soulCrystals,
    'completedStages':      completedStages.toList(),
    'savedTeams':           savedTeams.map((t) => t.toJson()).toList(),
    'revealedStarterUids':  revealedStarterUids.toList(),
    'starterComplete':      starterComplete,
  };

  String toJsonString() => jsonEncode(toJson());
  factory PlayerData.fromJsonString(String s) =>
      PlayerData.fromJson(jsonDecode(s) as Map<String, dynamic>);

  PlayerData copyWith({
    List<OwnedPet>? roster,
    List<String>?   activeTeam,
    Object?         activeTeamId = _sentinel,
    int?            soulCrystals,
    Set<String>?    completedStages,
    List<TeamComposition>? savedTeams,
    Set<String>?    revealedStarterUids,
    bool?           starterComplete,
  }) => PlayerData(
    roster:               roster               ?? this.roster,
    activeTeam:           activeTeam           ?? this.activeTeam,
    activeTeamId:         activeTeamId == _sentinel
        ? this.activeTeamId
        : activeTeamId as String?,
    soulCrystals:         soulCrystals         ?? this.soulCrystals,
    completedStages:      completedStages      ?? this.completedStages,
    savedTeams:           savedTeams           ?? this.savedTeams,
    revealedStarterUids:  revealedStarterUids  ?? this.revealedStarterUids,
    starterComplete:      starterComplete      ?? this.starterComplete,
  );
}

// Sentinel so copyWith can explicitly clear activeTeamId to null.
const Object _sentinel = Object();
