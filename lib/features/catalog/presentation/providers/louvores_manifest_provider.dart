import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/catalog_providers.dart';
import '../../domain/entities/louvor.dart';

/// Estado async do manifest carregado no boot da aplicação (UC-12).
///
/// Disparado via `ref.listen` em [ColdiguiApp] (evita rebuild do router ao concluir
/// ~4600 itens); consumido por [homeSearchResultsProvider] e demais `ref.watch`.
final louvoresManifestProvider = FutureProvider<List<Louvor>>((ref) async {
  final loadManifest = ref.watch(loadLouvoresManifestProvider);
  return loadManifest();
});
