import 'package:coldigui/features/catalog/domain/entities/catalog_filter_state.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/catalog/domain/usecases/matches_catalog_filters.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

void main() {
  final hino = catalogGroup(
    praiseId: 'p1',
    name: 'Hino',
    tonality: 'Dm',
    rhythm: 'Fox',
    category: 'Clamor',
    tags: const ['PES · 9.2026', 'Avulsos'],
    pdfKinds: const {'k-grade': 'Grade'},
    audioKinds: const {'k-play': 'Playback'},
  );
  final coro = catalogGroup(
    praiseId: 'p2',
    name: 'Coro',
    tonality: 'G',
    rhythm: 'Valsa',
    category: 'Adoração',
    tags: const ['CIAs'],
    pdfKinds: const {'k-cifra1': 'Cifra I'},
  );
  final semMeta = LouvorGroup(
    groupId: 'x',
    numero: '',
    nome: 'Sem meta',
    sections: const [],
  );

  bool matches(LouvorGroup group, CatalogFilterState filters) =>
      matchesCatalogFilters(group, filters);

  test('sem filtros passa tudo, inclusive grupo sem meta', () {
    expect(matches(hino, CatalogFilterState.empty), isTrue);
    expect(matches(semMeta, CatalogFilterState.empty), isTrue);
  });

  test('tom: OU entre os selecionados', () {
    const filters = CatalogFilterState(tonalities: {'Dm', 'A'});
    expect(matches(hino, filters), isTrue);
    expect(matches(coro, filters), isFalse);
  });

  test('ritmo e categoria', () {
    expect(matches(hino, const CatalogFilterState(rhythms: {'Fox'})), isTrue);
    expect(matches(coro, const CatalogFilterState(rhythms: {'Fox'})), isFalse);
    expect(
      matches(coro, const CatalogFilterState(categories: {'Adoração'})),
      isTrue,
    );
    expect(
      matches(hino, const CatalogFilterState(categories: {'Adoração'})),
      isFalse,
    );
  });

  test('tags: o pai inclui os filhos; o filho não inclui o pai; prefixo solto não conta', () {
    expect(matches(hino, const CatalogFilterState(tags: {'PES'})), isTrue);
    expect(
      matches(hino, const CatalogFilterState(tags: {'PES · 9.2026'})),
      isTrue,
    );
    expect(
      matches(hino, const CatalogFilterState(tags: {'PES · 9.2026 · Coro'})),
      isFalse,
    );
    expect(matches(hino, const CatalogFilterState(tags: {'PE'})), isFalse);
    expect(
      matches(coro, const CatalogFilterState(tags: {'PES', 'CIAs'})),
      isTrue,
    );
  });

  test('tipo de material: algum PDF ou extra com o materialKindId', () {
    expect(
      matches(hino, const CatalogFilterState(materialKindIds: {'k-play'})),
      isTrue,
    );
    expect(
      matches(hino, const CatalogFilterState(materialKindIds: {'k-grade'})),
      isTrue,
    );
    expect(
      matches(
        coro,
        const CatalogFilterState(materialKindIds: {'k-grade', 'k-play'}),
      ),
      isFalse,
    );
  });

  test('E entre filtros diferentes', () {
    const filters = CatalogFilterState(tonalities: {'Dm', 'G'}, tags: {'CIAs'});
    expect(matches(hino, filters), isFalse);
    expect(matches(coro, filters), isTrue);
  });

  test('grupo sem meta falha filtros de meta; sem materiais falha o tipo', () {
    expect(
      matches(semMeta, const CatalogFilterState(tonalities: {'Dm'})),
      isFalse,
    );
    expect(matches(semMeta, const CatalogFilterState(tags: {'PES'})), isFalse);
    expect(
      matches(semMeta, const CatalogFilterState(materialKindIds: {'k-grade'})),
      isFalse,
    );
  });

  test('valor do praise com espaços nas pontas casa com o chip aparado', () {
    final sujo = catalogGroup(praiseId: 'p3', name: 'S', tonality: ' Dm ');
    expect(matches(sujo, const CatalogFilterState(tonalities: {'Dm'})), isTrue);
  });
}
