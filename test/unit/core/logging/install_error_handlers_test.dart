import 'package:coldigui/core/logging/error_reporter.dart';
import 'package:coldigui/core/logging/install_error_handlers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeErrorReporter implements ErrorReporter {
  final List<Object> reportedErrors = <Object>[];
  final List<String?> reportedContexts = <String?>[];

  @override
  void report(Object error, StackTrace? stackTrace, {String? context}) {
    reportedErrors.add(error);
    reportedContexts.add(context);
  }
}

void main() {
  test(
    'installErrorHandlers encaminha FlutterError.reportError para o reporter',
    () {
      final reporter = _FakeErrorReporter();
      final previousOnError = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previousOnError);

      installErrorHandlers(reporter);

      final exception = Exception('falha de teste');
      FlutterError.reportError(
        FlutterErrorDetails(exception: exception, stack: StackTrace.current),
      );

      expect(reporter.reportedErrors, hasLength(1));
      expect(reporter.reportedErrors.single, exception);
      expect(reporter.reportedContexts.single, 'FlutterError');
    },
  );
}
