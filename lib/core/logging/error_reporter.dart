/// Porta para envio de erros não tratados a um serviço externo.
///
/// Onda 2 só disponibiliza [NoopErrorReporter]; uma implementação real
/// (Sentry, Crashlytics, etc.) fica para uma próxima onda.
abstract class ErrorReporter {
  void report(Object error, StackTrace? stackTrace, {String? context});
}

class NoopErrorReporter implements ErrorReporter {
  const NoopErrorReporter();

  @override
  void report(Object error, StackTrace? stackTrace, {String? context}) {}
}
