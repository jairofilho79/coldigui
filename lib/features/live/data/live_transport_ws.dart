import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/ports/live_transport.dart';

/// [LiveTransport] sobre `web_socket_channel` — o mesmo código em web, iOS e
/// Android (o pacote escolhe `WebSocket` do browser ou `dart:io`).
class WebSocketLiveTransport implements LiveTransport {
  const WebSocketLiveTransport({
    this.handshakeTimeout = const Duration(seconds: 10),
  });

  final Duration handshakeTimeout;

  @override
  Future<LiveConnection> connect(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    // `ready` rejeita no handshake recusado; o timeout cobre a rede que engole
    // o upgrade sem responder (proxy que bloqueia WS).
    await channel.ready.timeout(handshakeTimeout);
    return _WsConnection(channel);
  }
}

class _WsConnection implements LiveConnection {
  _WsConnection(this._channel) {
    // Assinatura única, com buffer: o `_channel.stream` só é ouvido aqui,
    // uma vez; qualquer frame que chegue antes de alguém assinar `messages`
    // fica retido no `StreamController` até o primeiro (e único) `listen`.
    _sub = _channel.stream.listen(
      (data) => _out.add(data.toString()),
      onError: (_) => _finish(),
      onDone: _finish,
      cancelOnError: false,
    );
  }

  final WebSocketChannel _channel;
  final _out = StreamController<String>();
  late final StreamSubscription<void> _sub;
  final _done = Completer<LiveDisconnect>();
  bool _closed = false;

  void _finish() {
    if (!_done.isCompleted) {
      _done.complete(
        LiveDisconnect(code: _channel.closeCode, reason: _channel.closeReason),
      );
    }
    if (!_out.isClosed) _out.close();
    unawaited(_sub.cancel());
  }

  @override
  Stream<String> get messages => _out.stream;

  @override
  void send(String text) => _channel.sink.add(text);

  @override
  Future<void> close({int code = 1000, String? reason}) async {
    if (_closed || _done.isCompleted) return;
    _closed = true;
    await _channel.sink.close(code, reason);
    _finish();
  }

  @override
  Future<LiveDisconnect> get done => _done.future;
}
