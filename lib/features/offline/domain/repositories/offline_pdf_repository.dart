import 'dart:typed_data';

import '../entities/offline_pdf_batch_item.dart';
import '../entities/offline_pdf_entry.dart';

/// Contrato de persistência offline — índice Isar + PDFs em documents (UC-09/10).
///
/// Ponto de integração para [ResolvePdfForReader] (3.2) e [FetchAndStorePdf] (3.3).
/// DI via [offlinePdfRepositoryProvider].
abstract class OfflinePdfRepository {
  /// Lookup O(1) no Isar + validação de arquivo no disco.
  ///
  /// Retorna `null` se índice ausente, arquivo inexistente ou `length == 0`.
  /// Índice órfão permanece até [ReconcileOfflineIndex] (3.6).
  Future<OfflinePdfEntry?> lookup(String pdfId);

  /// Lookup com estado do índice — uma query Isar + validação de disco.
  ///
  /// [entry] é não-nulo apenas com índice e arquivo válido.
  /// [hasIndexEntry] indica presença no Isar mesmo com arquivo inválido/ausente.
  Future<(OfflinePdfEntry? entry, bool hasIndexEntry)> lookupWithIndexState(
    String pdfId,
  );

  /// Subconjunto de [pdfIds] com índice Isar e arquivo válido no disco.
  ///
  /// Uma consulta Isar em lote + validação de disco paralelizada (bulk UC-09).
  Future<Set<String>> lookupBatch(Set<String> pdfIds);

  /// Entrada do índice Isar sem validar disco — detecta órfãos (reconcile 3.6).
  Future<OfflinePdfEntry?> findIndexEntry(String pdfId);

  /// Grava bytes via escrita atômica e upsert no índice Isar.
  ///
  /// [category] = `Louvor.classificacao`. Path no disco via [PdfPathNormalizer.getPdfRelPath].
  /// [isPersistent] — quando `true`, marca o PDF como isento de eviction LRU.
  Future<OfflinePdfEntry> upsert({
    required String pdfId,
    required Uint8List bytes,
    required String category,
    bool isPersistent = false,
  });

  /// Remove arquivo no disco e entrada no índice (idempotente se ausente).
  Future<void> remove(String pdfId);

  /// Reindexa [fromPdfId] como [toPdfId] sem mover o arquivo no disco.
  ///
  /// Idempotente se [fromPdfId] ausente ou [toPdfId] já indexado.
  Future<void> remapPdfId({
    required String fromPdfId,
    required String toPdfId,
  });

  /// Resolve [pdfId] a partir do path absoluto no índice Isar, ou `null`.
  Future<String?> findPdfIdByAbsolutePath(String absolutePath);

  /// Agregação por categoria a partir do índice Isar — sem scan filesystem.
  Future<Map<String, int>> countByCategory();

  /// Todos os registros do índice — sem validar disco (bulk/reconcile 3.5/3.6).
  Future<List<OfflinePdfEntry>> listAll();

  /// Indexa PDFs já gravados em disco (bulk UC-09) em chunks Isar.
  Future<void> indexExtractedBatch(List<ExtractedPdfItem> items);

  /// Upsert em lote com escrita atômica (quando bytes ainda não estão no disco).
  Future<void> upsertBatch(List<OfflinePdfBatchItem> items);

  /// Remove entradas órfãs do índice por [pdfIds].
  Future<int> removeIndexEntries(Set<String> pdfIds);

  /// Limpa todo o índice Isar — sem tocar arquivos no disco.
  Future<void> clearAll();

  /// Soma de [OfflinePdfEntry.fileSize] no índice — stats e quota LRU.
  Future<int> totalCachedBytes();

  /// Remove PDFs menos recentes até liberar [targetBytes] (LRU por lastAccessedAt).
  ///
  /// [excludePdfIds] permanecem no cache (ex.: favoritos ou PDF em download).
  /// Retorna bytes efetivamente liberados.
  Future<int> evictOldestPdfs({
    required int targetBytes,
    Set<String> excludePdfIds = const {},
  });

  /// Persiste toques LRU pendentes (debounce) — ex.: ao pausar o app.
  Future<void> flushPendingTouchLastAccessed();
}
