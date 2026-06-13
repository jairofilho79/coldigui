import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/utils/find_louvor_by_pdf_id.dart';
import '../../../offline/domain/usecases/resolve_pdf_for_reader.dart';
import '../../../pdf_opening/domain/usecases/validate_pdf_availability.dart';
import '../../../pdf_opening/domain/utils/louvor_pdf_path.dart';
import '../ports/prefetch_network_policy.dart';

/// Prefetch fire-and-forget dos PDFs adjacentes no carousel in-reader (#8).
class PrefetchAdjacentCarouselPdfs {
  const PrefetchAdjacentCarouselPdfs({
    required ValidatePdfAvailability validateAvailability,
    required ResolvePdfForReader resolvePdf,
    required PrefetchNetworkPolicy networkPolicy,
  })  : _validateAvailability = validateAvailability,
        _resolvePdf = resolvePdf,
        _networkPolicy = networkPolicy;

  final ValidatePdfAvailability _validateAvailability;
  final ResolvePdfForReader _resolvePdf;
  final PrefetchNetworkPolicy _networkPolicy;

  /// Dispara resolve para vizinhos ainda não cacheados; erros são ignorados.
  Future<void> call({
    required List<Louvor>? catalog,
    required String? previousPdfId,
    required String? nextPdfId,
  }) async {
    if (!await _networkPolicy.allowsAdjacentPdfPrefetch()) return;

    for (final pdfId in [previousPdfId, nextPdfId]) {
      if (pdfId == null) continue;
      if (await _validateAvailability(pdfId: pdfId)) continue;

      final louvor = findLouvorByPdfId(catalog, pdfId);
      if (louvor == null) continue;

      await _prefetchLouvor(louvor);
    }
  }

  Future<void> _prefetchLouvor(Louvor louvor) async {
    try {
      await _resolvePdf(
        pdfId: louvor.pdfId,
        remotePath: LouvorPdfPath.fromLouvor(louvor),
      );
    } on Object {
      // Fire-and-forget — falhas de rede não afetam o PDF atual.
    }
  }
}
