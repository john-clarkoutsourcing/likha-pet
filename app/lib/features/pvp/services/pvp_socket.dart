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
  bool _authRejected = false;

  // Messages queued while the socket is still connecting.
  final List<Map<String, dynamic>> _pendingQueue = [];
  bool _connected = false;

  Stream<PvpMessage> get messages => _controller.stream;
  bool get isConnected => _connected;

  void connect(String jwt, {String? resumeMatchId}) {
    _resumeMatchId = resumeMatchId;
    _reconnectDelayMs = 1000;
    _disposed = false;
    _authRejected = false;
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
    }).catchError((e) {
      if (_looksLikeAuthError(e)) {
        _authRejected = true;
        _controller.add(const PvpError(
          code: 'WS_AUTH',
          message: 'Arena session invalid or expired. Please log in again.',
        ));
      }
      // Connection failed — reconnect/onDone handlers will manage retries.
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
      onError: (e) {
        _connected = false;
        if (_looksLikeAuthError(e)) {
          _authRejected = true;
          _controller.add(const PvpError(
            code: 'WS_AUTH',
            message: 'Arena session invalid or expired. Please log in again.',
          ));
          return;
        }
        _controller.add(PvpError(
          code: 'WS_ERROR',
          message: 'WebSocket error: $e',
        ));
        _scheduleReconnect(jwt);
      },
      onDone: () {
        _connected = false;
        if (_authRejected) return;
        _controller.add(const PvpError(
          code: 'WS_CLOSED',
          message: 'Connection lost. Reconnecting to Arena...',
        ));
        if (!_disposed) _scheduleReconnect(jwt);
      },
    );
  }

  bool _looksLikeAuthError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('401') ||
        msg.contains('unauthorized') ||
        msg.contains('forbidden') ||
        msg.contains('jwt');
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

PvpSocket connectPvpSocket({String? jwt, String? resumeMatchId}) {
  final token = jwt ?? ApiClient.cachedToken ?? '';
  if (token.isEmpty) {
    // Let caller surface auth UX; keep helper non-throwing.
    return PvpSocket.instance;
  }
  PvpSocket.instance.connect(token, resumeMatchId: resumeMatchId);
  return PvpSocket.instance;
}
