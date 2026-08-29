// test/unit/features/chords/chord_material_adapter_test.dart
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:flutter_test/flutter_test.dart';

PraiseDetailDto _praise(List<Map<String, dynamic>> materials) {
  return PraiseDetailDto.fromJson({
    'id': 'praise-1',
    'name': 'Comigo habita',
    'number': '692',
    'rhythm': 'Cancao',
    'author': 'J.G.R',
    'materials': materials,
  });
}

void main() {
  test('cria um ChordMaterial por material type chord', () {
    final items = ColdigomLouvorAdapter.toChordMaterials(
      _praise([
        {
          'id': 'm1',
          'type': 'chord',
          'r2_key': 'assets/praises/praise-1/m1.chord',
          'material_kind_name': 'Cifra I',
        },
        {
          'id': 'm2',
          'type': 'chord',
          'r2_key': 'assets/praises/praise-1/m2.chord',
          'material_kind_name': 'Cifra II',
        },
      ]),
    );

    expect(items, hasLength(2));
    expect(items.map((i) => i.categoria), ['Cifra I', 'Cifra II']);
    expect(items.first.nome, 'Comigo habita');
    expect(items.first.numero, '692');
    expect(items.first.groupId, 'praise-1');
    expect(items.first.author, 'J.G.R');
    expect(items.first.classificacao, 'Cancao');
    expect(items.first.source, LouvorDataSource.coldigom);
  });

  test('o chordId cai no mesmo espaco do pdfId e e reconhecido como cifra', () {
    final item = ColdigomLouvorAdapter.toChordMaterials(
      _praise([
        {
          'id': 'm1',
          'type': 'chord',
          'r2_key': 'assets/praises/praise-1/m1.chord',
          'material_kind_name': 'Cifra',
        },
      ]),
    ).single;

    expect(materialIdKindOf(item.chordId), MaterialIdKind.chord);
    expect(item.r2Key, 'assets/praises/praise-1/m1.chord');
  });

  test('ignora materiais de outros tipos', () {
    final items = ColdigomLouvorAdapter.toChordMaterials(
      _praise([
        {
          'id': 'm1',
          'type': 'pdf',
          'r2_key': 'assets/praises/praise-1/m1.pdf',
          'material_kind_name': 'Cifra',
        },
        {
          'id': 'm2',
          'type': 'mp3',
          'r2_key': 'assets/praises/praise-1/m2.mp3',
          'material_kind_name': 'Audio',
        },
      ]),
    );

    expect(items, isEmpty);
  });

  test('ignora chord sem r2_key utilizavel', () {
    final items = ColdigomLouvorAdapter.toChordMaterials(
      _praise([
        {'id': 'm1', 'type': 'chord', 'r2_key': null},
        {'id': 'm2', 'type': 'chord', 'r2_key': ''},
      ]),
    );

    expect(items, isEmpty);
  });

  test('usa "Cifra" como categoria padrao sem material_kind_name', () {
    final item = ColdigomLouvorAdapter.toChordMaterials(
      _praise([
        {
          'id': 'm1',
          'type': 'chord',
          'r2_key': 'assets/praises/praise-1/m1.chord',
        },
      ]),
    ).single;

    expect(item.categoria, 'Cifra');
  });
}
