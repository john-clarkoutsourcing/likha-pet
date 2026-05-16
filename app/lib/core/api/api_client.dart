import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiResponse<T> {
  final int statusCode;
  final T body;

  ApiResponse({
    required this.statusCode,
    required this.body,
  });
}

/// API Client for making authenticated requests to the server
class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://localhost:3000',
  );
  static String? _cachedToken;

  static String? get cachedToken => _cachedToken;

  /// Set the JWT token (called from auth provider)
  static void setToken(String token) {
    _cachedToken = token;
  }

  /// Get request with Bearer token authentication
  static Future<ApiResponse<dynamic>> getWithAuth(String endpoint) async {
    try {
      final token = _cachedToken ?? 'test-token';

      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // Parse response body
      final body = _parseResponse(response.body);

      return ApiResponse(
        statusCode: response.statusCode,
        body: body,
      );
    } catch (e) {
      throw Exception('Failed to make request: $e');
    }
  }

  /// Post request with Bearer token authentication
  static Future<ApiResponse<dynamic>> postWithAuth(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final token = _cachedToken ?? 'test-token';

      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body.isEmpty ? '{}' : jsonEncode(body),
      );

      // Parse response body
      final responseBody = _parseResponse(response.body);

      return ApiResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } catch (e) {
      throw Exception('Failed to make request: $e');
    }
  }

  /// Parse response body
  static dynamic _parseResponse(String body) {
    try {
      if (body.isEmpty) return null;

      // Try parsing as JSON
      if (body.startsWith('[')) {
        return jsonDecode(body);
      } else if (body.startsWith('{')) {
        return jsonDecode(body);
      } else {
        return body;
      }
    } catch (e) {
      return body;
    }
  }
}
