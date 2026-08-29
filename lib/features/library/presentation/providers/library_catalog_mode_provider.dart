import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/presentation/providers/catalog_filters_provider.dart';
import '../../domain/entities/library_catalog_mode.dart';
import 'library_special_arrangement_provider.dart';
import 'library_view_settings_provider.dart';
import 'coldigom_library_filters_provider.dart';

/// Modo exclusivo da Biblioteca: PLPCG (local) ou Coldigom (online).
final libraryCatalogModeProvider =
    NotifierProvider<LibraryCatalogModeNotifier, LibraryCatalogMode>(
      LibraryCatalogModeNotifier.new,
    );

class LibraryCatalogModeNotifier extends Notifier<LibraryCatalogMode> {
  @override
  LibraryCatalogMode build() => LibraryCatalogMode.plpcg;

  void hydrateFromUrl({String? fonte}) {
    state = LibraryCatalogMode.fromUrl(fonte);
  }

  /// Troca o modo e limpa filtros incompatíveis; reseta página para 1.
  void setMode(LibraryCatalogMode mode) {
    if (state == mode) return;
    state = mode;
    if (mode == LibraryCatalogMode.coldigom) {
      ref.read(catalogFiltersProvider.notifier).reset();
      ref.read(librarySpecialArrangementProvider.notifier).clear();
    } else {
      ref.read(coldigomLibraryFiltersProvider.notifier).clear();
    }
    ref.read(libraryViewSettingsProvider.notifier).setPage(1);
  }
}
