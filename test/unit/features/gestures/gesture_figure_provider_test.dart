import 'dart:typed_data';

import 'package:coldigui/features/gestures/data/datasources/gesture_figure_store.dart';
import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/data/repositories/gesture_figure_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositório com resposta roteirizada: `get` devolve o valor de [next] a
/// cada chamada, sem tocar em store nem rede de verdade.
class _FakeRepository extends GestureFigureRepository {
  _FakeRepository(this.next) : super(_NullStore(), Dio(), apiBase: '');

  Uint8List? Function() next;

  @override
  Future<Uint8List?> get(String r2Key) async => next();
}

class _NullStore implements GestureFigureStorePort {
  @override
  Future<Uint8List?> read(String r2Key) async => null;

  @override
  Future<void> write(String r2Key, Uint8List bytes) async {}

  @override
  Future<void> deleteAll() async {}
}

/// Lê segurando uma inscrição (como um widget) e solta no fim; o `pump()`
/// deixa o Riverpod decidir se o elemento sobreviveu (`keepAlive`) ou não.
Future<Uint8List?> _readWhileWatched(ProviderContainer c, String key) async {
  final sub = c.listen(gestureFigureProvider(key), (_, _) {});
  final Uint8List? result;
  try {
    result = await c.read(gestureFigureProvider(key).future);
  } finally {
    sub.close();
  }
  await c.pump();
  return result;
}

void main() {
  test('null (sem sinal) não gruda: próxima leitura tenta de novo', () async {
    var callCount = 0;
    final bytes = Uint8List.fromList([9]);
    final repo = _FakeRepository(() {
      callCount++;
      return callCount == 1 ? null : bytes;
    });
    final container = ProviderContainer(
      overrides: [gestureFigureRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final first = await _readWhileWatched(container, 'k1');
    expect(first, isNull);

    final second = await _readWhileWatched(container, 'k1');
    expect(second, bytes);
  });

  test('bytes não nulos ficam vivos sem novo watcher', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final repo = _FakeRepository(() => bytes);
    final container = ProviderContainer(
      overrides: [gestureFigureRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final first = await _readWhileWatched(container, 'k2');
    expect(first, bytes);

    // Sem `listen`, um `read` isolado só devolve o valor mantido vivo pelo
    // `keepAlive()` do sucesso — sem ele o elemento já teria sido descartado.
    expect(container.read(gestureFigureProvider('k2')).value, bytes);
  });
}
