/// Sobe os itens cujo kind é favorito, na ordem do [rank]; os demais mantêm
/// a ordem de entrada. Sort **estável** — dois itens do mesmo kind favorito
/// continuam na ordem em que vieram.
///
/// Genérica por seletor porque o sheet ordena tanto `CatalogMaterial` quanto
/// as `LouvorMaterialEntry` da aba PDF. [rank] vazio devolve a própria lista:
/// deslogado e acervo PLPCG não pagam nada.
List<T> orderByFavoriteKinds<T>(
  List<T> items,
  Map<String, int> rank, {
  required String? Function(T item) kindIdOf,
}) {
  if (rank.isEmpty || items.length < 2) return items;
  final favorites = <(int, T)>[];
  final others = <T>[];
  for (final item in items) {
    final kind = kindIdOf(item);
    final position = kind == null ? null : rank[kind];
    if (position == null) {
      others.add(item);
    } else {
      favorites.add((position, item));
    }
  }
  if (favorites.isEmpty) return items;
  // `List.sort` não é estável; o índice de entrada desempata.
  final indexed = [
    for (var i = 0; i < favorites.length; i++)
      (favorites[i].$1, i, favorites[i].$2),
  ];
  indexed.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
  });
  return [for (final entry in indexed) entry.$3, ...others];
}
