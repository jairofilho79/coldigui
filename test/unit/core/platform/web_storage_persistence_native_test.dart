import 'package:coldigui/core/platform/web_storage_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

/// No VM o conditional import resolve para o stub nativo: o SO não apaga o
/// storage do app por inatividade, logo não há nada a pedir.
void main() {
  test('nativo devolve null sem lançar', () async {
    expect(await requestPersistentStorage(), isNull);
  });
}
