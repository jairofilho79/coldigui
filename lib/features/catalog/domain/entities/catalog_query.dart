import '../constants/catalog_materials.dart';
import 'catalog_filter_state.dart';
import 'louvor_group.dart';

/// Uma pergunta ao catálogo: texto + filtros UC-02 + página.
///
/// Vale para os dois lados da porta: a busca local (PLPCG) usa [text] e
/// [filters]; a busca remota (Coldigom) usa [text], [page] e [pageSize] — a
/// API não aceita os filtros locais, que continuam sendo aplicados em memória.
final class CatalogQuery {
  const CatalogQuery({
    required this.text,
    this.filters = defaultFilters,
    this.page = 1,
    this.pageSize = 20,
  });

  /// Filtro padrão: todos os materiais, nenhum arranjo — o mesmo que
  /// `CatalogFilterState.defaults()`, só que `const` (a fábrica não é).
  static const defaultFilters = CatalogFilterState(
    selectedMaterials: CatalogMaterials.defaultSelected,
    selectedArranjos: {},
  );

  /// Texto digitado, ainda sem `trim` (ver [isEmpty]).
  final String text;

  /// Filtros de material e arranjo aplicados localmente.
  final CatalogFilterState filters;

  /// Página 1-based da fonte remota.
  final int page;

  /// Tamanho de página pedido à fonte remota.
  final int pageSize;

  /// `true` quando não há o que buscar — nenhuma fonte deve tocar a rede.
  bool get isEmpty => text.trim().isEmpty;
}

/// Uma página de resultados de uma fonte remota.
final class CatalogSearchPage {
  const CatalogSearchPage({
    required this.groups,
    required this.page,
    this.hasNextPage = false,
  });

  final List<LouvorGroup> groups;

  /// Página 1-based que estes [groups] representam.
  final int page;

  /// `true` quando a fonte indica que há mais uma página.
  final bool hasNextPage;

  /// Página vazia — o que uma fonte puramente local devolve.
  static const empty = CatalogSearchPage(groups: [], page: 1);
}
