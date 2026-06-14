import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/catalog_providers.dart';
import '../../domain/entities/louvores_manifest.dart';

/// Estado async do manifest carregado no boot da aplicação (UC-12).
///
/// Disparado via `ref.listen` em [ColdiguiApp] (evita rebuild do router ao concluir
/// ~4600 itens); consumido por [homeSearchGroupResultsProvider] e demais `ref.watch`.
/// [LouvoresManifest.availableArranjos] é pré-computado no carregamento (UC-02).
final louvoresManifestProvider = FutureProvider<LouvoresManifest>((ref) async {
  final repository = ref.watch(catalogRepositoryProvider);
  final loadManifest = ref.watch(loadLouvoresManifestProvider);
  final louvores = await loadManifest();
  final isStale = await repository.isCatalogStale();
  return LouvoresManifest.fromLouvores(louvores, isStale: isStale);
});
