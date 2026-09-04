import 'dart:async';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

/// Fake mínimo de [Isar] — implementa só [close] (o único membro que
/// [isarInitializerProvider] chama na instância resolvida); os demais
/// membros abstratos são encaminhados a [noSuchMethod] porque o teste nunca
/// os invoca (evita reimplementar toda a API de leitura/escrita do Isar).
class _FakeIsar implements Isar {
  int closeCallCount = 0;

  @override
  bool close({bool deleteFromDisk = false}) {
    closeCallCount++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  test(
    'instancia que so abre depois do timeout e fechada exatamente uma vez',
    () {
      fakeAsync((async) {
        final lateIsar = _FakeIsar();
        final openerCompleter = Completer<Isar>();
        Timer(
          const Duration(seconds: 20),
          () => openerCompleter.complete(lateIsar),
        );

        final container = ProviderContainer(
          overrides: [
            isarOpenerProvider.overrideWithValue(() => openerCompleter.future),
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

        // Aos 15s o provider ja degradou; a instancia tardia ainda nao chegou.
        async.elapse(const Duration(seconds: 15));
        expect(lastValue?.hasError, isTrue);
        expect(lastValue?.error, isA<TimeoutException>());
        expect(lateIsar.closeCallCount, 0);

        // Aos 20s o opener finalmente resolve: a instancia tardia deve ser
        // fechada (ninguem mais vai le-la, ja que o provider errou).
        async.elapse(const Duration(seconds: 5));
        expect(lateIsar.closeCallCount, 1);
      });
    },
  );

  test(
    'instancia aberta antes do timeout so e fechada no dispose, nao antes',
    () {
      fakeAsync((async) {
        final isar = _FakeIsar();
        final openerCompleter = Completer<Isar>();
        Timer(const Duration(seconds: 2), () => openerCompleter.complete(isar));

        final container = ProviderContainer(
          overrides: [
            isarOpenerProvider.overrideWithValue(() => openerCompleter.future),
          ],
        );

        AsyncValue<Isar>? lastValue;
        container.listen<AsyncValue<Isar>>(isarInitializerProvider, (
          previous,
          next,
        ) {
          lastValue = next;
        }, fireImmediately: true);

        async.elapse(const Duration(seconds: 2));
        expect(lastValue?.asData?.value, same(isar));
        expect(isar.closeCallCount, 0);

        container.dispose();
        expect(isar.closeCallCount, 1);
      });
    },
  );
}
