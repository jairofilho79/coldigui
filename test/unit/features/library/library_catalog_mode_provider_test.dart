import 'package:coldigui/features/library/domain/entities/library_catalog_mode.dart';
import 'package:coldigui/features/library/presentation/providers/library_catalog_mode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default é coldigom', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(libraryCatalogModeProvider),
      LibraryCatalogMode.coldigom,
    );
  });

  test('hydrateFromUrl sem fonte permanece coldigom', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(libraryCatalogModeProvider.notifier).hydrateFromUrl();

    expect(
      container.read(libraryCatalogModeProvider),
      LibraryCatalogMode.coldigom,
    );
  });

  test('setMode(plpcg) é ignorado', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(libraryCatalogModeProvider.notifier)
        .setMode(LibraryCatalogMode.plpcg);

    expect(
      container.read(libraryCatalogModeProvider),
      LibraryCatalogMode.coldigom,
    );
  });
}
