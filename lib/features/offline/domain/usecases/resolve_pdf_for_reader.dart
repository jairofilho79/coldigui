import 'package:dio/dio.dart';

import '../entities/local_pdf_source.dart';
import '../exceptions/pdf_resolve_exceptions.dart';
import '../repositories/offline_pdf_repository.dart';
import 'fetch_and_store_pdf.dart';

/// Resolver local-first — lookup O(1) + fetch on miss (Fase 3.2).
///
/// Hit → path absoluto local; miss → delega [FetchAndStorePdf]; falha de rede
/// → exceção tipada conforme índice órfão ou ausente.
class ResolvePdfForReader {
  const ResolvePdfForReader(this._repository, this._fetchAndStore);

  final OfflinePdfRepository _repository;
  final FetchAndStorePdf _fetchAndStore;

  /// Resolve [pdfId] para path absoluto local, baixando on-demand se necessário.
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
  }) async {
    final entry = await _repository.lookup(pdfId);
    if (entry != null) {
      return LocalPdfSource(
        pdfId: pdfId,
        absolutePath: entry.absolutePath,
        fromCache: true,
      );
    }

    final hasStaleIndex = await _repository.findIndexEntry(pdfId) != null;

    try {
      return await _fetchAndStore(
        pdfId: pdfId,
        remotePath: remotePath,
      );
    } on DioException catch (e) {
      if (_isNetworkError(e)) {
        if (hasStaleIndex) {
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
