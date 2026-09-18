import 'dart:math' show min;

import 'package:dio/dio.dart';

import '../../../catalog/data/datasources/catalog_local_datasource.dart';
import '../../../pdf_opening/domain/utils/louvor_pdf_path.dart';
import '../exceptions/offline_bulk_exceptions.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/offline_category_resolver.dart';
import '../utils/offline_material_resolver.dart';
import 'fetch_and_store_pdf.dart';

/// Resultado de [DownloadMissingPdfs] (UC-10, Fase 3.6/3.7 UI).
class DownloadMissingResult {
  const DownloadMissingResult({
    required this.downloadedCount,
    required this.skippedCount,
    required this.failedCount,
  });

  /// PDFs baixados e indexados nesta execução.
  final int downloadedCount;

  /// PDFs já no índice — não re-fetchados.
  final int skippedCount;

  /// Falhas de fetch/upsert.
  final int failedCount;
}

/// Limite de downloads on-demand simultâneos (UC-10, backlog #10).
const _maxConcurrentDownloads = 3;

/// UC-10 — Baixar PDFs faltantes no índice (Fase 3.6).
///
/// Usa o catálogo Isar (D1 local) como SSOT dos PDFs esperados. Pré-filtra PDFs
/// válidos (índice + arquivo no disco) e faz fetch **somente** dos ausentes.
///
/// O PDF vem da URL absoluta do manifest (`LouvorCache.pdf`); sem ela cai no
/// path legado `/assets/...`.
class DownloadMissingPdfs {
  DownloadMissingPdfs(
    this._catalogLocal,
    this._repository,
    this._fetchAndStorePdf,
  );

  final CatalogLocalDatasource _catalogLocal;
  final OfflinePdfRepository _repository;
  final FetchAndStorePdf _fetchAndStorePdf;

  Future<DownloadMissingResult> call({
    Set<String>? materialCategories,

    /// Chamado após cada fetch (ou falha). [total] = quantidade de faltantes.
    void Function(int done, int total)? onProgress,

    /// Cancelamento do utilizador (UC-09 «Parar»): os workers deixam de
    /// puxar ids e o use case termina com [OfflineBulkCancelledException].
    /// O que já foi gravado fica — a próxima chamada pré-filtra.
    CancelToken? cancelToken,
  }) async {
    // Uma só leitura de `louvorCaches`: dela saem os ids filtrados por
    // categoria e a URL de cada PDF.
    final rows = await _catalogLocal.loadPdfRows();
    final allPdfIds = _collectPdfIds(rows, materialCategories);
    final pdfById = {for (final row in rows) row.pdfId: row.pdf};
    final validPdfIds = await _collectValidPdfIds();
    final missingPdfIds = [
      for (final pdfId in allPdfIds)
        if (!validPdfIds.contains(pdfId)) pdfId,
    ];

    var downloaded = 0;
    var failed = 0;

    onProgress?.call(0, missingPdfIds.length);

    if (missingPdfIds.isNotEmpty) {
      var completed = 0;
      var nextIndex = 0;

      Future<void> worker() async {
        while (true) {
          if (cancelToken?.isCancelled ?? false) break;
          if (nextIndex >= missingPdfIds.length) break;
          final index = nextIndex++;
          final pdfId = missingPdfIds[index];

          try {
            await _fetchAndStorePdf(
              pdfId: pdfId,
              remotePath: LouvorPdfPath.remotePath(
                pdf: pdfById[pdfId] ?? '',
                pdfId: pdfId,
              ),
              category: OfflineCategoryResolver.fromPdfId(pdfId),
              persistentDownload: true,
              cancelToken: cancelToken,
            );
            downloaded++;
          } on Object {
            if (cancelToken?.isCancelled ?? false) break;
            failed++;
          }

          completed++;
          onProgress?.call(completed, missingPdfIds.length);
        }
      }

      final workerCount = min(_maxConcurrentDownloads, missingPdfIds.length);
      await Future.wait(List.generate(workerCount, (_) => worker()));
      if (cancelToken?.isCancelled ?? false) {
        throw const OfflineBulkCancelledException();
      }
    }

    return DownloadMissingResult(
      downloadedCount: downloaded,
      skippedCount: allPdfIds.length - missingPdfIds.length,
      failedCount: failed,
    );
  }

  /// PDFs com índice Isar e arquivo válido no store — via [lookupBatch].
  Future<Set<String>> _collectValidPdfIds() async {
    final entries = await _repository.listAll();
    if (entries.isEmpty) return {};

    const batchSize = 50;
    final validPdfIds = <String>{};
    for (var i = 0; i < entries.length; i += batchSize) {
      final batch = entries.sublist(i, min(i + batchSize, entries.length));
      final pdfIds = batch.map((e) => e.pdfId).toSet();
      validPdfIds.addAll(await _repository.lookupBatch(pdfIds));
    }
    return validPdfIds;
  }

  /// Ids únicos de [rows] (o cache pode repetir um `pdfId` em duas entradas)
  /// filtrados por [materialCategories]; `null` = todas as categorias.
  List<String> _collectPdfIds(
    List<CatalogPdfRow> rows,
    Set<String>? materialCategories,
  ) {
    if (materialCategories != null && materialCategories.isEmpty) {
      return const [];
    }

    final pdfIds = <String>{};
    for (final row in rows) {
      if (materialCategories != null &&
          !materialCategories.contains(
            OfflineMaterialResolver.toUiMaterial(row.categoria),
          )) {
        continue;
      }
      pdfIds.add(row.pdfId);
    }
    return pdfIds.toList();
  }
}
