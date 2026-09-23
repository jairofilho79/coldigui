import 'dart:convert';

import 'package:coldigui/features/catalog/domain/entities/catalog_filter_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty não filtra; qualquer conjunto não vazio filtra', () {
    expect(CatalogFilterState.empty.isEmpty, isTrue);
    expect(const CatalogFilterState(tags: {'PES'}).isEmpty, isFalse);
    expect(const CatalogFilterState(materialKindIds: {'k1'}).isEmpty, isFalse);
  });

  test('igualdade por conteúdo dos cinco conjuntos', () {
    expect(
      const CatalogFilterState(tonalities: {'Dm', 'G'}),
      const CatalogFilterState(tonalities: {'G', 'Dm'}),
    );
    expect(
      const CatalogFilterState(tonalities: {'Dm'}),
      isNot(const CatalogFilterState(rhythms: {'Dm'})),
    );
  });

  test('getters de URL: CSV ordenado; null quando vazio', () {
    const state = CatalogFilterState(
      tonalities: {'G', 'Dm'},
      tags: {'PES · 9.2026', 'Avulsos'},
      materialKindIds: {'k2', 'k1'},
    );

    expect(state.tonalityUrlValue, 'Dm,G');
    expect(state.tagsUrlValue, 'Avulsos,PES · 9.2026');
    expect(state.materialKindsUrlValue, 'k1,k2');
    expect(state.rhythmUrlValue, isNull);
    expect(state.categoryUrlValue, isNull);
  });

  test('fromUrl/parseCsv aparam espaços e ignoram vazios', () {
    final state = CatalogFilterState.fromUrl(
      tonality: ' Dm , ,G',
      tags: '',
      materialKinds: 'k1',
    );

    expect(state.tonalities, {'Dm', 'G'});
    expect(state.tags, isEmpty);
    expect(state.materialKindIds, {'k1'});
  });

  test('formato gravado v2: ida e volta; formato antigo e lixo → null', () {
    const state = CatalogFilterState(
      tonalities: {'Dm'},
      rhythms: {'Fox'},
      categories: {'Clamor'},
      tags: {'PES'},
      materialKindIds: {'k1'},
    );

    final json = jsonDecode(jsonEncode(state.toPersistedJson()));
    expect(CatalogFilterState.fromPersistedJson(json), state);
    expect(
      CatalogFilterState.fromPersistedJson({
        'materials': ['Partitura'],
        'arranjos': <String>[],
      }),
      isNull,
    );
    expect(CatalogFilterState.fromPersistedJson('x'), isNull);
    expect(CatalogFilterState.fromPersistedJson(null), isNull);
  });
}
