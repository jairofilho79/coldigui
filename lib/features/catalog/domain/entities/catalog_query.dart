import 'louvor_group.dart';

/// Uma pergunta ao catálogo: texto + página. A busca local usa [text]; a
/// remota usa [text], [page] e [pageSize]. Os filtros do catálogo não viajam
/// por aqui: quem filtra é `matchesCatalogFilters`.
final class CatalogQuery {
  const CatalogQuery({required this.text, this.page = 1, this.pageSize = 20});

  /// Texto digitado, ainda sem `trim` (ver [isEmpty]).
  final String text;

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
