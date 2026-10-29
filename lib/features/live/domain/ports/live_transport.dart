/// Por que a conexão fechou. [code] `null` = erro sem close frame.
final class LiveDisconnect {
  const LiveDisconnect({this.code, this.reason});
  final int? code;
  final String? reason;
}

/// Uma conexão aberta com a sala.
abstract class LiveConnection {
  /// Mensagens de texto do servidor (JSON dos frames, ou `pong`).
  ///
  /// Stream de assinatura única: aceita **um só** `listen`; frames chegados
  /// antes desse primeiro listener ficam em buffer até ele assinar.
  Stream<String> get messages;

  void send(String text);

  /// Fecha com [code] (1000 = saída limpa). Idempotente.
  Future<void> close({int code = 1000, String? reason});

  /// Completa quando o socket fecha por qualquer motivo (inclusive [close]).
  Future<LiveDisconnect> get done;
}

/// Abre conexões. [connect] **lança** quando o handshake falha — é o que o
/// controller conta para chegar a `unavailable` (spec D5).
abstract class LiveTransport {
  Future<LiveConnection> connect(Uri uri);
}
