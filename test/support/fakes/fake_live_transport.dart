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

  /// O servidor falou. Sem efeito depois de fechada — como um socket real,
  /// que não entrega mais nada ao stream local uma vez fechado; é o cliente
  /// (via geração) que decide, não este `emit`, quando um frame é "tardio".
  void emit(String text) {
    if (_controller.isClosed) return;
    _controller.add(text);
  }

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
  Completer<void>? _gate;

  /// As próximas [n] tentativas de `connect` lançam (handshake recusado).
  void failNext(int n) => _failNext = n;

  /// A **próxima** chamada a `connect` fica pendurada até o teste completar
  /// o `Completer` devolvido — simula um handshake em voo (ex.: `leave()`
  /// chamado no meio de um `join`).
  Completer<void> holdNext() {
    final gate = Completer<void>();
    _gate = gate;
    return gate;
  }

  FakeLiveConnection get last => connections.last;

  @override
  Future<LiveConnection> connect(Uri uri) async {
    attempts++;
    final gate = _gate;
    if (gate != null) {
      _gate = null;
      await gate.future;
    }
    if (_failNext > 0) {
      _failNext--;
      throw StateError('handshake recusado');
    }
    final connection = FakeLiveConnection(uri);
    connections.add(connection);
    return connection;
  }
}
