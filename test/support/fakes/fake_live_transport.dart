import 'dart:async';

import 'package:coldigui/features/live/domain/ports/live_transport.dart';

/// Conexão de mentira: o teste **emite** frames do "servidor" e lê o que o
/// controller mandou.
class FakeLiveConnection implements LiveConnection {
  FakeLiveConnection(this.uri);

  final Uri uri;
  final _controller = StreamController<String>.broadcast();
  final _done = Completer<LiveDisconnect>();
  final List<String> sent = [];
  int? closedWith;

  @override
  Stream<String> get messages => _controller.stream;

  @override
  void send(String text) => sent.add(text);

  @override
  Future<void> close({int code = 1000, String? reason}) async {
    if (closedWith != null) return;
    closedWith = code;
    await _controller.close();
    if (!_done.isCompleted) _done.complete(LiveDisconnect(code: code));
  }

  @override
  Future<LiveDisconnect> get done => _done.future;

  /// O servidor falou.
  void emit(String text) => _controller.add(text);

  /// A rede caiu (ou o servidor fechou com [code]) — sem `close()` do cliente.
  Future<void> drop({int code = 1006}) async {
    if (closedWith != null) return;
    closedWith = code;
    await _controller.close();
    if (!_done.isCompleted) _done.complete(LiveDisconnect(code: code));
  }

  bool get isOpen => closedWith == null;
}

class FakeLiveTransport implements LiveTransport {
  final List<FakeLiveConnection> connections = [];
  int _failNext = 0;
  int attempts = 0;

  /// As próximas [n] tentativas de `connect` lançam (handshake recusado).
  void failNext(int n) => _failNext = n;

  FakeLiveConnection get last => connections.last;

  @override
  Future<LiveConnection> connect(Uri uri) async {
    attempts++;
    if (_failNext > 0) {
      _failNext--;
      throw StateError('handshake recusado');
    }
    final connection = FakeLiveConnection(uri);
    connections.add(connection);
    return connection;
  }
}
