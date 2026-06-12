import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_classification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogMaterials', () {
    test('expandMaterial Cifra inclui níveis I e II', () {
      expect(
        CatalogMaterials.expandMaterial(CatalogMaterials.cifra),
        {
          CatalogMaterials.cifra,
          CatalogMaterials.cifraNivelI,
          CatalogMaterials.cifraNivelII,
        },
      );
    });

    test('parseFromUrl vazio retorna padrão', () {
      expect(
        CatalogMaterials.parseFromUrl(null),
        CatalogMaterials.defaultSelected,
      );
    });

    test('serializeForUrl omite seleção padrão', () {
      expect(
        CatalogMaterials.serializeForUrl(CatalogMaterials.defaultSelected),
        isNull,
      );
    });

    test('serializeForUrl inclui subset', () {
      expect(
        CatalogMaterials.serializeForUrl({CatalogMaterials.partitura}),
        CatalogMaterials.partitura,
      );
    });
  });

  group('LouvorClassification', () {
    test('baseClassification remove parênteses', () {
      expect(
        LouvorClassification.baseClassification('ColAdultos (Especial)'),
        'ColAdultos',
      );
    });

    test('parseArranjosFromUrl vazio retorna conjunto vazio', () {
      expect(LouvorClassification.parseArranjosFromUrl(null), isEmpty);
    });
  });
}
