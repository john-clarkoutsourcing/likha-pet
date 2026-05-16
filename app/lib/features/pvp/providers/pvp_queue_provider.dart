import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pvp_message.dart';
import '../services/pvp_socket.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pets/models/owned_pet.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum QueuePhase { idle, connecting, queuing, matched }

class PvpQueueState {
  final QueuePhase phase;
  final int position;
  final int mmr;
  final PvpMatchFound? matchFound;
  final String? error;

  const PvpQueueState({
    this.phase = QueuePhase.idle,
    this.position = 0,
    this.mmr = 1000,
    this.matchFound,
    this.error,
  });

  PvpQueueState copyWith({
    QueuePhase? phase,
    int? position,
    int? mmr,
    PvpMatchFound? matchFound,
    String? error,
  }) =>
      PvpQueueState(
        phase: phase ?? this.phase,
        position: position ?? this.position,
        mmr: mmr ?? this.mmr,
        matchFound: matchFound ?? this.matchFound,
        error: error ?? this.error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PvpQueueNotifier extends StateNotifier<PvpQueueState> {
  PvpQueueNotifier(this._ref) : super(const PvpQueueState());

  final Ref _ref;
  StreamSubscription<PvpMessage>? _sub;

  Future<void> joinQueue(List<OwnedPet> team) async {
    state = state.copyWith(phase: QueuePhase.connecting, error: null);

    final jwt = _ref.read(jwtTokenProvider);
    if (jwt == null) {
      state = state.copyWith(phase: QueuePhase.idle, error: 'Not authenticated');
      return;
    }

    connectPvpSocket();
    _sub?.cancel();
    _sub = PvpSocket.instance.messages.listen(_onMessage);

    final teamRefs = team.map((p) => PetDnaRef(uid: p.uid, dna: p.dna)).toList();
    PvpSocket.instance.send(OutQueueJoin(team: teamRefs).toJson());
    state = state.copyWith(phase: QueuePhase.queuing);
  }

  void leaveQueue() {
    PvpSocket.instance.send(const OutQueueLeave().toJson());
    _cleanup();
    state = const PvpQueueState();
  }

  void clearMatch() {
    state = state.copyWith(phase: QueuePhase.idle, matchFound: null);
  }

  void _onMessage(PvpMessage msg) {
    if (msg is PvpQueueStatus) {
      state = state.copyWith(
        position: msg.position,
        mmr: msg.mmr,
        phase: QueuePhase.queuing,
      );
    } else if (msg is PvpMatchFound) {
      state = state.copyWith(phase: QueuePhase.matched, matchFound: msg);
    } else if (msg is PvpError) {
      state = state.copyWith(phase: QueuePhase.idle, error: msg.message);
    }
  }

  void _cleanup() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

final pvpQueueProvider =
    StateNotifierProvider<PvpQueueNotifier, PvpQueueState>((ref) {
  return PvpQueueNotifier(ref);
});
