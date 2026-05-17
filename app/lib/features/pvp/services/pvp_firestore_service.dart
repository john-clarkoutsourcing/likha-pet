import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:likha_pet/features/pvp/models/battle_action_log.dart';

/// Service for storing battle validation results in Firestore.
///
/// Handles:
/// - Storing full battle logs (action history, team compositions)
/// - Storing validation server results (accepted/rejected, anti-cheat flags)
/// - Querying player battle history
/// - Detecting flagged accounts
class PvpFirestoreService {
  final FirebaseFirestore _firestore;

  PvpFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stores a complete battle log in Firestore.
  ///
  /// This is the client-side record. The server's validation result is stored separately.
  Future<void> storeBattleLog({
    required String battleId,
    required String playerId,
    required String opponentId,
    required List<String> playerTeam,
    required List<String> opponentTeam,
    required List<BattleActionLog> actionLog,
    required List<PetTeamSnapshot> finalPlayerTeamState,
    required List<PetTeamSnapshot> finalOpponentTeamState,
    required int battleDurationMs,
    required int randomSeed,
  }) async {
    try {
      await _firestore.collection('battles').doc(battleId).set({
        'playerId': playerId,
        'opponentId': opponentId,
        'playerTeam': playerTeam,
        'opponentTeam': opponentTeam,
        'actionLog': actionLog.map((a) => a.toJson()).toList(),
        'finalPlayerTeamState':
            finalPlayerTeamState.map((p) => p.toJson()).toList(),
        'finalOpponentTeamState':
            finalOpponentTeamState.map((p) => p.toJson()).toList(),
        'battleDurationMs': battleDurationMs,
        'randomSeed': randomSeed,
        'createdAt': FieldValue.serverTimestamp(),
        'mode': 'pvp',
      });
    } catch (e) {
      // Silently fail - battle log is not critical for PvP functionality
      // Server has its own validation results
      print('[Firestore] Warning: Failed to store battle log: $e');
    }
  }

  /// Stores the server's validation result for a battle.
  ///
  /// This is typically called after the server validates the battle.
  /// Contains the decision (accepted/rejected/suspicious) and anti-cheat details.
  Future<void> storeValidationResult({
    required String battleId,
    required String playerId,
    required BattleValidationResponse response,
    required String validationDetails,
  }) async {
    try {
      await _firestore.collection('validationResults').doc(battleId).set({
        'playerId': playerId,
        'result': response.result,
        'isAccepted': response.isAccepted,
        'isRejected': response.isRejected,
        'isSuspicious': response.isSuspicious,
        'mmrChange': response.mmrChange ?? 0,
        'reason': response.reason,
        'flaggedForReview': response.flaggedForReview,
        'validationDetails': validationDetails,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silently fail - validation result storage is non-critical
      // Server has already processed the validation
      print('[Firestore] Warning: Failed to store validation result: $e');
    }
  }

  /// Fetches a player's recent battles from Firestore.
  ///
  /// Limited to the last [limit] battles, ordered by most recent first.
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> getPlayerBattleHistory({
    required String playerId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('battles')
          .where('playerId', isEqualTo: playerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      // Return empty list on error - non-critical operation
      print('[Firestore] Warning: Failed to fetch battle history: $e');
      return [];
    }
  }

  /// Fetches validation results for a player's battles.
  ///
  /// Helps track which battles were flagged for review or rejected.
  Future<List<DocumentSnapshot<Map<String, dynamic>>>>
      getPlayerValidationHistory({
    required String playerId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('validationResults')
          .where('playerId', isEqualTo: playerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      // Return empty list on error - non-critical operation
      print('[Firestore] Warning: Failed to fetch validation history: $e');
      return [];
    }
  }

  /// Fetches all battles flagged as suspicious.
  ///
  /// Used by admin dashboard to investigate potential cheaters.
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> getSuspiciousBattles({
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('validationResults')
          .where('isSuspicious', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      // Return empty list on error - non-critical operation
      print('[Firestore] Warning: Failed to fetch suspicious battles: $e');
      return [];
    }
  }

  /// Fetches all battles flagged for manual review.
  ///
  /// Used by moderation team to approve/reject suspicious accounts.
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> getFlaggedBattles({
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('validationResults')
          .where('flaggedForReview', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      // Return empty list on error - non-critical operation
      print('[Firestore] Warning: Failed to fetch flagged battles: $e');
      return [];
    }
  }

  /// Checks if a player account is currently flagged for suspicious behavior.
  Future<bool> isPlayerFlagged(String playerId) async {
    try {
      final snapshot = await _firestore
          .collection('validationResults')
          .where('playerId', isEqualTo: playerId)
          .where('flaggedForReview', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      // Return false on error - assume not flagged if check fails
      print('[Firestore] Warning: Failed to check player flag status: $e');
      return false;
    }
  }

  /// Gets a single battle log by ID.
  Future<DocumentSnapshot<Map<String, dynamic>>?> getBattleLog(
    String battleId,
  ) async {
    try {
      final doc = await _firestore.collection('battles').doc(battleId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      // Return null on error - non-critical operation
      print('[Firestore] Warning: Failed to fetch battle log: $e');
      return null;
    }
  }

  /// Gets validation result for a specific battle.
  Future<DocumentSnapshot<Map<String, dynamic>>?> getValidationResult(
    String battleId,
  ) async {
    try {
      final doc =
          await _firestore.collection('validationResults').doc(battleId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      // Return null on error - non-critical operation
      print('[Firestore] Warning: Failed to fetch validation result: $e');
      return null;
    }
  }
}
