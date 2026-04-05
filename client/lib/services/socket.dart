// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:web_socket/web_socket.dart';

import '../config.dart';
import 'secure_storage.dart';

typedef SocketConnector = Future<WebSocket> Function(Uri uri);
typedef SocketTokenReader = Future<String?> Function();

enum SocketConnectionStatus { disconnected, connecting, connected }

class SocketService {
  SocketService({
    SecureStorage? storage,
    SocketConnector? connector,
    SocketTokenReader? tokenReader,
  }) : _storage = storage ?? SecureStorage(namespace: 'auth'),
       _connector = connector ?? WebSocket.connect,
       _tokenReader = tokenReader;

  static const String namespace = '/platform';

  final SecureStorage _storage;
  final SocketConnector _connector;
  final SocketTokenReader? _tokenReader;

  WebSocket? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController =
      StreamController<SocketConnectionStatus>.broadcast();
  final Map<int, Completer<dynamic>> _ackHandlers = {};
  final Set<String> _joinedRooms = <String>{};

  int _ackCounter = 0;
  bool _isSessionActive = false;
  bool _isDisconnecting = false;
  Completer<void>? _connectCompleter;
  Timer? _reconnectTimer;
  SocketConnectionStatus _connectionStatus =
      SocketConnectionStatus.disconnected;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<SocketConnectionStatus> get connectionStatus =>
      _statusController.stream;
  bool get isConnected => _connectionStatus == SocketConnectionStatus.connected;
  bool get isSessionActive => _isSessionActive;
  SocketConnectionStatus get status => _connectionStatus;

  Future<void> startAuthenticatedSession() async {
    _isSessionActive = true;
    _isDisconnecting = false;
    _cancelReconnectTimer();

    if (isConnected) {
      return;
    }
    if (_connectCompleter != null) {
      return _connectCompleter!.future;
    }

    _connectCompleter = Completer<void>();
    _updateStatus(SocketConnectionStatus.connecting);
    print('Socket authenticated session starting');

    try {
      await _connectInternal();
      await _connectCompleter!.future;
    } finally {
      if (!(_connectCompleter?.isCompleted ?? true)) {
        _connectCompleter?.complete();
      }
      _connectCompleter = null;
    }
  }

  Future<void> endAuthenticatedSession() async {
    print('Socket authenticated session ending');
    _cancelReconnectTimer();
    _isSessionActive = false;
    _isDisconnecting = true;

    final channel = _channel;
    _channel = null;
    _updateStatus(SocketConnectionStatus.disconnected);

    await channel?.close();

    if (!(_connectCompleter?.isCompleted ?? true)) {
      _connectCompleter?.complete();
    }
    _connectCompleter = null;
    _ackHandlers.forEach((id, c) => c.completeError('Socket disconnected'));
    _ackHandlers.clear();
    _joinedRooms.clear();
  }

  Future<void> _connectInternal() async {
    final token = await (_tokenReader?.call() ?? _storage.read('token'));
    if (token == null || token.isEmpty) {
      _isSessionActive = false;
      _updateStatus(SocketConnectionStatus.disconnected);
      return;
    }

    final baseUri = AppConfig.apiUri;
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final uri = Uri(
      scheme: wsScheme,
      host: baseUri.host,
      port: baseUri.port,
      path: '/socket.io/',
      queryParameters: {'EIO': '4', 'transport': 'websocket', 'token': token},
    );

    try {
      print('Socket opening transport connection to ${uri.host}:${uri.port}');
      _channel = await _connector(uri);
      print('Socket transport connection established');

      _channel!.events.listen(
        _handleIncomingData,
        onError: (error) {
          print('Socket Error: $error');
          _onDisconnect();
        },
        onDone: () {
          print('Socket Connection Closed');
          _onDisconnect();
        },
      );
    } catch (e) {
      print('Socket Connection Failed: $e');
      _onDisconnect();
    }
  }

  void _handleIncomingData(WebSocketEvent data) {
    if (data is! TextDataReceived) {
      return;
    }

    final payload = data.text;

    if (payload.startsWith('0')) {
      print('Socket transport handshake received, joining $namespace');
      _sendRaw('40$namespace,');
    } else if (payload.startsWith('44$namespace')) {
      // Namespace connection error — server rejected auth.
      print('Socket namespace connection error: $payload');
      _onDisconnect();
    } else if (payload.startsWith('40$namespace')) {
      _updateStatus(SocketConnectionStatus.connected);
      print('Socket namespace connection established for $namespace');
      if (!(_connectCompleter?.isCompleted ?? true)) {
        _connectCompleter?.complete();
      }
      unawaited(_restoreJoinedRooms());
    } else if (payload.startsWith('2')) {
      _sendRaw('3');
    } else if (payload.startsWith('42$namespace,')) {
      _processEvent(payload.substring('42$namespace,'.length));
    } else if (payload.startsWith('43$namespace,')) {
      _processAck(payload.substring('43$namespace,'.length));
    }
  }

