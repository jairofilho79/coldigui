import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/library_catalog_mode.dart';
import 'library_view_settings_provider.dart';
import 'coldigom_library_filters_provider.dart';

/// Modo da Biblioteca — fixo em Coldigom neste build.
final libraryCatalogModeProvider =
    NotifierProvider<LibraryCatalogModeNotifier, LibraryCatalogMode>(
      LibraryCatalogModeNotifier.new,
    );

class LibraryCatalogModeNotifier extends Notifier<LibraryCatalogMode> {
  @override
  LibraryCatalogMode build() => LibraryCatalogMode.coldigom;

  void hydrateFromUrl({String? fonte}) {
    state = LibraryCatalogMode.fromUrl(fonte);
  }

  /// Neste build só Coldigom; chamadas para plpcg são ignoradas.
  void setMode(LibraryCatalogMode mode) {
    if (mode != LibraryCatalogMode.coldigom) return;
    if (state == mode) return;
    state = mode;
    ref.read(coldigomLibraryFiltersProvider.notifier).clear();
    ref.read(libraryViewSettingsProvider.notifier).setPage(1);
  }
}
