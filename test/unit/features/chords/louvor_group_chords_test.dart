import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:flutter_test/flutter_test.dart';

ChordMaterial _chord({required String groupId, required String categoria}) {
  return ChordMaterial(
    chordId: 'id-$groupId-$categoria',
    r2Key: 'assets/praises/$groupId/$categoria.chord',
    nome: 'Comigo habita',
    numero: '692',
    groupId: groupId,
    categoria: categoria,
    classificacao: 'Cancao',
  );
}

void main() {
  test('agrupa cifras pelo mesmo groupId', () {
    final groups = LouvorGroup.fromLouvores(
      const [],
      chordMaterials: [
        _chord(groupId: 'p1', categoria: 'Cifra I'),
        _chord(groupId: 'p1', categoria: 'Cifra II'),
        _chord(groupId: 'p2', categoria: 'Cifra'),
      ],
    );

    final p1 = groups.firstWhere((g) => g.groupId == 'p1');
    expect(p1.chordMaterials.map((c) => c.categoria), ['Cifra I', 'Cifra II']);
    expect(groups.firstWhere((g) => g.groupId == 'p2').chordMaterials, hasLength(1));
  });

  test('cria grupo so com cifra, sem PDF nem audio', () {
    final groups = LouvorGroup.fromLouvores(
      const [],
      chordMaterials: [_chord(groupId: 'p1', categoria: 'Cifra')],
    );

    expect(groups, hasLength(1));
    expect(groups.single.nome, 'Comigo habita');
    expect(groups.single.numero, '692');
  });

  test('cifras entram em totalMaterials', () {
    final group = LouvorGroup.fromLouvores(
      const [],
      chordMaterials: [
        _chord(groupId: 'p1', categoria: 'Cifra I'),
        _chord(groupId: 'p1', categoria: 'Cifra II'),
      ],
    ).single;

    expect(group.totalMaterials, 2);
  });

  test('withColdigomMeta preserva as cifras', () {
    final group = LouvorGroup.fromLouvores(
      const [],
      chordMaterials: [_chord(groupId: 'p1', categoria: 'Cifra')],
    ).single;

    expect(group.withColdigomMeta(null).chordMaterials, hasLength(1));
  });
}
