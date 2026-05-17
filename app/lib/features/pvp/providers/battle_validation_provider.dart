import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pvp_battle_result.dart';
import '../models/battle_action_log.dart';
import '../services/pvp_validation_service.dart';
import '../services/authenticated_pvp_validation_service.dart';
import '../services/pvp_firestore_service.dart';

/// Represents the state of battle validation
enum BattleValidationState {
  idle,
  validating,
  completed,
  error,
}

/// Holds the validation result for a battle
class BattleValidationData {
  final BattleValidationState state;
  final BattleValidationResponse? response;
  final String? error;

  const BattleValidationData({
    required this.state,
    this.response,
    this.error,
  });

  bool get isValidating => state == BattleValidationState.validating;
  bool get isCompleted => state == BattleValidationState.completed;
  bool get hasError => state == BattleValidationState.error;

  factory BattleValidationData.idle() => const BattleValidationData(
    state: BattleValidationState.idle,
  );

  factory BattleValidationData.validating() => const BattleValidationData(
    state: BattleValidationState.validating,
  );

  factory BattleValidationData.completed(BattleValidationResponse response) =>
      BattleValidationData(
        state: BattleValidationState.completed,
        response: response,
      );

  factory BattleValidationData.error(String error) => BattleValidationData(
    state: BattleValidationState.error,
    error: error,
  );
}

/// Provider for managing battle validation state
final battleValidationProvider =
    StateNotifierProvider<BattleValidationNotifier, BattleValidationData>((ref) {
  final validationService = ref.watch(pvpValidationServiceProvider);
  final firestoreService = ref.watch(pvpFirestoreServiceProvider);
  return BattleValidationNotifier(validationService, firestoreService);
});

/// Notifier for battle validation
class BattleValidationNotifier extends StateNotifier<BattleValidationData> {
  final PvpValidationService _validationService;
  final PvpFirestoreService _firestoreService;

  BattleValidationNotifier(this._validationService, this._firestoreService)
      : super(BattleValidationData.idle());

  /// Submit battle for validation
  Future<void> submitBattle({
    required String battleId,
    required BattleValidationRequest request,
  }) async {
    state = BattleValidationData.validating();

    try {
      final response = await _validationService.submitBattleValidation(request);
      state = BattleValidationData.completed(response);

      // Store validation result in Firestore
      await _firestoreService.storeValidationResult(
        battleId: battleId,
        playerId: request.playerId,
        response: response,
        validationDetails:
            'Result: ${response.result}, Reason: ${response.reason ?? 'none'}',
      );
    } catch (e) {
      state = BattleValidationData.error(e.toString());
    }
  }

  /// Reset validation state
  void reset() {
    state = BattleValidationData.idle();
  }
}

/// Provider to convert validation response to PvpBattleResult
final pvpBattleResultProvider = Provider.family<PvpBattleResult, ({
  String opponentName,
  String? opponentId,
  bool isWin,
  bool isDraw,
  bool isLoss,
})>((ref, args) {
  final validationData = ref.watch(battleValidationProvider);

  // Map validation status to our result type
  final validationStatus = _mapValidationToStatus(validationData);
  final mmrChange = validationData.response?.mmrChange ?? 0;

  return PvpBattleResult(
    isWin: args.isWin,
    isDraw: args.isDraw,
    isLoss: args.isLoss,
    opponentName: args.opponentName,
    opponentId: args.opponentId,
    validationStatus: validationStatus,
    validationReason: validationData.response?.reason,
    flaggedForReview: validationData.response?.flaggedForReview ?? false,
    mmrChange: mmrChange,
    battleDurationMs: 0,
    finalPlayerHp: 0,
    finalOpponentHp: 0,
  );
});

/// Helper to map validation state to ValidationStatus enum
ValidationStatus _mapValidationToStatus(BattleValidationData data) {
  if (data.isValidating) {
    return ValidationStatus.pending;
  }

  if (data.hasError) {
    return ValidationStatus.rejected;
  }

  if (!data.isCompleted || data.response == null) {
    return ValidationStatus.pending;
  }

  final response = data.response!;

  if (response.isRejected) {
    return ValidationStatus.rejected;
  } else if (response.isSuspicious) {
    return ValidationStatus.suspicious;
  } else if (response.isAccepted) {
    return ValidationStatus.accepted;
  }

  return ValidationStatus.pending;
}