  void _processEvent(String payloadStr) {
    try {
      int? ackId;
      String jsonPart = payloadStr;

      final match = RegExp(r'^(\d+)(.*)$').firstMatch(payloadStr);
      if (match != null) {
        ackId = int.parse(match.group(1)!);
        jsonPart = match.group(2)!;
      }

      final List<dynamic> eventData = jsonDecode(jsonPart);
      final String eventName = eventData[0];
      final dynamic body = eventData[1];
      final normalizedBody = _normalizeEventPayload(body);

      if (!_messageController.isClosed) {
        _messageController.add({
          'event': eventName,
          'data': normalizedBody,
          'raw': body,
        });
      }

      if (ackId != null) {
        _sendRaw('43$namespace,$ackId[{"data":true}]');
      }
    } catch (e) {
      print('Error processing event: $e');
    }
  }

  dynamic _normalizeEventPayload(dynamic body) {
    dynamic current = body;

    while (current is Map && _isStandardSocketEnvelope(current)) {
      current = current['data'];
    }

    if (current is Map<String, dynamic>) {
      return current;
    }

    if (current is Map) {
      return Map<String, dynamic>.from(current);
    }

    return current;
  }

  bool _isStandardSocketEnvelope(Map<dynamic, dynamic> payload) {
    if (!payload.containsKey('data')) {
      return false;
    }

    final allowedKeys = {'data', 'error', 'stack'};
    return payload.keys.every((key) => allowedKeys.contains(key));
  }

  void _processAck(String ackData) {
    try {
      final match = RegExp(r'^(\d+)(.*)$').firstMatch(ackData);
      if (match != null) {
        final ackId = int.parse(match.group(1)!);
        final jsonPart = match.group(2)!;
        final dynamic result = jsonDecode(jsonPart);

        final completer = _ackHandlers.remove(ackId);
        completer?.complete(result);
      }
    } catch (e) {
      print('Error processing ack: $e');
    }
  }

  Future<dynamic> sendMessage(String event, Map<String, dynamic> data) {
    if (!isConnected || _channel == null) {
      return Future.error(StateError('Socket is not connected'));
    }

    final completer = Completer<dynamic>();
    final ackId = _ackCounter++;
    _ackHandlers[ackId] = completer;

    final payload = jsonEncode([event, data]);
    _sendRaw('42$namespace,$ackId$payload');

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _ackHandlers.remove(ackId);
        throw TimeoutException('Socket acknowledgment timed out');
      },
    );
  }

  Future<dynamic> emit(String event, Map<String, dynamic> data) {
    return sendMessage(event, data);
  }

  Future<void> joinRoom(String room) async {
    _joinedRooms.add(room);
    if (!isConnected) {
      return;
    }

    try {
      await emit('join:room', {'room': room});
    } catch (error) {
      print('Socket joinRoom failed for $room: $error');
    }
  }

  Future<void> leaveRoom(String room) async {
    _joinedRooms.remove(room);
    if (!isConnected) {
      return;
    }

    try {
      await emit('leave:room', {'room': room});
    } catch (error) {
      print('Socket leaveRoom failed for $room: $error');
    }
  }

  void _sendRaw(String message) {
    _channel?.sendText(message);
  }

  void _onDisconnect() {
    if (_connectionStatus == SocketConnectionStatus.disconnected &&
        _channel == null &&
        _connectCompleter == null) {
      return;
    }

    print('Socket disconnected. sessionActive=$_isSessionActive');
    _channel = null;
    _updateStatus(SocketConnectionStatus.disconnected);

    if (!(_connectCompleter?.isCompleted ?? true)) {
      _connectCompleter?.complete();
    }
    _connectCompleter = null;
    _ackHandlers.forEach((id, c) => c.completeError('Socket disconnected'));
    _ackHandlers.clear();

    if (_isSessionActive && !_isDisconnecting) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _cancelReconnectTimer();
    print('Socket scheduling reconnect');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isSessionActive || _isDisconnecting) {
        return;
      }
      print('Socket reconnect attempt');
      unawaited(
        startAuthenticatedSession().catchError((error) {
          print('Socket reconnect failed: $error');
        }),
      );
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _updateStatus(SocketConnectionStatus status) {
    if (_connectionStatus == status) {
      return;
    }
    _connectionStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void dispose() {
    _cancelReconnectTimer();
    _isSessionActive = false;
    _isDisconnecting = true;
    _channel?.close();
    _channel = null;
    _updateStatus(SocketConnectionStatus.disconnected);
    _messageController.close();
    _statusController.close();
  }

  Future<void> _restoreJoinedRooms() async {
    if (!isConnected || _joinedRooms.isEmpty) {
      return;
    }

    for (final room in _joinedRooms) {
      try {
        await emit('join:room', {'room': room});
      } catch (error) {
        print('Socket restoreJoinedRooms failed for $room: $error');
      }
    }
  }
}

final socketService = SocketService();
