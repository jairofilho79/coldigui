/// Lançada por escritas que exigem Isar quando o banco não abriu (modo
/// degradado). Leituras devolvem vazio; escritas não podem fingir sucesso.
class StorageUnavailableException implements Exception {
  const StorageUnavailableException(this.operation);

  /// Operação que falhou, ex.: `'playlists.insert'`, `'offline.put'`.
  final String operation;

  @override
  String toString() => 'StorageUnavailableException($operation)';
}
