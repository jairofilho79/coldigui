import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_filter_options.dart';
import 'package:coldigui/features/catalog/domain/entities/material_kind_taxonomy.dart';
import 'package:coldigui/features/catalog/domain/usecases/build_material_kind_sections.dart';
import 'package:flutter_test/flutter_test.dart';

const _pdf = {MaterialKind.pdf};
const _audio = {MaterialKind.audio};

final options = <CatalogKindOption>[
  const CatalogKindOption(id: 'tuba', name: 'Tuba', types: _pdf),
  const CatalogKindOption(id: 'sax', name: 'Saxofone', types: _pdf),
  const CatalogKindOption(id: 'alto', name: 'Saxofone alto', types: _pdf),
  const CatalogKindOption(id: 'tenor', name: 'Saxofone tenor', types: _audio),
  const CatalogKindOption(
    id: 'cifra',
    name: 'Cifra',
    types: {MaterialKind.chord},
  ),
  const CatalogKindOption(id: 'novo', name: 'Novo', types: _pdf),
];

final taxonomy = MaterialKindTaxonomy(
  classes: const [
    MaterialKindClass(id: 'metais', label: 'Metais'),
    MaterialKindClass(id: 'banda', label: 'Banda'),
  ],
  kinds: const {
    'sax': MaterialKindTaxon(name: 'Saxofone', classId: 'metais', order: 30),
    'alto': MaterialKindTaxon(
      name: 'Saxofone alto',
      classId: 'metais',
      parentId: 'sax',
      order: 50,
    ),
    'tenor': MaterialKindTaxon(
      name: 'Saxofone tenor',
      classId: 'metais',
      parentId: 'sax',
      order: 60,
    ),
    'tuba': MaterialKindTaxon(name: 'Tuba', classId: 'metais', order: 100),
    'cifra': MaterialKindTaxon(name: 'Cifra', classId: 'banda', order: 10),
  },
);

List<String> labels(MaterialKindSection s) => [
  for (final u in s.units)
    switch (u) {
      MaterialKindSingleUnit(:final option) => option.name,
      MaterialKindFamilyUnit(:final parent, :final children) =>
        '${parent.name}[${children.map((c) => c.name).join(', ')}]',
    },
];

void main() {
  test(
    'classes na ordem, família recolhida, ordem de grade, Outros por último',
    () {
      final view = buildMaterialKindSections(
        options: options,
        taxonomy: taxonomy,
        types: const {},
        selected: const {},
      );
      expect(view.sections.map((s) => s.label), ['Metais', 'Banda', null]);
      expect(labels(view.sections[0]), [
        'Saxofone[Saxofone alto, Saxofone tenor]',
        'Tuba',
      ]);
      expect(view.sections[0].count, 4);
      expect(labels(view.sections[2]), ['Novo']);
      expect(view.hiddenCount, 0);
    },
  );

  test('contagem por tipo na ordem fixa, só tipos presentes', () {
    final view = buildMaterialKindSections(
      options: options,
      taxonomy: taxonomy,
      types: const {},
      selected: const {},
    );
    expect(view.typeCounts.keys.toList(), [
      MaterialKind.pdf,
      MaterialKind.chord,
      MaterialKind.audio,
    ]);
    expect(view.typeCounts[MaterialKind.pdf], 4);
  });

  test('tipo esconde kinds; selecionado nunca some; classe vazia some', () {
    final view = buildMaterialKindSections(
      options: options,
      taxonomy: taxonomy,
      types: const {MaterialKind.audio},
      selected: const {'novo'},
    );
    // Só o tenor tem áudio: sem o pai visível e com um membro só, vira chip simples.
    expect(view.sections.map((s) => s.label), ['Metais', null]);
    expect(labels(view.sections[0]), ['Saxofone tenor']);
    expect(labels(view.sections[1]), ['Novo']);
    expect(view.hiddenCount, 4);
  });

  test('pai escondido pelo tipo, dois filhos visíveis: família com o pai como cabeça', () {
    final view = buildMaterialKindSections(
      options: [
        const CatalogKindOption(id: 'sax', name: 'Saxofone', types: _pdf),
        const CatalogKindOption(
          id: 'alto',
          name: 'Saxofone alto',
          types: _audio,
        ),
        const CatalogKindOption(
          id: 'tenor',
          name: 'Saxofone tenor',
          types: _audio,
        ),
      ],
      taxonomy: taxonomy,
      types: const {MaterialKind.audio},
      selected: const {},
    );
    expect(labels(view.sections.single), [
      'Saxofone[Saxofone alto, Saxofone tenor]',
    ]);
  });

  test('pai sem material no índice: nome da taxonomia', () {
    final view = buildMaterialKindSections(
      options: [
        const CatalogKindOption(id: 'alto', name: 'Saxofone alto', types: _pdf),
        const CatalogKindOption(
          id: 'tenor',
          name: 'Saxofone tenor',
          types: _pdf,
        ),
      ],
      taxonomy: taxonomy,
      types: const {},
      selected: const {},
    );
    expect(labels(view.sections.single), [
      'Saxofone[Saxofone alto, Saxofone tenor]',
    ]);
  });

  test('selecionado que sumiu do catálogo continua, pelo nome da taxonomia ou pelo id', () {
    final view = buildMaterialKindSections(
      options: const [],
      taxonomy: taxonomy,
      types: const {},
      selected: const {'tuba', 'k-velho'},
    );
    expect(labels(view.sections[0]), ['Tuba']);
    expect(labels(view.sections[1]), ['k-velho']);
  });

  test('taxonomia vazia: uma seção só, sem classe, em ordem alfabética', () {
    final view = buildMaterialKindSections(
      options: options,
      taxonomy: MaterialKindTaxonomy.empty,
      types: const {},
      selected: const {},
    );
    expect(view.sections.single.classId, isNull);
    expect(labels(view.sections.single), [
      'Cifra',
      'Novo',
      'Saxofone',
      'Saxofone alto',
      'Saxofone tenor',
      'Tuba',
    ]);
  });
}
