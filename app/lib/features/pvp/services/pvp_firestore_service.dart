import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:likha_pet/features/pvp/models/battle_action_log.dart';

/// Service for storing battle validation results in Firestore.
///
/// Uses lazy initialization to avoid throwing exceptions on app startup.
/// On web, Firestore is disabled due to JavaScript interop type issues.
class PvpFirestoreService {
  FirebaseFirestore? _firestore;
  final FirebaseFirestore? _injectedFirestore;
  final bool _isWeb = kIsWeb;

  PvpFirestoreService({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  /// Lazy-load Firestore instance with error handling.
  /// Returns null on web or if initialization fails.
  FirebaseFirestore? _getFirestore() {
    // Skip entirely on web platform
    if (_isWeb) {
      return null;
    }

    // Use injected instance if available
    if (_injectedFirestore != null) {
      return _injectedFirestore;
    }

    // Attempt to access shared instance with error handling
    if (_firestore != null) {
      return _firestore;
    }

    try {
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } catch (e) {
      // If Firestore.instance throws, gracefully degrade
      print('[Firestore] Warning: Failed to initialize Firestore: $e');
      return null;
    }
  }

  /// Stores a complete battle log in Firestore.
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
    final firestore = _getFirestore();
    if (firestore == null) {
      return;
    }

    try {
      await firestore.collection('battles').doc(battleId).set({
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
      print('[Firestore] Warning: Failed to store battle log: $e');
    }
  }

  /// Stores the server's validation result for a battle.
  Future<void> storeValidationResult({
    required String battleId,
    required String playerId,
    required BattleValidationResponse response,
    required String validationDetails,
  }) async {
    final firestore = _getFirestore();
    if (firestore == null) {
      return;
    }

    try {
      await firestore.collection('validationResults').doc(battleId).set({
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
      print('[Firestore] Warning: Failed to store validation result: $e');
    }
  }

  /// Fetches a player's recent battles from Firestore.
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> getPlayerBattleHistory({
    required String playerId,
    int limit = 50,
  }) async {
    final firestore = _getFirestore();
    if (firestore == null) {
      return [];
    }

    try {
      final snapshot = await firestore
          .collection('battles')
          .where('playerId', isEqualTo: playerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      print('[Firestore] Warning: Failed to fetch battle history: $e');
      return [];
    }
  }

  /// Fetches validation results for a player's battles.
  Future<List<DocumentSnapshot<Map<String, dynamic>>>>
      getPlayerValidationHistory({
    required String playerId,
    int limit = 50,
  }) async {
    final firestore = _getFirestore();
    if (firestore == null) {
      return [];
    }

    try {
      final snapshot = await firestore
          .collection('validationResults')
          .where('playerId', isEqualTo: playerId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      print('[Firestore] Warning: Failed to fetch validation history: $e');
      return [];
    }
  }

  /// Fetches all battles flagged as suspicious.
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> getSuspiciousBattles({
    int limit = 100,
  }) async {
    final firestore = _getFirestore();
    if (firestore == null) {
      return [];
    }

    try {
      final snapshot = await firestore
          .collection('validationResults')
          .where('isSuspicious', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      print('[Firestore] Warning: Failed to fetch suspicious battles: $e');
      return [];
    }
  }

  /// Fetches all battles flagged for manual review.
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> getFlaggedBattles({
    int limit = 100,
  }) async {
    final firestore = _getFirestore();
    if (firestore == null) {
      return [];
    }

    try {
      final snapshot = await firestore
          .collection('validationResults')
          .where('flaggedForReview', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs;
    } catch (e) {
      print('[Firestore] Warning: Failed to fetch flagged battles: $e');
      return [];
    }
  }

  /// Checks if a player account is currently flagged.
  Future<bool> isPlayerFlagged(String playerId) async {
    final firestore = _getFirestore();
    if (firestore == null) {
      return false;
    }

    try {
      final snapshot = await firestore
          .collection('validationResults')
          .where('playerId', isEqualTo: playerId)
          .where('flaggedForReview', isEqualTo: true)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('[Firestore] Warning: Failed to check player flag status: $e');
      return false;
    }
  }

  /// Gets a single battle log by ID.
  Future<DocumentSnapshot<Map<String, dynamic>>?> getBattleLog(
    String battleId,
  ) async {
    final firestore = _getFirestore();
    if (firestore == null) {
      return null;
    }

    try {
      final doc = await firestore.collection('battles').doc(battleId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      print('[Firestore] Warning: Failed to fetch battle log: $e');
      return null;
    }
  }

  /// Gets validation result for a specific battle.
  Future<DocumentSnapshot<Map<String, dynamic>>?> getValidationResult(
    String battleId,
  ) async {
    final firestore = _getFirestore();
    if (firestore == null) {
      return null;
    }

    try {
      final doc = await firestore
          .collection('validationResults')
          .doc(battleId)
          .get();
      return doc.exists ? doc : null;
    } catch (e) {
      print('[Firestore] Warning: Failed to fetch validation result: $e');
      return null;
    }
  }
}

// ── Type definitions for Firestore storage ─────────────────────────────────

class PetTeamSnapshot {
  final String petId;
  final int hpRemaining;
  final int maxHp;
  final List<String> activeStatusEffects;

  PetTeamSnapshot({
    required this.petId,
    required this.hpRemaining,
    required this.maxHp,
    required this.activeStatusEffects,
  });

  Map<String, dynamic> toJson() => {
        'petId': petId,
        'hpRemaining': hpRemaining,
        'maxHp': maxHp,
        'activeStatusEffects': activeStatusEffects,
      };
}

class BattleValidationResponse {
  final String result; // 'accepted', 'rejected', 'suspicious'
  final bool isAccepted;
  final bool isRejected;
  final bool isSuspicious;
  final int? mmrChange;
  final String? reason;
  final bool flaggedForReview;

  BattleValidationResponse({
    required this.result,
    required this.isAccepted,
    required this.isRejected,
    required this.isSuspicious,
    this.mmrChange,
    this.reason,
    required this.flaggedForReview,
  });
}
