@TestOn('browser')
library;

import 'package:coldigui/core/platform/web_storage_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

/// `navigator.storage.persist()` existe no Chrome do harness; conceder ou não
/// depende do perfil, mas o resultado nunca é `null` nem a chamada lança.
void main() {
  test('resolve com bool no Chrome', () async {
    expect(await requestPersistentStorage(), isNotNull);
  });

  test('uma chamada por sessão: o Future é reutilizado', () {
    expect(
      identical(requestPersistentStorage(), requestPersistentStorage()),
      isTrue,
    );
  });
}
