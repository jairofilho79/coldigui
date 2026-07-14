import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_filters_provider.dart';
import 'package:coldigui/features/library/domain/entities/library_catalog_mode.dart';
import 'package:coldigui/features/library/presentation/providers/coldigom_library_filters_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_catalog_mode_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_special_arrangement_provider.dart';
import 'package:coldigui/features/library/presentation/providers/library_view_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trocar para coldigom limpa filtros PLPCG e reseta página', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(catalogFiltersProvider.notifier).toggleArranjo('ColAdultos');
    container
        .read(librarySpecialArrangementProvider.notifier)
        .toggleSpecialArrangement('Especial');
    container.read(libraryViewSettingsProvider.notifier).setPage(3);

    container
        .read(libraryCatalogModeProvider.notifier)
        .setMode(LibraryCatalogMode.coldigom);

    expect(
      container.read(libraryCatalogModeProvider),
      LibraryCatalogMode.coldigom,
    );
    expect(container.read(catalogFiltersProvider).selectedArranjos, isEmpty);
    expect(
      container.read(catalogFiltersProvider).selectedMaterials,
      CatalogMaterials.defaultSelected.toSet(),
    );
    expect(
      container
          .read(librarySpecialArrangementProvider)
          .selectedSpecialArrangements,
      isEmpty,
    );
    expect(container.read(libraryViewSettingsProvider).page, 1);
  });

  test('trocar para plpcg limpa filtros coldigom', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(libraryCatalogModeProvider.notifier)
        .setMode(LibraryCatalogMode.coldigom);
    container
        .read(coldigomLibraryFiltersProvider.notifier)
        .toggleTonality('Dm');
    container.read(libraryViewSettingsProvider.notifier).setPage(2);

    container
        .read(libraryCatalogModeProvider.notifier)
        .setMode(LibraryCatalogMode.plpcg);

    expect(
      container.read(libraryCatalogModeProvider),
      LibraryCatalogMode.plpcg,
    );
    expect(
      container.read(coldigomLibraryFiltersProvider).selectedTonalities,
      isEmpty,
    );
    expect(container.read(libraryViewSettingsProvider).page, 1);
  });
}
