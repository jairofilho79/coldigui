/// Entrada(s) da lista sem `shortId` de praise no catálogo local — o link por
/// praise não pode ser montado (spec fim-fonte-plpcg §4.2).
///
/// Lançada por `GeneratePlaylistShareUrl`. Quem mostra o erro também pede um
/// sync do catálogo: o próximo share já encontra o id.
class PraiseShortIdUnavailableException implements Exception {
  const PraiseShortIdUnavailableException(this.entryIds);

  /// Ids das entradas sem token, na ordem da lista.
  final List<String> entryIds;

  @override
  String toString() =>
      'PraiseShortIdUnavailableException(${entryIds.length} sem shortId: '
      '${entryIds.join(', ')})';
}
