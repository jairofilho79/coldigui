import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:flutter_test/flutter_test.dart';

final _id = encodePdfId('assets/praises/p1/m1.gestures');
final _gesture = GestureMaterial(
  gestureId: _id, r2Key: 'assets/praises/p1/m1.gestures', nome: 'Quero viver',
  numero: '182', groupId: 'p1', categoria: 'Gestos', classificacao: 'Marcha',
);

void main() {
  test('findMaterialById resolve gesto do cache', () {
    final source = ColdigomCatalogSource(gestures: {_id: _gesture});
    final material = source.findMaterialById(_id);
    expect(material, isA<GestureMaterialRef>());
    expect(material!.id, _id);
  });

  test('gesto fora do cache devolve null', () {
    expect(const ColdigomCatalogSource().findMaterialById(_id), isNull);
  });

  test('findGroupById inclui o gesto nos extras do grupo', () {
    final source = ColdigomCatalogSource(gestures: {_id: _gesture});
    final group = source.findGroupById('p1');
    expect(group, isNotNull);
    expect(group!.gestureMaterials.single.gestureId, _id);
    expect(group.extras.whereType<GestureMaterialRef>(), hasLength(1));
  });
}
