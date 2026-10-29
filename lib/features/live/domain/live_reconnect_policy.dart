import 'dart:math';

/// Falhas seguidas de handshake ao **entrar** antes de `unavailable` (D5).
const int kLiveMaxHandshakeFailures = 3;

/// Backoff exponencial 1 → 30 s com jitter de até 1 s — o jitter espalha a
/// reconexão em massa depois de um deploy do Worker (§7).
class LiveReconnectPolicy {
  LiveReconnectPolicy({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const _base = Duration(seconds: 1);
  static const _cap = Duration(seconds: 30);

  Duration delayFor(int attempt) {
    final exponent = attempt.clamp(0, 10);
    final base = _base * (1 << exponent);
    final capped = base > _cap ? _cap : base;
    return capped + Duration(milliseconds: _random.nextInt(1000));
  }
}
