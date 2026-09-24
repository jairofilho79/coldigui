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

  /// Remove [pdfIds] em lote — arquivos primeiro, depois **uma** baixa no
  /// índice Isar (`deleteByPdfIds`), não uma por PDF como [remove] em laço
  /// faria. Quem deriva estado do índice ouve uma única mudança em vez de N
  /// (ex.: remoção Coldigom de ~1700 PDFs bumpava `offlineIndexRevisionProvider`
  /// ~1700×). Idempotente se algum `pdfId` ausente.
  Future<void> removeMany(Set<String> pdfIds);

  /// Reindexa cada chave de [fromTo] como o seu valor, sem mover arquivos no
  /// disco, e tira [remove] do índice — tudo numa escrita só, com **um**
  /// aviso a quem deriva estado do índice (a troca de ids legados de um
  /// índice com milhares de PDFs; spec fim-fonte-plpcg §6.2).
  ///
  /// Chave ausente é ignorada. Se o destino já está indexado (ou outra chave
  /// do lote já foi para ele), a linha de origem sai e a do destino fica —
  /// persistente se qualquer das duas era. Devolve quantas linhas de origem
  /// mudaram ou saíram.
  Future<int> remapPdfIds(
    Map<String, String> fromTo, {
    Set<String> remove = const {},
  });

  /// Resolve [pdfId] a partir do path absoluto no índice Isar, ou `null`.
  Future<String?> findPdfIdByAbsolutePath(String absolutePath);

  /// Agregação por categoria a partir do índice Isar — sem scan filesystem.
  Future<Map<String, int>> countByCategory();

  /// Todos os registros do índice — sem validar disco (bulk/reconcile 3.5/3.6).
  Future<List<OfflinePdfEntry>> listAll();

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
