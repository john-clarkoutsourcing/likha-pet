import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_data.dart';

// ── PlayerRepository ──────────────────────────────────────────────────────────
//
// Persists PlayerData to device storage using shared_preferences.
// All data is stored as a single JSON string under _kKey.

class PlayerRepository {
  static const _kKey = 'likha_pet_player_data';

  Future<PlayerData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return null;
    try {
      return PlayerData.fromJsonString(raw);
    } catch (_) {
      return null; // corrupt data — start fresh
    }
  }

  Future<void> save(PlayerData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, data.toJsonString());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
