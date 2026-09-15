import 'dart:typed_data';

/// Porta de persistência de áudios Coldigom baixados (spec §5.1, O7).
///
/// Gémea de [PdfStoragePort], enxuta: sem `listOrphans`/`purgeLegacyStorage`
/// (não há reconcile nem migração de áudio). Nativo: paths absolutos em
/// `documents/plpcg_audio/`; web: chaves lógicas na Cache API.
abstract interface class AudioStoragePort {
  /// Grava [bytes] em [relPath] (ex.: o `r2Key`); devolve o `storageKey`.
  Future<String> writeAtomic(Uint8List bytes, String relPath);

  Future<bool> exists(String storageKey);

  /// Bytes completos, ou `null` se ausente.
  Future<Uint8List?> readBytes(String storageKey);

  /// Idempotente.
  Future<void> delete(String storageKey);

  /// Apaga tudo e recria a raiz vazia («Remover áudios baixados»).
  Future<void> deleteTree();

  /// Soma de bytes persistidos — auditoria.
  Future<int> getTotalBytes();
}
