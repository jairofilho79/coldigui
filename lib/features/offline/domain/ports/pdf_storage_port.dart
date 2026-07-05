import 'dart:typed_data';

/// Porta de persistência de PDFs offline (Fase 4a).
///
/// Nativo: paths absolutos no filesystem via [PdfLocalStore].
/// Web: chaves lógicas — implementação OPFS (Fase 4b).
abstract interface class PdfStoragePort {
  /// Path ou chave raiz do store (`plpcg_pdfs/`).
  Future<String> get rootPath;

  /// Grava [bytes] em [relPath]; retorna identificador de storage.
  Future<String> writeAtomic(Uint8List bytes, String relPath);

  /// Verifica existência do PDF em [storageKey].
  Future<bool> exists(String storageKey);

  /// Remove PDF em [storageKey] (idempotente).
  Future<void> delete(String storageKey);

  /// Remove toda a árvore de storage e recria raiz vazia.
  Future<void> deleteTree();

  /// Soma bytes de todos os PDFs persistidos (auditoria UC-10).
  Future<int> getTotalOfflineBytes();

  /// PDFs no store que não constam em [indexedStorageKeys] (reconcile UC-10).
  Future<List<String>> listOrphans(Set<String> indexedStorageKeys);

  /// Lê bytes do PDF em [storageKey]; `null` se ausente.
  ///
  /// Com [maxBytes], lê só o prefixo (validação de magic bytes).
  Future<Uint8List?> readBytes(String storageKey, {int? maxBytes});
}
