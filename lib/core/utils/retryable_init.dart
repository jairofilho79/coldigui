/// Memoiza um [Future] de inicialização idempotente sem memoizar falha.
///
/// Igual ao padrão comum `_future ??= init()`, mas quando o [Future]
/// resultante rejeita, a memoização é limpa: a próxima chamada tenta [init]
/// de novo em vez de re-aguardar (e relançar) o mesmo erro para sempre.
///
/// Chamadas concorrentes durante a mesma tentativa compartilham o mesmo
/// [Future] (e, portanto, o mesmo resultado/erro) — só a *próxima* chamada,
/// feita depois que a tentativa em curso já terminou, dispara uma nova
/// execução de [init].
class RetryableInit<T> {
  RetryableInit(this._init);

  final Future<T> Function() _init;
  Future<T>? _future;

  /// Retorna o [Future] memoizado, disparando [init] na primeira chamada (ou
  /// de novo após uma falha anterior).
  Future<T> call() => _future ??= _run();

  Future<T> _run() async {
    try {
      return await _init();
    } on Object {
      _future = null;
      rethrow;
    }
  }
}
