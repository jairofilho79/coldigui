import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/louvor.dart';
import 'louvores_manifest_provider.dart';

/// `pdfId → Louvor` do manifest PLPCG, construído **uma vez por manifest** (A4).
///
/// Substitui os mapas O(catálogo) refeitos a cada mutação do carousel/lista
/// (`buildCarouselMetadataMap`, `PlaylistsNotifier._buildLabelMap`,
/// `findLouvorByPdfId`). Vazio enquanto o manifest não carregou. A instância
/// só muda quando a lista de louvores do manifest muda — leituras
/// consecutivas devolvem o mesmo mapa.
final louvoresByPdfIdProvider = Provider<Map<String, Louvor>>((ref) {
  final louvores = ref.watch(
    louvoresManifestProvider.select((manifest) => manifest.value?.louvores),
  );
  if (louvores == null) return const {};
  return Map<String, Louvor>.unmodifiable({
    for (final louvor in louvores) louvor.pdfId: louvor,
  });
});
