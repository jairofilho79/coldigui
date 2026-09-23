import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/utils/catalog_tag_hierarchy.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filter_options_provider.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/coldigom/presentation/providers/coldigom_catalog_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  group('hierarquia de tags', () {
    test('o pai casa consigo e com os filhos; prefixo solto não conta', () {
      expect(catalogTagMatches('PES', 'PES'), isTrue);
      expect(catalogTagMatches('PES · 9.2026', 'PES'), isTrue);
      expect(catalogTagMatches('PES · 9.2026 · Coro', 'PES · 9.2026'), isTrue);
      expect(catalogTagMatches('PESCA', 'PES'), isFalse);
      expect(catalogTagMatches('PES', 'PES · 9.2026'), isFalse);
    });

    test('ancestrais em ordem, do mais geral à própria tag', () {
      expect(catalogTagWithAncestors('A · B · C').toList(), [
        'A',
        'A · B',
        'A · B · C',
      ]);
      expect(catalogTagWithAncestors('Avulsos').toList(), ['Avulsos']);
    });
  });

  group('CatalogFilterOptions.fromGroups', () {
    final groups = [
      catalogGroup(
        praiseId: 'p1',
        name: 'Hino',
        tonality: 'Dm',
        rhythm: 'Fox',
        category: 'Clamor',
        tags: const ['PES · 9.2026', 'Avulsos'],
        pdfKinds: const {'k-cifra1': 'Cifra I'},
      ),
      catalogGroup(
        praiseId: 'p2',
        name: 'Coro',
        tonality: ' G ',
        category: 'Adoração',
        tags: const ['avulsos'],
        pdfKinds: const {'k-grade': 'Grade'},
        audioKinds: const {'k-play': 'Playback'},
      ),
      catalogGroup(
        praiseId: 'p3',
        name: 'Outro',
        tonality: 'Dm',
        pdfKinds: const {'k-grade': 'Grade'},
      ),
      // Grupo sem meta (ex.: montado fora do catálogo): não contribui nem
      // derruba nada.
      LouvorGroup(groupId: 'x', numero: '', nome: 'x', sections: const []),
    ];
    final options = CatalogFilterOptions.fromGroups(groups);

    test(
      'tom, ritmo e categoria: valores com praise, aparados, sem vazios',
      () {
        expect(options.tonalities, ['Dm', 'G']);
        expect(options.rhythms, ['Fox']);
        expect(options.categories, ['Adoração', 'Clamor']);
      },
    );

    test(
      'tags como estão (M5), com os ancestrais, sem acento/caixa na ordem',
      () {
        expect(options.tags, ['Avulsos', 'avulsos', 'PES', 'PES · 9.2026']);
      },
    );

    test(
      'tipos de material por id, com o nome do kind, ordenados pelo nome',
      () {
        expect(options.materialKinds, const [
          CatalogKindOption(id: 'k-cifra1', name: 'Cifra I'),
          CatalogKindOption(id: 'k-grade', name: 'Grade'),
          CatalogKindOption(id: 'k-play', name: 'Playback'),
        ]);
      },
    );

    test('sem grupos → vazio', () {
      final empty = CatalogFilterOptions.fromGroups(const []);
      expect(empty.tonalities, isEmpty);
      expect(empty.tags, isEmpty);
      expect(empty.materialKinds, isEmpty);
    });
  });

  test('catalogFilterOptionsProvider lê o índice local', () {
    final container = ProviderContainer(
      overrides: [
        coldigomSearchIndexProvider.overrideWithValue(
          catalogIndexOf([
            catalogGroup(praiseId: 'p1', name: 'Hino', tonality: 'Dm'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(catalogFilterOptionsProvider).tonalities, ['Dm']);
  });

  test('índice vazio → CatalogFilterOptions.empty', () {
    final container = ProviderContainer(
      overrides: [
        coldigomSearchIndexProvider.overrideWithValue(
          ColdigomSearchIndex.empty,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(catalogFilterOptionsProvider),
      same(CatalogFilterOptions.empty),
    );
  });
}
