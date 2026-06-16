import 'package:dio/dio.dart';

import '../entities/local_pdf_source.dart';
import '../exceptions/pdf_resolve_exceptions.dart';
import '../repositories/offline_pdf_repository.dart';
import 'fetch_and_store_pdf.dart';

/// Resolver local-first — lookup O(1) + fetch on miss (Fase 3.2).
///
/// Hit → path absoluto local; miss → delega [FetchAndStorePdf]; falha de rede
/// → exceção tipada conforme índice órfão ou ausente.
///
/// Quando [isFullOfflineMode] retorna `true` (`OFFLINE_AVAILABLE=TRUE`), o miss
/// usa `persistentDownload` e omite eviction LRU — preserva acervo bulk ao abrir
/// PDFs novos fora dos packages.
class ResolvePdfForReader {
  const ResolvePdfForReader(
    this._repository,
    this._fetchAndStore, {
    bool Function() isFullOfflineMode = _defaultIsFullOfflineMode,
  }) : _isFullOfflineMode = isFullOfflineMode;

  static bool _defaultIsFullOfflineMode() => false;

  final OfflinePdfRepository _repository;
  final FetchAndStorePdf _fetchAndStore;
  final bool Function() _isFullOfflineMode;

  /// Resolve [pdfId] para path absoluto local, baixando on-demand se necessário.
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    ProgressCallback? onProgress,
  }) async {
    final (entry, hasIndexEntry) =
        await _repository.lookupWithIndexState(pdfId);
    if (entry != null) {
      return LocalPdfSource(
        pdfId: pdfId,
        absolutePath: entry.absolutePath,
        fromCache: true,
      );
    }

    if (_isFullOfflineMode()) {
      if (hasIndexEntry) {
        throw PdfExternallyDeletedException(pdfId: pdfId);
      }
      throw PdfOfflineUnavailableException(pdfId: pdfId);
    }

    try {
      return await _fetchAndStore(
        pdfId: pdfId,
        remotePath: remotePath,
        onProgress: onProgress,
        persistentDownload: _isFullOfflineMode(),
      );
    } on DioException catch (e) {
      if (_isNetworkError(e)) {
        if (hasIndexEntry) {
          throw PdfExternallyDeletedException(pdfId: pdfId);
        }
        throw PdfOfflineUnavailableException(pdfId: pdfId);
      }
      throw PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: e,
      );
    } on PdfExternallyDeletedException {
      rethrow;
    } on PdfOfflineUnavailableException {
      rethrow;
    } on PdfFetchFailedException {
      rethrow;
    } on Object catch (e) {
      throw PdfFetchFailedException(
        'Falha ao baixar o PDF',
        cause: e,
      );
    }
  }

  static bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;
  }
}
