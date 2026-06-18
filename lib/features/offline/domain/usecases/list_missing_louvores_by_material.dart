import '../../../catalog/data/datasources/catalog_local_datasource.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/utils/louvor_numero_normalizer.dart';
import '../repositories/offline_pdf_repository.dart';
import '../utils/offline_material_resolver.dart';

/// UC-10 — Lista louvores do catálogo local sem PDF offline válido (Fase 3.7).
///
/// Usa [OfflinePdfRepository.lookupBatch] — mesma regra de “faltante” que
/// [DownloadMissingPdfs].
class ListMissingLouvoresByMaterial {
  const ListMissingLouvoresByMaterial(
    this._catalogLocal,
    this._repository,
  );

  final CatalogLocalDatasource _catalogLocal;
  final OfflinePdfRepository _repository;

  Future<List<Louvor>> call(String materialCategory) async {
    final louvores = await _catalogLocal.loadLouvores();
    final materialLouvores = <Louvor>[
      for (final louvor in louvores)
        if (OfflineMaterialResolver.toUiMaterial(louvor.categoria) ==
            materialCategory)
          louvor,
    ];

    if (materialLouvores.isEmpty) return const [];

    final pdfIds = materialLouvores.map((l) => l.pdfId).toSet();
    final validPdfIds = await _repository.lookupBatch(pdfIds);

    final missing = [
      for (final louvor in materialLouvores)
        if (!validPdfIds.contains(louvor.pdfId)) louvor,
    ]..sort(_compareLouvores);

    return missing;
  }

  static int _compareLouvores(Louvor a, Louvor b) {
    final na = LouvorNumeroNormalizer.normalize(a.numero);
    final nb = LouvorNumeroNormalizer.normalize(b.numero);
    final cmp = na.compareTo(nb);
    if (cmp != 0) return cmp;
    return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
  }
}
