import 'dart:async';

import 'package:coldigui/core/database/isar_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

/// Fake mínimo de [Isar] — só [close] é chamado por [isarInitializerProvider].
class _FakeIsar implements Isar {
  @override
  bool close({bool deleteFromDisk = false}) => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ProviderContainer containerWith(Future<Isar> Function() opener) {
    final container = ProviderContainer(
      overrides: [isarOpenerProvider.overrideWithValue(opener)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('opening enquanto o Isar ainda está abrindo', () async {
    final completer = Completer<Isar>();
    final container = containerWith(() => completer.future);

    container.listen(isarInitializerProvider, (_, _) {}, fireImmediately: true);

    expect(container.read(isarStatusProvider), IsarStatus.opening);
    expect(
      container.read(isarAvailableProvider),
      isFalse,
      reason: 'abrindo ainda não é disponível',
    );

    completer.complete(_FakeIsar());
    await container.read(isarInitializerProvider.future);
  });

  test('available quando o Isar abre', () async {
    final container = containerWith(() async => _FakeIsar());

    await container.read(isarInitializerProvider.future);

    expect(container.read(isarStatusProvider), IsarStatus.available);
    expect(container.read(isarAvailableProvider), isTrue);
  });

  test('unavailable quando a abertura falha', () async {
    final container = containerWith(
      () async => throw StateError('OPFS travado'),
    );

    await expectLater(
      container.read(isarInitializerProvider.future),
      throwsA(isA<StateError>()),
    );

    expect(container.read(isarStatusProvider), IsarStatus.unavailable);
    expect(container.read(isarAvailableProvider), isFalse);
  });
}
