import 'package:coldigui/core/utils/retryable_init.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetryableInit', () {
    test('memoiza sucesso — chamadas subsequentes não reexecutam init', () async {
      var calls = 0;
      final init = RetryableInit<int>(() async {
        calls++;
        return 42;
      });

      expect(await init(), 42);
      expect(await init(), 42);
      expect(calls, 1);
    });

    test('primeira init falha, segunda chamada tenta de novo', () async {
      var calls = 0;
      final init = RetryableInit<void>(() async {
        calls++;
        if (calls == 1) {
          throw StateError('boom');
        }
      });

      await expectLater(init(), throwsStateError);
      expect(calls, 1);

      // Segunda chamada não deve reusar o Future rejeitado: deve tentar de novo.
      await init();
      expect(calls, 2);
    });

    test('duas chamadas concorrentes durante a mesma falha veem o mesmo erro', () async {
      var calls = 0;
      final init = RetryableInit<void>(() async {
        calls++;
        throw StateError('boom-$calls');
      });

      final first = init();
      final second = init();

      await expectLater(first, throwsStateError);
      await expectLater(second, throwsStateError);
      expect(calls, 1);
    });
  });
}
