import 'dart:async';

/// Cancelamento de uma busca em curso, sem Dio no domínio.
///
/// Quem dispara a busca cria uma instância e a cancela no `onDispose` do
/// provider; o adaptador de rede escuta [whenCancelled] e traduz para o
/// mecanismo do transporte (`CancelToken` do Dio, no Coldigom). Cancelar é
/// idempotente — chamar duas vezes não lança nem completa duas vezes.
final class SearchCancellation {
  final Completer<void> _completer = Completer<void>();

  /// Cancela a busca; a partir daqui [isCancelled] é `true` e [whenCancelled]
  /// resolve.
  void cancel() {
    if (_completer.isCompleted) return;
    _completer.complete();
  }

  /// `true` depois do primeiro [cancel].
  bool get isCancelled => _completer.isCompleted;

  /// Resolve quando (e só quando) [cancel] é chamado.
  Future<void> get whenCancelled => _completer.future;
}

/// A busca terminou porque foi **cancelada**, não porque falhou.
///
/// Quem chama distingue os dois casos: cancelamento é o fluxo normal de uma
/// tecla nova chegando, e não deve acender a faixa de "indisponível".
final class SearchCancelledException implements Exception {
  const SearchCancelledException([
    this.message = 'busca cancelada antes de terminar',
  ]);

  final String message;

  @override
  String toString() => 'SearchCancelledException: $message';
}
