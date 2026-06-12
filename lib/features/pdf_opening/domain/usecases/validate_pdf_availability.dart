import '../../../offline/domain/repositories/offline_pdf_repository.dart';

/// UC-04 — Validar disponibilidade offline do PDF (Fase 3.4).
///
/// Alias fino sobre [OfflinePdfRepository.lookup]: retorna `true` se o PDF está
/// no índice Isar e o arquivo no disco é válido, **sem** disparar download.
class ValidatePdfAvailability {
  const ValidatePdfAvailability(this._repository);

  final OfflinePdfRepository _repository;

  /// Verifica se [pdfId] está cacheado com arquivo válido no disco.
  ///
  /// Não dispara download — apenas delega a [OfflinePdfRepository.lookup].
  Future<bool> call({required String pdfId}) async {
    return (await _repository.lookup(pdfId)) != null;
  }
}
