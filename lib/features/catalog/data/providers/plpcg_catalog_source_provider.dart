import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/search/plpcg_search_index.dart';
import '../../presentation/providers/louvores_manifest_provider.dart';
import '../sources/plpcg_catalog_source.dart';

/// Fonte PLPCG **estável** — observa só o manifest.
///
/// É por isso que ela mora num provider próprio: o índice de busca custa uma
/// varredura dos ~4600 louvores, e o `catalogSourceProvider` antigo recompunha
/// tudo a cada merge de cache Coldigom (uma vez por página de busca). Aqui a
/// instância — e o índice dentro dela — sobrevive às páginas Coldigom e só
/// muda quando a lista de louvores do manifest muda.
final plpcgCatalogSourceProvider = Provider<PlpcgCatalogSource>((ref) {
  final louvores = ref.watch(
    louvoresManifestProvider.select((manifest) => manifest.value?.louvores),
  );
  if (louvores == null) return const PlpcgCatalogSource();
  return PlpcgCatalogSource(
    catalog: louvores,
    index: PlpcgSearchIndex.build(louvores),
  );
});
