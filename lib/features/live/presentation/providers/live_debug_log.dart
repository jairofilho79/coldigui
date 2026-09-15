/// Diagnóstico da Lista ao Vivo **ligável em produção**: abrir o app com
/// `?livedbg=1` na URL faz o [LiveSessionController] escrever no console
/// (`[live] …`) cada mudança de foco local, cada `set` agendado/enviado e
/// cada frame recebido — com timestamp, chaves/ids encurtados e sem token.
///
/// Existe porque `AppLogger` cala em release e o bug de campo «consumidor um
/// louvor atrás» só aparece na máquina do usuário. Custo zero desligado.
library;

final bool liveDebugEnabled = _detect();

bool _detect() {
  try {
    return Uri.base.queryParameters.containsKey('livedbg');
  } on Object {
    return false;
  }
}

final _startedAt = DateTime.now();

/// Escreve `[live] +<ms> <msg>` no console quando ligado.
void liveDebug(String Function() message) {
  if (!liveDebugEnabled) return;
  final ms = DateTime.now().difference(_startedAt).inMilliseconds;
  // ignore: avoid_print — é o propósito deste arquivo.
  print('[live] +${ms}ms ${message()}');
}

/// Fim de um id/chave (os ids Coldigom são base64 longos e só o fim varia).
String liveShort(String? value) {
  if (value == null) return '-';
  return value.length <= 12 ? value : '…${value.substring(value.length - 12)}';
}
