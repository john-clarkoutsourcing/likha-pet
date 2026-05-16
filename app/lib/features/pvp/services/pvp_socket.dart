import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/pvp_message.dart';
import '../../../core/api/api_client.dart';

class PvpSocket {
  PvpSocket._();
  static final PvpSocket instance = PvpSocket._();

  static const _wsBase = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:3000/pvp',
  );

  WebSocketChannel? _channel;
  final _controller = StreamController<PvpMessage>.broadcast();
  bool _disposed = false;
  Timer? _reconnectTimer;
  int _reconnectDelayMs = 1000;
  String? _resumeMatchId;

  // Messages queued while the socket is still connecting.
  final List<Map<String, dynamic>> _pendingQueue = [];
  bool _connected = false;

  Stream<PvpMessage> get messages => _controller.stream;
  bool get isConnected => _connected;

  void connect(String jwt, {String? resumeMatchId}) {
    _resumeMatchId = resumeMatchId;
    _reconnectDelayMs = 1000;
    _disposed = false;
    _connect(jwt);
  }

  /// Send a message. If the socket isn't open yet, buffers it until ready.
  void send(Map<String, dynamic> msg) {
    if (_connected && _channel != null) {
      _channel!.sink.add(jsonEncode(msg));
    } else {
      _pendingQueue.add(msg);
    }
  }

  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _pendingQueue.clear();
  }

  void _connect(String jwt) {
    _channel?.sink.close();
    _connected = false;

    final uri = Uri.parse('$_wsBase?token=${Uri.encodeComponent(jwt)}');
    _channel = WebSocketChannel.connect(uri);

    // ready() resolves when the WS handshake completes (first message or ready event).
    // web_socket_channel signals readiness via the `ready` future on supported platforms.
    _channel!.ready.then((_) {
      _connected = true;
      _flushPending();
      if (_resumeMatchId != null) {
        send(OutMatchResume(matchId: _resumeMatchId!).toJson());
      }
    }).catchError((_) {
      // Connection failed — reconnect will handle it.
    });

    _channel!.stream.listen(
      (raw) {
        if (!_connected) {
          // Treat first message as confirmation of open (fallback for platforms
          // where ready future doesn't fire).
          _connected = true;
          _flushPending();
        }
        _reconnectDelayMs = 1000;
        final msg = PvpMessage.tryParse(raw.toString());
        if (msg != null) _controller.add(msg);
      },
      onError: (_) {
        _connected = false;
        _scheduleReconnect(jwt);
      },
      onDone: () {
        _connected = false;
        if (!_disposed) _scheduleReconnect(jwt);
      },
    );
  }

  void _flushPending() {
    final copy = List<Map<String, dynamic>>.from(_pendingQueue);
    _pendingQueue.clear();
    for (final msg in copy) {
      _channel?.sink.add(jsonEncode(msg));
    }
  }

  void _scheduleReconnect(String jwt) {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: _reconnectDelayMs), () {
      _reconnectDelayMs = (_reconnectDelayMs * 2).clamp(1000, 30000);
      _connect(jwt);
    });
  }
}

PvpSocket connectPvpSocket({String? resumeMatchId}) {
  final jwt = ApiClient.cachedToken ?? '';
  PvpSocket.instance.connect(jwt, resumeMatchId: resumeMatchId);
  return PvpSocket.instance;
}
