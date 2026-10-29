import 'dart:io';

import 'package:coldigui/features/live/data/live_transport_ws.dart';
import 'package:coldigui/features/live/domain/ports/live_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('messages é assinatura única e bufferiza frames anteriores ao listen; '
      'close é idempotente', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      socket.add('frame1');
      socket.add('frame2');
    });
    addTearDown(server.close);

    final uri = Uri.parse('ws://${server.address.address}:${server.port}');
    final connection = await const WebSocketLiveTransport().connect(uri);
    addTearDown(connection.close);

    // Dá tempo do servidor mandar os dois frames e do listener interno da
    // conexão bufferizá-los antes do teste assinar `messages`.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final received = <String>[];
    final sub = connection.messages.listen(received.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await sub.cancel();

    expect(received, ['frame1', 'frame2']);

    await connection.close();
    await connection.close(); // idempotente: não lança, não reabre `done`.

    final disconnect = await connection.done;
    expect(disconnect, isA<LiveDisconnect>());
  });
}
