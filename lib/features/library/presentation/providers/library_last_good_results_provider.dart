import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/library_catalog_mode.dart';
import '../../domain/entities/paginated_louvor_groups.dart';
import 'coldigom_library_filters_provider.dart';
import 'library_catalog_mode_provider.dart';
import 'library_coldigom_browse_provider.dart';
import 'library_view_settings_provider.dart';

/// Última página do browse Coldigom que **deu certo**, na consulta atual.
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
///
/// **Escopo da guarda.** O valor vale só enquanto a *consulta* for a mesma:
/// modo, filtros Coldigom, ordenação e tamanho de página entram no `build`
/// (via `watch`), então mudar qualquer um deles recria o notifier e zera a
/// página guardada. Sem isso, trocar de filtro e ver a primeira busca do filtro
/// novo falhar deixaria o paginador descrevendo o conjunto **anterior** —
/// totais e número de páginas de uma busca que não é mais a da tela.
///
/// A página (`view.page`) é a única coisa da consulta que fica **de fora**: ela
/// é justamente o que muda quando a página 2 falha e a página 1 tem que
/// sobreviver.
final libraryLastGoodResultsProvider =
    NotifierProvider<LibraryLastGoodResultsNotifier, PaginatedLouvorGroups>(
      LibraryLastGoodResultsNotifier.new,
    );

class LibraryLastGoodResultsNotifier extends Notifier<PaginatedLouvorGroups> {
  @override
  PaginatedLouvorGroups build() {
    // Assinatura da consulta: mudou, esquece a página guardada. Os filtros
    // entram pelos getters canônicos (CSV ordenado) e a view por um registro
    // de primitivos — os dois estados não têm `==`, e comparar por identidade
    // jogaria fora página boa a cada instância nova.
    ref.watch(libraryCatalogModeProvider);
    ref.watch(
      coldigomLibraryFiltersProvider.select(
        (filters) => (
          filters.tonalityUrlValue,
          filters.rhythmUrlValue,
          filters.categoryUrlValue,
          filters.tagsUrlValue,
          filters.materialKindsUrlValue,
        ),
      ),
    );
    ref.watch(
      libraryViewSettingsProvider.select(
        (view) => (view.sortBy, view.itemsPerPage),
      ),
    );

    // Sem `fireImmediately`: ao recriar por mudança de assinatura, o estado do
    // browse ainda pode ser o sucesso da consulta anterior, e disparar na hora
    // guardaria de volta exatamente o que este `build` acabou de esquecer.
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
    );

    return PaginatedLouvorGroups.empty;
  }
}
