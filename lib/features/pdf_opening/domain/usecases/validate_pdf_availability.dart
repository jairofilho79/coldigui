import '../../../offline/domain/repositories/offline_pdf_repository.dart';
import '../entities/pdf_offline_availability.dart';

/// UC-04 — Validar disponibilidade offline do PDF (Fase 3.4).
///
/// Diferencia PDF permanente offline de cache LRU transitório via
/// [OfflinePdfRepository.findIndexEntry] — sem disparar download.
class ValidatePdfAvailability {
  const ValidatePdfAvailability(this._repository);

  final OfflinePdfRepository _repository;

  /// Classifica a disponibilidade offline de [pdfId] no índice Isar.
  Future<PdfOfflineAvailability> call({required String pdfId}) async {
    final entry = await _repository.findIndexEntry(pdfId);
    if (entry == null) return PdfOfflineAvailability.notAvailable;
    return entry.isPersistent
        ? PdfOfflineAvailability.persistentOffline
        : PdfOfflineAvailability.cachedLru;
  }

  /// `true` se o PDF está cacheado com arquivo válido no disco.
  Future<bool> isCachedOnDisk({required String pdfId}) async {
    return (await _repository.lookup(pdfId)) != null;
  }
}
