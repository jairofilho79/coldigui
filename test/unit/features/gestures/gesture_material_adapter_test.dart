import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:flutter_test/flutter_test.dart';

PraiseDetailDto _praise(List<Map<String, Object?>> materials) => PraiseDetailDto.fromJson({
  'id': 'p1',
  'name': 'Quero viver',
  'number': '182',
  'rhythm': 'Marcha',
  'tonality': 'C',
  'category': 'CIA',
  'author': 'Autor',
  'tag_names': <String>[],
  'materials': materials,
});

void main() {
  test('type gestures com r2_key vira GestureMaterial no espaço do pdfId', () {
    final praise = _praise([
      {'id': 'm1', 'praise_id': 'p1', 'type': 'gestures', 'r2_key': 'assets/praises/p1/m1.gestures', 'material_kind_name': 'Gestos'},
      {'id': 'm2', 'praise_id': 'p1', 'type': 'pdf', 'r2_key': 'assets/praises/p1/m2.pdf'},
    ]);
    final items = ColdigomLouvorAdapter.toGestureMaterials(praise);
    expect(items, hasLength(1));
    final g = items.single;
    expect(g.gestureId, encodePdfId('assets/praises/p1/m1.gestures'));
    expect(materialIdKindOf(g.gestureId), MaterialKind.gesture);
    expect(g.r2Key, 'assets/praises/p1/m1.gestures');
    expect(g.nome, 'Quero viver');
    expect(g.numero, '182');
    expect(g.groupId, 'p1');
    expect(g.categoria, 'Gestos');
    expect(g.classificacao, 'Marcha');
    expect(g.author, 'Autor');
  });

  test('sem r2_key é ignorado; categoria cai para "Gestos"', () {
    final praise = _praise([
      {'id': 'm1', 'praise_id': 'p1', 'type': 'gestures'},
      {'id': 'm3', 'praise_id': 'p1', 'type': 'GESTURES', 'r2_key': 'assets/praises/p1/m3.gestures'},
    ]);
    final items = ColdigomLouvorAdapter.toGestureMaterials(praise);
    expect(items.single.categoria, 'Gestos');
  });

  test('PDF de gestos continua sendo Louvor (toLouvores), não GestureMaterial', () {
    final praise = _praise([
      {'id': 'm2', 'praise_id': 'p1', 'type': 'pdf', 'r2_key': 'assets/praises/p1/gestos.pdf', 'material_kind_name': 'Gestos em Gravura'},
    ]);
    expect(ColdigomLouvorAdapter.toGestureMaterials(praise), isEmpty);
    expect(ColdigomLouvorAdapter.toLouvores(praise), hasLength(1));
  });
}
