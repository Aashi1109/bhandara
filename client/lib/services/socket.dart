// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:web_socket/web_socket.dart';
import 'api.dart';
import 'secure_storage.dart';

class SocketService {
  WebSocket? _channel;
  final _storage = SecureStorage(namespace: 'auth');

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  final Map<int, Completer<dynamic>> _ackHandlers = {};
  int _ackCounter = 0;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  static const String namespace = '/platform';

  Future<void> connect(String eventId) async {
    if (_isConnected) return;

    final token = await _storage.read('token');

    // Engine.IO 4 connection URL
    final baseUrl = ApiService.baseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse(
      '$baseUrl/socket.io/?EIO=4&transport=websocket&token=$token',
    );

    try {
      _channel = await WebSocket.connect(uri);

      _channel!.events.listen(
        _handleIncomingData,
        onError: (error) {
          print('Socket Error: $error');
          _onDisconnect(eventId);
        },
        onDone: () {
          print('Socket Connection Closed');
          _onDisconnect(eventId);
        },
      );
    } catch (e) {
      print('Socket Connection Failed: $e');
      _onDisconnect(eventId);
    }
  }

  void _handleIncomingData(WebSocketEvent data) {
    if (data is! TextDataReceived) return;

    final payload = data.text;

    // Engine.IO Packet Types:
    // 0: OPEN (Handshake)
    // 1: CLOSE
    // 2: PING
    // 3: PONG
    // 4: MESSAGE

    if (payload.startsWith('0')) {
      // Handshake received, now join namespace
      _sendRaw('40$namespace,');
      _isConnected = true;
    } else if (payload.startsWith('2')) {
      // Received PING, send PONG
      _sendRaw('3');
    } else if (payload.startsWith('42$namespace,')) {
      // Received a MESSAGE on our namespace
      final payloadStr = payload.substring('42$namespace,'.length);
      _processEvent(payloadStr);
    } else if (payload.startsWith('43$namespace,')) {
      // Received an ACKNOWLEDGMENT
      final ackData = payload.substring('43$namespace,'.length);
      _processAck(ackData);
    }
  }

  void _processEvent(String payloadStr) {
    try {
      // Payload format: [<ackId>]["event", data]
      // For simple messages without ackId: ["event", data]

      int? ackId;
      String jsonPart = payloadStr;

      // Check if it starts with a digit (ackId)
      final match = RegExp(r'^(\d+)(.*)$').firstMatch(payloadStr);
      if (match != null) {
        ackId = int.parse(match.group(1)!);
        jsonPart = match.group(2)!;
      }

      final List<dynamic> eventData = jsonDecode(jsonPart);
      final String eventName = eventData[0];
      final dynamic body = eventData[1];

      // Broadcast to message stream
      _messageController.add({'event': eventName, 'data': body});

      // If server requested an ack (not common for broadcasts but possible)
      if (ackId != null) {
        _sendRaw('43$namespace,$ackId[{"data":true}]');
      }
    } catch (e) {
      print('Error processing event: $e');
    }
  }

  void _processAck(String ackData) {
    try {
      // Format: <ackId>[data]
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
    final completer = Completer<dynamic>();
    final ackId = _ackCounter++;
    _ackHandlers[ackId] = completer;

    // Socket.IO Emit with Ack format: 42/namespace,<ackId>["event", data]
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

  void _sendRaw(String message) {
    if (_channel != null && _isConnected) {
      _channel!.sendText(message);
    }
  }

  void _onDisconnect(String eventId) {
    _isConnected = false;
    _ackHandlers.forEach((id, c) => c.completeError('Socket disconnected'));
    _ackHandlers.clear();

    // Auto-reconnect
    Future.delayed(const Duration(seconds: 5), () => connect(eventId));
  }

  void disconnect() {
    _channel?.close();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}

final socketService = SocketService();
