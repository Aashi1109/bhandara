import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/services/socket.dart';
import 'package:web_socket/web_socket.dart';

void main() {
  group('SocketService', () {
    test(
      'starts the authenticated session once and becomes connected',
      () async {
        final socket = FakeWebSocket();
        var connectCount = 0;
        final service = SocketService(
          tokenReader: () async => 'session-token',
          connector: (uri) async {
            connectCount++;
            unawaited(
              Future<void>.delayed(const Duration(milliseconds: 1), () {
                socket.add(TextDataReceived('0{"sid":"abc"}'));
                socket.add(TextDataReceived('40/platform'));
              }),
            );
            return socket;
          },
        );

        await service.startAuthenticatedSession();
        await service.startAuthenticatedSession();

        expect(connectCount, 1);
        expect(service.isSessionActive, isTrue);
        expect(service.isConnected, isTrue);
        expect(service.status, SocketConnectionStatus.connected);

        await service.endAuthenticatedSession();
        service.dispose();
      },
    );

    test(
      'forwards flat socket namespace messages to the event stream',
      () async {
        final socket = FakeWebSocket();
        final service = SocketService(
          tokenReader: () async => 'session-token',
          connector: (uri) async {
            unawaited(
              Future<void>.delayed(const Duration(milliseconds: 1), () {
                socket.add(TextDataReceived('0{"sid":"abc"}'));
                socket.add(TextDataReceived('40/platform'));
                socket.add(
                  TextDataReceived(
                    '42/platform,["message:create",{"id":"message-1"}]',
                  ),
                );
              }),
            );
            return socket;
          },
        );

        final eventFuture = service.messages.first;
        await service.startAuthenticatedSession();

        final event = await eventFuture;
        expect(event['event'], 'message:create');
        expect(event['data'], {'id': 'message-1'});
        expect(event['raw'], {'id': 'message-1'});

        await service.endAuthenticatedSession();
        service.dispose();
      },
    );

    test(
      'unwraps the standard server data envelope before listeners parse models',
      () async {
        final socket = FakeWebSocket();
        final service = SocketService(
          tokenReader: () async => 'session-token',
          connector: (uri) async {
            unawaited(
              Future<void>.delayed(const Duration(milliseconds: 1), () {
                socket.add(TextDataReceived('0{"sid":"abc"}'));
                socket.add(TextDataReceived('40/platform'));
                socket.add(
                  TextDataReceived(
                    '42/platform,["event:update",{"data":{"id":"event-1","name":"Street Lunch"}}]',
                  ),
                );
              }),
            );
            return socket;
          },
        );

        final eventFuture = service.messages.first;
        await service.startAuthenticatedSession();

        final event = await eventFuture;
        expect(event['event'], 'event:update');
        expect(event['data'], {'id': 'event-1', 'name': 'Street Lunch'});
        expect(event['raw'], {
          'data': {'id': 'event-1', 'name': 'Street Lunch'},
        });

        await service.endAuthenticatedSession();
        service.dispose();
      },
    );

    test(
      'ends the authenticated session and blocks emits while disconnected',
      () async {
        final socket = FakeWebSocket();
        final service = SocketService(
          tokenReader: () async => 'session-token',
          connector: (uri) async {
            unawaited(
              Future<void>.delayed(const Duration(milliseconds: 1), () {
                socket.add(TextDataReceived('0{"sid":"abc"}'));
                socket.add(TextDataReceived('40/platform'));
              }),
            );
            return socket;
          },
        );

        await service.startAuthenticatedSession();
        await service.endAuthenticatedSession();

        expect(service.isSessionActive, isFalse);
        expect(service.isConnected, isFalse);
        await expectLater(
          service.emit('reaction:create', {'id': '1'}),
          throwsA(isA<StateError>()),
        );

        service.dispose();
      },
    );
  });
}

class FakeWebSocket implements WebSocket {
  final StreamController<WebSocketEvent> _controller =
      StreamController<WebSocketEvent>.broadcast();

  final List<String> sentTexts = [];
  bool isClosed = false;

  void add(WebSocketEvent event) {
    if (!isClosed) {
      _controller.add(event);
    }
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    isClosed = true;
    await _controller.close();
  }

  @override
  Stream<WebSocketEvent> get events => _controller.stream;

  @override
  String get protocol => '';

  @override
  void sendBytes(Uint8List b) {}

  @override
  void sendText(String s) {
    sentTexts.add(s);
  }
}
