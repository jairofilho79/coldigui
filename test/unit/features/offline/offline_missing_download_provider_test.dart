import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_category_selection_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missingScope é interseção de selecionadas e bulk', () {
    const state = OfflineCategorySelectionState(
      selected: {
        CatalogMaterials.partitura,
        CatalogMaterials.cifra,
        CatalogMaterials.gestosEmGravura,
      },
      bulkDownloaded: {
        CatalogMaterials.partitura,
        CatalogMaterials.cifra,
      },
    );

    expect(state.missingScope, {
      CatalogMaterials.partitura,
      CatalogMaterials.cifra,
    });
    expect(state.packagesScope, {CatalogMaterials.gestosEmGravura});
  });

  test('packagesScope vazio quando todas selecionadas já têm bulk', () {
    const state = OfflineCategorySelectionState(
      selected: CatalogMaterials.defaultSelected,
      bulkDownloaded: CatalogMaterials.defaultSelected,
    );

    expect(state.missingScope, CatalogMaterials.defaultSelected);
    expect(state.packagesScope, isEmpty);
  });
}
