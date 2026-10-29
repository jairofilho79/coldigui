import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'error_reporter.dart';

final _log = AppLogger.of('error-handler');

/// Encaminha erros do Flutter e da plataforma para [reporter].
///
/// Deve ser chamado uma vez em `main()`, antes de `runApp` (idealmente
/// dentro de `runZonedGuarded`, que cobre erros assíncronos fora do
/// framework Flutter).
void installErrorHandlers(ErrorReporter reporter) {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    _log.error('erro do Flutter', details.exception, details.stack);
    reporter.report(details.exception, details.stack, context: 'FlutterError');
    previousOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _log.error('erro nao tratado da plataforma', error, stack);
    reporter.report(error, stack, context: 'PlatformDispatcher');
    return true;
  };
}
