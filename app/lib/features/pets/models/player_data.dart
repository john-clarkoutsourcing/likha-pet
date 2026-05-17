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
  final List<String>   activeTeam;     // 3 OwnedPet UIDs
  final int            soulCrystals;
  final Set<String>    completedStages; // stage IDs ('1', '2', …)
  final List<TeamComposition> savedTeams; // team presets

  const PlayerData({
    required this.roster,
    required this.activeTeam,
    this.soulCrystals    = 0,
    this.completedStages = const {},
    this.savedTeams      = const [],
  });

  factory PlayerData.empty() => const PlayerData(
    roster:          [],
    activeTeam:      [],
    soulCrystals:    0,
    completedStages: {},
    savedTeams:      [],
  );

  bool get hasStarters  => roster.isNotEmpty;
  bool get hasFullTeam  => activeTeam.length == 3;

  bool isStageCompleted(String id) => completedStages.contains(id);

  /// Highest completed stage number (0 = none completed).
  int get highestStage => completedStages.isEmpty
      ? 0
      : completedStages.map(int.parse).reduce((a, b) => a > b ? a : b);

  List<OwnedPet> get activeRoster =>
      activeTeam.map((uid) => roster.firstWhere((p) => p.uid == uid)).toList();

  OwnedPet? petById(String uid) =>
      roster.cast<OwnedPet?>().firstWhere((p) => p?.uid == uid, orElse: () => null);

  // ── Serialisation ──────────────────────────────────────────────────────────

  factory PlayerData.fromJson(Map<String, dynamic> j) => PlayerData(
    roster: (j['roster'] as List<dynamic>)
        .map((e) => OwnedPet.fromJson(e as Map<String, dynamic>))
        .toList(),
    activeTeam:      List<String>.from(j['activeTeam'] as List),
    soulCrystals:    (j['soulCrystals'] as int?) ?? 0,
    completedStages: Set<String>.from(
        (j['completedStages'] as List<dynamic>?) ?? []),
    savedTeams: (j['savedTeams'] as List<dynamic>?)
        ?.map((e) => TeamComposition.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'roster':          roster.map((p) => p.toJson()).toList(),
    'activeTeam':      activeTeam,
    'soulCrystals':    soulCrystals,
    'completedStages': completedStages.toList(),
    'savedTeams':      savedTeams.map((t) => t.toJson()).toList(),
  };

  String toJsonString() => jsonEncode(toJson());
  factory PlayerData.fromJsonString(String s) =>
      PlayerData.fromJson(jsonDecode(s) as Map<String, dynamic>);

  PlayerData copyWith({
    List<OwnedPet>? roster,
    List<String>?   activeTeam,
    int?            soulCrystals,
    Set<String>?    completedStages,
    List<TeamComposition>? savedTeams,
  }) => PlayerData(
    roster:          roster          ?? this.roster,
    activeTeam:      activeTeam      ?? this.activeTeam,
    soulCrystals:    soulCrystals    ?? this.soulCrystals,
    completedStages: completedStages ?? this.completedStages,
    savedTeams:      savedTeams      ?? this.savedTeams,
  );
}
