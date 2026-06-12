import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/offline/domain/utils/offline_material_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toUiMaterial mapeia cifras para chip Cifra', () {
    expect(
      OfflineMaterialResolver.toUiMaterial(CatalogMaterials.cifraNivelI),
      CatalogMaterials.cifra,
    );
    expect(
      OfflineMaterialResolver.toUiMaterial(CatalogMaterials.cifraNivelII),
      CatalogMaterials.cifra,
    );
  });

  test('toUiMaterial preserva partitura e gestos', () {
    expect(
      OfflineMaterialResolver.toUiMaterial(CatalogMaterials.partitura),
      CatalogMaterials.partitura,
    );
    expect(
      OfflineMaterialResolver.toUiMaterial(CatalogMaterials.gestosEmGravura),
      CatalogMaterials.gestosEmGravura,
    );
  });

  test('toUiMaterial retorna null para classificação', () {
    expect(OfflineMaterialResolver.toUiMaterial('ColAdultos'), isNull);
  });
}
