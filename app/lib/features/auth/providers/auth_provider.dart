import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api/api_client.dart';

/// Auth State - represents current authentication status
enum AuthState {
  unauthenticated,  // User not logged in
  authenticating,   // Login/register in progress
  authenticated,    // User logged in
  error,           // Auth error occurred
}

/// Auth Response from server
class AuthResponse {
  final String userId;
  final String token;
  final String email;

  AuthResponse({
    required this.userId,
    required this.token,
    required this.email,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['userId'] as String,
      token: json['token'] as String,
      email: json['email'] as String,
    );
  }
}

/// Auth Notifier - manages auth state
class AuthNotifier extends StateNotifier<AuthState> {
  final FlutterSecureStorage _storage;
  final String _apiBase;

  String? _userId;
  String? _email;
  String? _token;

  AuthNotifier({
    required FlutterSecureStorage storage,
    String apiBase = 'http://localhost:3000/api',
  })  : _storage = storage,
        _apiBase = apiBase,
        super(AuthState.unauthenticated) {
    _initializeFromStorage();
  }

  /// Initialize auth state from secure storage (check if already logged in)
  Future<void> _initializeFromStorage() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        _token = token;
        _userId = await _storage.read(key: 'user_id');
        _email = await _storage.read(key: 'user_email');
        // Set token in API client
        ApiClient.setToken(token);
        state = AuthState.authenticated;
      }
    } catch (e) {
      state = AuthState.unauthenticated;
    }
  }

  /// Register with email and password
  Future<void> register({
    required String email,
    required String password,
  }) async {
    state = AuthState.authenticating;
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = AuthResponse.fromJson(jsonDecode(response.body));
        await _saveAuthData(data);
        state = AuthState.authenticated;
      } else {
        final error = jsonDecode(response.body)['error'] as String;
        _lastError = error;
        state = AuthState.error;
      }
    } catch (e) {
      _lastError = 'Registration failed: ${e.toString()}';
      state = AuthState.error;
    }
  }

  /// Login with email and password
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = AuthState.authenticating;
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = AuthResponse.fromJson(jsonDecode(response.body));
        await _saveAuthData(data);
        state = AuthState.authenticated;
      } else {
        final error = jsonDecode(response.body)['error'] as String;
        _lastError = error;
        state = AuthState.error;
      }
    } catch (e) {
      _lastError = 'Login failed: ${e.toString()}';
      state = AuthState.error;
    }
  }

  /// Logout - clear token and auth state
  Future<void> logout() async {
    try {
      await _storage.delete(key: 'jwt_token');
      await _storage.delete(key: 'user_id');
      await _storage.delete(key: 'user_email');
      _token = null;
      _userId = null;
      _email = null;
      state = AuthState.unauthenticated;
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Save auth data to secure storage
  Future<void> _saveAuthData(AuthResponse auth) async {
    _token = auth.token;
    _userId = auth.userId;
    _email = auth.email;

    // Set token in API client for authenticated requests
    ApiClient.setToken(auth.token);

    await _storage.write(key: 'jwt_token', value: auth.token);
    await _storage.write(key: 'user_id', value: auth.userId);
    await _storage.write(key: 'user_email', value: auth.email);
  }

  // Getters
  String? get userId => _userId;
  String? get email => _email;
  String? get token => _token;

  String? _lastError;
  String? get lastError => _lastError;

  bool get isAuthenticated => state == AuthState.authenticated;
  bool get isAuthenticating => state == AuthState.authenticating;
  bool get hasError => state == AuthState.error;
}

/// Riverpod provider for auth state
final authStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(authStorageProvider);
  return AuthNotifier(storage: storage);
});

/// Get current user ID (if authenticated)
final userIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider.notifier);
  return auth.userId;
});

/// Get current user email (if authenticated)
final userEmailProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider.notifier);
  return auth.email;
});

/// Get JWT token (if authenticated)
final jwtTokenProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider.notifier);
  return auth.token;
});

/// Get last auth error message
final authErrorProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider.notifier);
  return auth.lastError;
});
