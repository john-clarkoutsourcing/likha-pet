/// Represents a single action taken during a PvP battle
/// Used for validation on the server
class BattleActionLog {
  final int round;
  final String actor; // pet UID performing action
  final String action; // trait/skill name
  final String? target; // target pet UID (optional for AoE)
  final int energyUsed;
  final int? damageDealt;
  final int timestamp;

  const BattleActionLog({
    required this.round,
    required this.actor,
    required this.action,
    this.target,
    required this.energyUsed,
    this.damageDealt,
    required this.timestamp,
  });

  /// Convert to JSON for server submission
  Map<String, dynamic> toJson() => {
    'round': round,
    'actor': actor,
    'action': action,
    'target': target,
    'energyUsed': energyUsed,
    'damageDealt': damageDealt,
    'timestamp': timestamp,
  };
}

/// Final state of a pet team at end of battle
class PetTeamSnapshot {
  final String petId;
  final int hp;
  final List<StatusEffectSnapshot> statusEffects;

  const PetTeamSnapshot({
    required this.petId,
    required this.hp,
    required this.statusEffects,
  });

  Map<String, dynamic> toJson() => {
    'petId': petId,
    'hp': hp,
    'statusEffects': statusEffects.map((s) => s.toJson()).toList(),
  };
}

/// Snapshot of a status effect
class StatusEffectSnapshot {
  final String type; // 'poison', 'burn', 'stun', 'buff', 'debuff'
  final int duration;
  final int? value;

  const StatusEffectSnapshot({
    required this.type,
    required this.duration,
    this.value,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'duration': duration,
    'value': value,
  };
}

/// Complete battle validation request sent to server
class BattleValidationRequest {
  final String playerId;
  final List<String> playerTeam; // 3 pet UIDs
  final List<String> opponentTeam; // 3 pet UIDs
  final String winner; // 'player' | 'opponent'
  final List<PetTeamSnapshot> finalPlayerTeamState;
  final List<PetTeamSnapshot> finalOpponentTeamState;
  final List<BattleActionLog> actionLog;
  final int battleDurationMs;
  final int? randomSeed;

  const BattleValidationRequest({
    required this.playerId,
    required this.playerTeam,
    required this.opponentTeam,
    required this.winner,
    required this.finalPlayerTeamState,
    required this.finalOpponentTeamState,
    required this.actionLog,
    required this.battleDurationMs,
    this.randomSeed,
  });

  Map<String, dynamic> toJson() => {
    'playerId': playerId,
    'playerTeam': playerTeam,
    'opponentTeam': opponentTeam,
    'winner': winner,
    'finalPlayerTeamState': finalPlayerTeamState.map((s) => s.toJson()).toList(),
    'finalOpponentTeamState': finalOpponentTeamState.map((s) => s.toJson()).toList(),
    'actionLog': actionLog.map((a) => a.toJson()).toList(),
    'battleDurationMs': battleDurationMs,
    'randomSeed': randomSeed,
  };
}

/// Server validation response
class BattleValidationResponse {
  final String result; // 'accepted' | 'rejected' | 'suspicious'
  final String? reason;
  final int? mmrChange;
  final bool? flaggedForReview;
  final bool? success;

  const BattleValidationResponse({
    required this.result,
    this.reason,
    this.mmrChange,
    this.flaggedForReview,
    this.success,
  });

  factory BattleValidationResponse.fromJson(Map<String, dynamic> json) {
    return BattleValidationResponse(
      result: json['result'] as String? ?? 'rejected',
      reason: json['reason'] as String?,
      mmrChange: json['mmrChange'] as int?,
      flaggedForReview: json['flaggedForReview'] as bool?,
      success: json['success'] as bool?,
    );
  }

  bool get isAccepted => result == 'accepted' && success == true;
  bool get isSuspicious => result == 'suspicious';
  bool get isRejected => result == 'rejected' || success == false;
}
