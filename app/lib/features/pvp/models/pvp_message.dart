import 'dart:convert';

// ── Inbound (server → client) ─────────────────────────────────────────────────

sealed class PvpMessage {
  const PvpMessage();

  static PvpMessage? fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String? ?? '') {
      'queue:status'           => PvpQueueStatus.fromJson(json),
      'match:found'            => PvpMatchFound.fromJson(json),
      'round:locked'           => PvpRoundLocked.fromJson(json),
      'match:end'              => PvpMatchEnd.fromJson(json),
      'match:resume'           => PvpMatchResume.fromJson(json),
      'opponent:disconnected'  => PvpOpponentDisconnected.fromJson(json),
      'error'                  => PvpError.fromJson(json),
      _                        => null,
    };
  }

  static PvpMessage? tryParse(String raw) {
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

class PetDnaRef {
  final String uid;
  final String dna;
  final int? createdAtMs;
  const PetDnaRef({required this.uid, required this.dna, this.createdAtMs});

  factory PetDnaRef.fromJson(Map<String, dynamic> j) =>
      PetDnaRef(
        uid: j['uid'] as String,
        dna: j['dna'] as String,
        createdAtMs: j['createdAtMs'] as int?,
      );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'dna': dna,
    if (createdAtMs != null) 'createdAtMs': createdAtMs,
  };
}

class PvpPlayerInfo {
  final String userId;
  final String displayName;
  final List<PetDnaRef> team;
  final int mmr;

  const PvpPlayerInfo({
    required this.userId,
    required this.displayName,
    required this.team,
    required this.mmr,
  });

  factory PvpPlayerInfo.fromJson(Map<String, dynamic> j) => PvpPlayerInfo(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String? ?? '',
        team: (j['team'] as List).map((e) => PetDnaRef.fromJson(e as Map<String, dynamic>)).toList(),
        mmr: (j['mmr'] as num?)?.toInt() ?? 1000,
      );
}

class PvpQueueStatus extends PvpMessage {
  final int position;
  final int mmr;
  const PvpQueueStatus({required this.position, required this.mmr});
  factory PvpQueueStatus.fromJson(Map<String, dynamic> j) =>
      PvpQueueStatus(position: (j['position'] as num).toInt(), mmr: (j['mmr'] as num).toInt());
}

class PvpMatchFound extends PvpMessage {
  final String matchId;
  final int seed;
  final PvpPlayerInfo you;
  final PvpPlayerInfo opponent;
  final int firstRoundDeadlineMs;

  const PvpMatchFound({
    required this.matchId,
    required this.seed,
    required this.you,
    required this.opponent,
    required this.firstRoundDeadlineMs,
  });

  factory PvpMatchFound.fromJson(Map<String, dynamic> j) => PvpMatchFound(
        matchId: j['matchId'] as String,
        seed: (j['seed'] as num).toInt(),
        you: PvpPlayerInfo.fromJson(j['you'] as Map<String, dynamic>),
        opponent: PvpPlayerInfo.fromJson(j['opponent'] as Map<String, dynamic>),
        firstRoundDeadlineMs: (j['firstRoundDeadlineMs'] as num).toInt(),
      );
}

class PvpRoundLocked extends PvpMessage {
  final String matchId;
  final int round;
  // selections: { userId -> { petId -> [cardInstanceId, ...] } }
  final Map<String, Map<String, List<String>>> selections;
  final int nextDeadlineMs;

  const PvpRoundLocked({
    required this.matchId,
    required this.round,
    required this.selections,
    required this.nextDeadlineMs,
  });

  factory PvpRoundLocked.fromJson(Map<String, dynamic> j) {
    final rawSel = j['selections'] as Map<String, dynamic>;
    final selections = rawSel.map((userId, rawPets) {
      final pets = (rawPets as Map<String, dynamic>).map(
          (petId, cards) => MapEntry(petId, (cards as List).cast<String>()));
      return MapEntry(userId, pets);
    });
    return PvpRoundLocked(
      matchId: j['matchId'] as String,
      round: (j['round'] as num).toInt(),
      selections: selections,
      nextDeadlineMs: (j['nextDeadlineMs'] as num).toInt(),
    );
  }
}

class PvpMatchEnd extends PvpMessage {
  final String matchId;
  final String? winnerUid;
  final bool dispute;
  final int mmrDelta;

  const PvpMatchEnd({
    required this.matchId,
    required this.winnerUid,
    required this.dispute,
    required this.mmrDelta,
  });

  factory PvpMatchEnd.fromJson(Map<String, dynamic> j) => PvpMatchEnd(
        matchId: j['matchId'] as String,
        winnerUid: j['winnerUid'] as String?,
        dispute: (j['dispute'] as bool?) ?? false,
        mmrDelta: (j['mmrDelta'] as num?)?.toInt() ?? 0,
      );
}

class PvpMatchResume extends PvpMessage {
  final String matchId;
  final int round;
  final String status;
  const PvpMatchResume({required this.matchId, required this.round, required this.status});
  factory PvpMatchResume.fromJson(Map<String, dynamic> j) => PvpMatchResume(
        matchId: j['matchId'] as String,
        round: (j['round'] as num).toInt(),
        status: j['status'] as String? ?? '',
      );
}

class PvpOpponentDisconnected extends PvpMessage {
  final int gracePeriodMs;
  const PvpOpponentDisconnected({required this.gracePeriodMs});
  factory PvpOpponentDisconnected.fromJson(Map<String, dynamic> j) =>
      PvpOpponentDisconnected(gracePeriodMs: (j['gracePeriodMs'] as num).toInt());
}

class PvpError extends PvpMessage {
  final String code;
  final String message;
  const PvpError({required this.code, required this.message});
  factory PvpError.fromJson(Map<String, dynamic> j) =>
      PvpError(code: j['code'] as String? ?? '', message: j['message'] as String? ?? '');
}

// ── Outbound (client → server) ────────────────────────────────────────────────

class OutQueueJoin {
  final List<PetDnaRef> team;
  const OutQueueJoin({required this.team});
  Map<String, dynamic> toJson() => {'type': 'queue:join', 'team': team.map((t) => t.toJson()).toList()};
}

class OutQueueLeave {
  const OutQueueLeave();
  Map<String, dynamic> toJson() => {'type': 'queue:leave'};
}

class OutRoundSubmit {
  final String matchId;
  final int round;
  // petId → [cardInstanceId, ...]
  final Map<String, List<String>> selections;

  const OutRoundSubmit({required this.matchId, required this.round, required this.selections});

  Map<String, dynamic> toJson() => {
        'type': 'round:submit',
        'matchId': matchId,
        'round': round,
        'selections': selections,
      };
}

class OutClientResult {
  final String matchId;
  final String winnerUid;
  final String transcriptChecksum;

  const OutClientResult({
    required this.matchId,
    required this.winnerUid,
    required this.transcriptChecksum,
  });

  Map<String, dynamic> toJson() => {
        'type': 'client:result',
        'matchId': matchId,
        'winnerUid': winnerUid,
        'transcriptChecksum': transcriptChecksum,
      };
}

class OutMatchResume {
  final String matchId;
  const OutMatchResume({required this.matchId});
  Map<String, dynamic> toJson() => {'type': 'match:resume', 'matchId': matchId};
}
