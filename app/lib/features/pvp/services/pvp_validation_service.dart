import 'dart:convert' show jsonEncode, jsonDecode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_client.dart';
import '../models/battle_action_log.dart';

/// API service for PvP validation
/// Submits battle logs to the server for validation and anti-cheat detection
class PvpValidationService {
  static String get baseUrl => '${ApiClient.baseUrl}/api/pvp';
  final http.Client _client;

  PvpValidationService({http.Client? client}) : _client = client ?? http.Client();

  /// Submit a completed battle for validation
  /// Returns validation response or throws on error
  Future<BattleValidationResponse> submitBattleValidation(
    BattleValidationRequest request,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/validate-battle');
      final body = jsonEncode(request.toJson());

      print('[PvP] Submitting battle validation: ${request.playerId}');
      
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ApiClient.cachedToken ?? ''}',
        },
        body: body,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Validation submission timed out after 30 seconds');
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return BattleValidationResponse.fromJson(json);
      } else if (response.statusCode == 400) {
        // Client error - validation rejected
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return BattleValidationResponse.fromJson(json);
      } else if (response.statusCode == 401) {
        throw UnauthorizedException('Not authenticated');
      } else if (response.statusCode == 500) {
        throw ServerException('Server error: ${response.body}');
      } else {
        throw ValidationException('Unexpected status: ${response.statusCode}');
      }
    } catch (e) {
      print('[PvP] Validation submission error: $e');
      rethrow;
    }
  }

  /// Get player's anti-cheat report
  Future<Map<String, dynamic>> getAntiCheatReport(String playerId) async {
    try {
      final url = Uri.parse('$baseUrl/anti-cheat-report');
      
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer ${ApiClient.cachedToken ?? ''}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch anti-cheat report: ${response.statusCode}');
      }
    } catch (e) {
      print('[PvP] Anti-cheat report error: $e');
      rethrow;
    }
  }

  /// Get current player MMR
  Future<int> getPlayerMmr(String playerId) async {
    try {
      final url = Uri.parse('$baseUrl/mmr');
      
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer ${ApiClient.cachedToken ?? ''}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['mmr'] as int? ?? 1000;
      } else {
        throw Exception('Failed to fetch MMR: ${response.statusCode}');
      }
    } catch (e) {
      print('[PvP] MMR fetch error: $e');
      rethrow;
    }
  }

  /// Cleanup HTTP resources
  void close() {
    _client.close();
  }
}

// ── Custom Exceptions ────────────────────────────────────────────────────────

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);

  @override
  String toString() => 'UnauthorizedException: $message';
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);

  @override
  String toString() => 'ServerException: $message';
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

/// Riverpod provider for validation service
final pvpValidationServiceProvider = Provider((ref) {
  final service = PvpValidationService();
  // Cleanup when provider is disposed
  ref.onDispose(service.close);
  return service;
});
