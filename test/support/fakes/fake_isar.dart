// test/support/fakes/fake_isar.dart
//
// Fake mínima de [Isar] (E10) — implementa só [close] (chamado por
// `isarInitializerProvider`/`isarOpenerProvider` ao descartar o container) e
// delega o resto a `noSuchMethod`, já que nenhum teste que usa esta fake
// chega a acessar coleções de verdade.
import 'package:isar_plus/isar_plus.dart';

class FakeIsar implements Isar {
  var closeCallCount = 0;

  @override
  bool close({bool deleteFromDisk = false}) {
    closeCallCount++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
