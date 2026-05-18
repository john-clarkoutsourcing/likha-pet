import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/team_composition.dart';

/// Syncs saved team compositions and the active team to Firestore.
///
/// Mirrors the SharedPreferences-backed PlayerRepository so player data
/// persists across devices.  On web the Firestore client has known JS-interop
/// issues, so the class degrades gracefully on that platform.
class TeamFirestoreRepository {
  FirebaseFirestore? _db;

  FirebaseFirestore? _fs() {
    if (kIsWeb) return null;
    return _db ??= FirebaseFirestore.instance;
  }

  // ── Paths ──────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _teamsCol(String uid) =>
      _fs()!.collection('users').doc(uid).collection('teams');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _fs()!.collection('users').doc(uid);

  // ── Write operations ───────────────────────────────────────────────────────

  /// Upsert a single team composition document.
  Future<void> upsertTeam(String uid, TeamComposition team) async {
    final db = _fs();
    if (db == null) return;
    try {
      await _teamsCol(uid).doc(team.id).set({
        'name':      team.name,
        'petUids':   team.petUids,
        'createdAt': team.createdAt.toIso8601String(),
        'updatedAt': team.updatedAt.toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Non-fatal — local state remains authoritative
      _log('upsertTeam failed: $e');
    }
  }

  /// Remove a team composition document.
  Future<void> deleteTeam(String uid, String teamId) async {
    final db = _fs();
    if (db == null) return;
    try {
      await _teamsCol(uid).doc(teamId).delete();
    } catch (e) {
      _log('deleteTeam failed: $e');
    }
  }

  /// Persist the active team UIDs on the user document.
  Future<void> setActiveTeam(String uid, List<String> petUids) async {
    final db = _fs();
    if (db == null) return;
    try {
      await _userDoc(uid).set({
        'activeTeam':          petUids,
        'activeTeamUpdatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      _log('setActiveTeam failed: $e');
    }
  }

  // ── Read operations ────────────────────────────────────────────────────────

  /// Fetch all saved teams for [uid], ordered newest-first.
  /// Returns an empty list on error or when offline.
  Future<List<TeamComposition>> loadTeams(String uid) async {
    final db = _fs();
    if (db == null) return [];
    try {
      final snap = await _teamsCol(uid)
          .orderBy('updatedAt', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));
      return snap.docs.map((d) {
        final data = d.data();
        return TeamComposition(
          id:        d.id,
          name:      data['name'] as String,
          petUids:   List<String>.from(data['petUids'] as List),
          createdAt: DateTime.parse(data['createdAt'] as String),
          updatedAt: DateTime.parse(data['updatedAt'] as String),
        );
      }).toList();
    } catch (e) {
      _log('loadTeams failed: $e');
      return [];
    }
  }

  /// Fetch the active team UIDs from the user document.
  /// Returns null on error or when the field doesn't exist yet.
  Future<List<String>?> loadActiveTeam(String uid) async {
    final db = _fs();
    if (db == null) return null;
    try {
      final doc = await _userDoc(uid)
          .get(const GetOptions(source: Source.serverAndCache));
      if (!doc.exists) return null;
      final raw = doc.data()?['activeTeam'];
      if (raw == null) return null;
      return List<String>.from(raw as List);
    } catch (e) {
      _log('loadActiveTeam failed: $e');
      return null;
    }
  }

  void _log(String msg) =>
      // ignore: avoid_print
      print('[TeamFirestoreRepository] $msg');
}
