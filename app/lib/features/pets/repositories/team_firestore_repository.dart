import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/owned_pet.dart';
import '../models/team_composition.dart';

/// Syncs player data (roster, teams, active team) to Firestore.
/// Disabled on web — Firebase is not initialized on the web platform.
/// Local SharedPreferences remains the authoritative store on web.
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
        'slots':     team.slots.map((s) => s.toJson()).toList(),
        'createdAt': team.createdAt.toIso8601String(),
        'updatedAt': team.updatedAt.toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      _log('upsertTeam failed: $e');
    }
  }

  /// Persist the full pet roster on the user document.
  Future<void> saveRoster(String uid, List<OwnedPet> roster) async {
    final db = _fs();
    if (db == null) return;
    try {
      await _userDoc(uid).set({
        'roster':          roster.map((p) => p.toJson()).toList(),
        'rosterUpdatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      _log('saveRoster failed: $e');
    }
  }

  /// Load the pet roster from the user document.
  /// Returns null if not found or on error (caller falls back to local).
  Future<List<OwnedPet>?> loadRoster(String uid) async {
    final db = _fs();
    if (db == null) return null;
    try {
      final doc = await _userDoc(uid)
          .get(const GetOptions(source: Source.serverAndCache));
      if (!doc.exists) return null;
      final raw = doc.data()?['roster'];
      if (raw == null) return null;
      return (raw as List)
          .map((e) => OwnedPet.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('loadRoster failed: $e');
      return null;
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
        return TeamComposition.fromJson({
          ...data,
          'id': d.id,
        });
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
