import 'dart:async';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  test(
    'isarInitializerProvider entra em erro em ate 15s quando openAppIsar nunca completa',
    () {
      fakeAsync((async) {
        final container = ProviderContainer(
          overrides: [
            isarOpenerProvider.overrideWithValue(
              () => Completer<Isar>().future,
            ),
          ],
        );
        addTearDown(container.dispose);

        AsyncValue<Isar>? lastValue;
        container.listen<AsyncValue<Isar>>(isarInitializerProvider, (
          previous,
          next,
        ) {
          lastValue = next;
        }, fireImmediately: true);

        // Ainda dentro do timeout: nenhum erro.
        async.elapse(const Duration(seconds: 14));
        expect(lastValue?.hasError, isFalse);

        // Passa dos 15s: deve degradar para erro (TimeoutException).
        async.elapse(const Duration(seconds: 2));
        expect(lastValue?.hasError, isTrue);
        expect(lastValue?.error, isA<TimeoutException>());
      });
    },
  );
}
