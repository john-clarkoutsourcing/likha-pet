import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_data.dart';

// ── PlayerRepository ──────────────────────────────────────────────────────────
//
// Persists PlayerData to device storage using shared_preferences.
// All data is stored as a single JSON string under _kKey.

class PlayerRepository {
  static const _kKeyPrefix = 'likha_pet_player_data';

  // Suffix changes when a user ID is set, isolating each account's data.
  String _key = _kKeyPrefix;

  /// Switch to a per-user storage key so different accounts don't share data.
  void setUid(String uid) {
    _key = '${_kKeyPrefix}_$uid';
  }

  Future<PlayerData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return PlayerData.fromJsonString(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PlayerData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, data.toJsonString());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
