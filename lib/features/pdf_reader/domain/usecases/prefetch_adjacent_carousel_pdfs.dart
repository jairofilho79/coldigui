import '../../../catalog/domain/entities/louvor.dart';
import '../../../offline/domain/usecases/resolve_pdf_for_reader.dart';
import '../../../pdf_opening/domain/usecases/validate_pdf_availability.dart';
import '../../../pdf_opening/domain/utils/louvor_pdf_path.dart';
import '../ports/prefetch_network_policy.dart';

/// Resolve o [Louvor] de um `pdfId` (manifest, cache Coldigom ou alias).
typedef PrefetchLouvorResolver = Louvor? Function(String pdfId);

/// Prefetch fire-and-forget dos PDFs adjacentes no carousel in-reader (#8).
class PrefetchAdjacentCarouselPdfs {
  const PrefetchAdjacentCarouselPdfs({
    required this._validateAvailability,
    required this._resolvePdf,
    required this._networkPolicy,
  });

  final ValidatePdfAvailability _validateAvailability;
  final ResolvePdfForReader _resolvePdf;
  final PrefetchNetworkPolicy _networkPolicy;

  /// Dispara resolve para vizinhos ainda não cacheados; erros são ignorados.
  ///
  /// Os vizinhos chegam como **materialId** (o id de uma entrada da lista
  /// ativa): quem chama já resolveu qual ocorrência é a corrente.
  ///
  /// [resolveLouvor] responde pelo id — em produção é o lookup com alias
  /// (`CatalogMaterialLookup.louvor`), para uma entrada com id Coldigom de
  /// material coberto pelo manifest também ganhar prefetch com cache frio.
  Future<void> call({
    required PrefetchLouvorResolver resolveLouvor,
    required String? previousMaterialId,
    required String? nextMaterialId,
  }) async {
    if (!await _networkPolicy.allowsAdjacentPdfPrefetch()) return;

    for (final pdfId in [previousMaterialId, nextMaterialId]) {
      if (pdfId == null) continue;
      if (await _validateAvailability.isCachedOnDisk(pdfId: pdfId)) continue;

      final louvor = resolveLouvor(pdfId);
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
