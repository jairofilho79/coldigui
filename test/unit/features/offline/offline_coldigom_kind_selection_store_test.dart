import 'package:coldigui/features/offline/data/datasources/offline_coldigom_kind_selection_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sem decisão: hasDecision false e leitura vazia; write persiste e marca decisão', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OfflineColdigomKindSelectionStore(
      await SharedPreferences.getInstance(),
    );

    expect(store.hasDecision, isFalse);
    expect(store.read(), isEmpty);

    await store.write({'k2', 'k1'});
    expect(store.hasDecision, isTrue);
    expect(store.read(), {'k1', 'k2'});

    await store.write({});
    expect(store.hasDecision, isTrue);
    expect(store.read(), isEmpty);
  });
}
