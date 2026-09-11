import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/library_catalog_mode.dart';
import '../../domain/entities/paginated_louvor_groups.dart';
import 'library_catalog_mode_provider.dart';
import 'library_coldigom_browse_provider.dart';

/// Última página do browse Coldigom que **deu certo**.
///
/// O paginador (`LibraryPaginationControls`) some quando `totalItems == 0`, e
/// era isso que acontecia quando a busca da página 2 falhava: sem valor, a
/// biblioteca caía em [PaginatedLouvorGroups.empty] e o usuário ficava com o
/// banner de erro e nenhuma navegação de página — nem para voltar à página 1.
///
/// Aqui o último resultado bom fica guardado fora do `AsyncValue` do browse,
/// para o paginador continuar de pé enquanto o banner de erro aparece. Só
/// resultado de sucesso em modo Coldigom entra: o `empty` que o browse devolve
/// fora do modo Coldigom não conta como página boa.
final libraryLastGoodResultsProvider =
    NotifierProvider<LibraryLastGoodResultsNotifier, PaginatedLouvorGroups>(
      LibraryLastGoodResultsNotifier.new,
    );

class LibraryLastGoodResultsNotifier extends Notifier<PaginatedLouvorGroups> {
  @override
  PaginatedLouvorGroups build() {
    ref.listen<AsyncValue<PaginatedLouvorGroups>>(
      libraryColdigomBrowseProvider,
      (_, next) {
        // `isLoading` com valor anterior é refresh, não página nova; erro não
        // tem página boa a guardar.
        if (next.isLoading || next.hasError) return;
        final results = next.value;
        if (results == null) return;
        if (ref.read(libraryCatalogModeProvider) !=
            LibraryCatalogMode.coldigom) {
          return;
        }
        state = results;
      },
      fireImmediately: true,
    );

    return PaginatedLouvorGroups.empty;
  }
}
