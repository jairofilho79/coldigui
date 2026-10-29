import 'dart:convert';

import 'package:coldigui/features/catalog/domain/entities/catalog_filter_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty não filtra; qualquer conjunto não vazio filtra', () {
    expect(CatalogFilterState.empty.isEmpty, isTrue);
    expect(const CatalogFilterState(tags: {'PES'}).isEmpty, isFalse);
    expect(const CatalogFilterState(materialKindIds: {'k1'}).isEmpty, isFalse);
  });

  test('igualdade por conteúdo dos quatro conjuntos', () {
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

  test('fromUrl: category legado vira subtag de Coletânea somada às tags', () {
    // «Morte, Ressureição e Salvação» chega partido pela vírgula do CSV.
    final state = CatalogFilterState.fromUrl(
      category: 'Clamor,Morte, Ressureição e Salvação,Avulsos',
      tags: 'PES',
    );

    expect(state.tags, {
      'PES',
      'Coletânea',
      'Coletânea · Clamor',
      'Coletânea · Morte Ressurreição e Salvação',
    });
    expect(state.tonalities, isEmpty);
  });

  test('fromUrl: só categorias sem seção → estado vazio', () {
    expect(
      CatalogFilterState.fromUrl(category: 'Avulsos,Avulso Cias').isEmpty,
      isTrue,
    );
  });

  test(
    'formato gravado v3: ida e volta, sem categories; antigo e lixo → null',
    () {
      const state = CatalogFilterState(
        tonalities: {'Dm'},
        rhythms: {'Fox'},
        tags: {'PES'},
        materialKindIds: {'k1'},
      );

      final json = jsonDecode(
        jsonEncode(state.toPersistedJson()),
      ) as Map<String, dynamic>;
      expect(CatalogFilterState.persistedVersion, 3);
      expect(json['v'], 3);
      expect(json, isNot(contains('categories')));
      expect(CatalogFilterState.fromPersistedJson(json), state);
      expect(
        CatalogFilterState.fromPersistedJson({
          'materials': ['Partitura'],
          'arranjos': <String>[],
        }),
        isNull,
      );
      expect(
        CatalogFilterState.fromPersistedJson({
          'v': 1,
          'tags': ['PES'],
        }),
        isNull,
      );
      expect(CatalogFilterState.fromPersistedJson('x'), isNull);
      expect(CatalogFilterState.fromPersistedJson(null), isNull);
    },
  );

  test('v2 gravado: categories converte para tags e nada mais se perde', () {
    final state = CatalogFilterState.fromPersistedJson(
      jsonDecode(
        jsonEncode({
          'v': 2,
          'tonalities': ['Dm'],
          'rhythms': <String>[],
          'categories': ['Clamor', 'Morte, Ressurreição e Salvação', 'Avulsos'],
          'tags': ['PES'],
          'materialKinds': ['k1'],
        }),
      ),
    );

    expect(
      state,
      const CatalogFilterState(
        tonalities: {'Dm'},
        tags: {
          'PES',
          'Coletânea',
          'Coletânea · Clamor',
          'Coletânea · Morte Ressurreição e Salvação',
        },
        materialKindIds: {'k1'},
      ),
    );
  });

  test('v3 com categories também converte', () {
    expect(
      CatalogFilterState.fromPersistedJson({
        'v': 3,
        'categories': ['Louvor'],
      }),
      const CatalogFilterState(tags: {'Coletânea', 'Coletânea · Louvor'}),
    );
  });

  test('activeCount soma os valores escolhidos de todos os filtros', () {
    expect(CatalogFilterState.empty.activeCount, 0);
    expect(
      const CatalogFilterState(
        tonalities: {'Dm', 'G'},
        tags: {'PES'},
        materialKindIds: {'k1'},
      ).activeCount,
      4,
    );
  });
}
