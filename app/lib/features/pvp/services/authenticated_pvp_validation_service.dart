import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/battle_action_log.dart';
import 'pvp_validation_service.dart';
import 'pvp_firestore_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Authenticated wrapper for PvP validation service
/// Automatically includes auth token in requests
class AuthenticatedPvpValidationService {
  final PvpValidationService _service;
  final String? _authToken;

  AuthenticatedPvpValidationService({
    required PvpValidationService service,
    required String? authToken,
  })  : _service = service,
        _authToken = authToken;

  /// Submit battle with authentication
  Future<BattleValidationResponse> submitBattleValidation(
    BattleValidationRequest request,
  ) async {
    if (_authToken == null) {
      throw UnauthorizedException('Not authenticated - missing auth token');
    }

    try {
      final response = await _service.submitBattleValidation(request);
      return response;
    } catch (e) {
      if (e is UnauthorizedException) {
        rethrow;
      }
      throw ValidationException('Battle validation failed: $e');
    }
  }

  /// Get anti-cheat report with authentication
  Future<Map<String, dynamic>> getAntiCheatReport(String playerId) async {
    if (_authToken == null) {
      throw UnauthorizedException('Not authenticated');
    }

    return _service.getAntiCheatReport(playerId);
  }

  /// Get player MMR with authentication
  Future<int> getPlayerMmr(String playerId) async {
    if (_authToken == null) {
      throw UnauthorizedException('Not authenticated');
    }

    return _service.getPlayerMmr(playerId);
  }
}

/// Riverpod provider for authenticated validation service
final authenticatedPvpValidationServiceProvider =
    Provider.family<AuthenticatedPvpValidationService, String>((ref, playerId) {
  final baseService = ref.watch(pvpValidationServiceProvider);
  final auth = ref.watch(authProvider.notifier);
  
  return AuthenticatedPvpValidationService(
    service: baseService,
    authToken: auth.token,
  );
});

/// Simple provider that doesn't require playerId
final pvpValidationServiceWithAuthProvider =
    Provider<AuthenticatedPvpValidationService>((ref) {
  final baseService = ref.watch(pvpValidationServiceProvider);
  final auth = ref.watch(authProvider.notifier);
  
  return AuthenticatedPvpValidationService(
    service: baseService,
    authToken: auth.token,
  );
});

/// Riverpod provider for Firestore service (battle history + validation storage)
final pvpFirestoreServiceProvider = Provider<PvpFirestoreService>((ref) {
  return PvpFirestoreService();
});
