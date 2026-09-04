import 'package:coldigui/core/logging/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NoopErrorReporter.report nao lanca e nao faz nada observavel', () {
    const reporter = NoopErrorReporter();

    expect(
      () => reporter.report(
        Exception('boom'),
        StackTrace.current,
        context: 'teste',
      ),
      returnsNormally,
    );
  });
}
