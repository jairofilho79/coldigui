/// Lançada ao gerar folheto de uma lista de entradas vazia (UC-08).
class EmptyLeafletException implements Exception {
  const EmptyLeafletException();

  @override
  String toString() => 'EmptyLeafletException: entries is empty';
}
