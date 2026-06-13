/// Entidade de domínio — PDF offline com índice e arquivo válidos (Fase 3.1).
///
/// Retornada por [OfflinePdfRepository.lookup] e [OfflinePdfRepository.upsert].
/// Diferente de `LocalPdfSource` (3.2), que inclui flag `fromCache` para o resolver.
class OfflinePdfEntry {
  const OfflinePdfEntry({
    required this.pdfId,
    required this.absolutePath,
    required this.category,
    required this.fileSize,
    required this.downloadedAt,
    this.lastAccessedAt,
  });

  /// Identificador Base64 URL-safe do path relativo (manifest).
  final String pdfId;

  /// Path absoluto em `documents/plpcg_pdfs/`.
  final String absolutePath;

  /// Classificação (`Louvor.classificacao`) — ex.: `ColAdultos`.
  final String category;

  /// Tamanho em bytes persistido no último upsert.
  final int fileSize;

  /// Momento do último upsert bem-sucedido.
  final DateTime downloadedAt;

  /// Momento do último acesso bem-sucedido — LRU eviction.
  final DateTime? lastAccessedAt;
}
