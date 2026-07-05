import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/catalog_providers.dart';
import '../../domain/entities/louvores_manifest.dart';

/// Estado async do manifest carregado no boot da aplicação (UC-12).
///
/// Disparado via `ref.listen` em [ColdiguiApp] (evita rebuild do router ao concluir
/// ~4600 itens); consumido por [homeSearchGroupResultsProvider] e demais `ref.watch`.
/// [LouvoresManifest.availableArranjos] é pré-computado no carregamento (UC-02).
///
/// Cache-first (Fase G): retorna Isar imediatamente quando disponível e
/// sincroniza com a rede em background sem voltar a `loading`.
final louvoresManifestProvider =
    AsyncNotifierProvider<LouvoresManifestNotifier, LouvoresManifest>(
      LouvoresManifestNotifier.new,
    );

/// Carrega manifest cache-first com refresh remoto em background.
class LouvoresManifestNotifier extends AsyncNotifier<LouvoresManifest> {
  @override
  Future<LouvoresManifest> build() async {
    final repository = ref.watch(catalogRepositoryProvider);
    final cached = await repository.loadCachedLouvores();

    if (cached.isNotEmpty) {
      unawaited(_refreshFromRemote());
      final isStale = await repository.isCatalogStale();
      return LouvoresManifest.fromLouvores(cached, isStale: isStale);
    }

    return _loadFromRemote();
  }

  Future<LouvoresManifest> _loadFromRemote() async {
    final repository = ref.read(catalogRepositoryProvider);
    final loadManifest = ref.read(loadLouvoresManifestProvider);
    final louvores = await loadManifest();
    final isStale = await repository.isCatalogStale();
    return LouvoresManifest.fromLouvores(louvores, isStale: isStale);
  }

  Future<void> _refreshFromRemote() async {
    try {
      final repository = ref.read(catalogRepositoryProvider);
      final loadManifest = ref.read(loadLouvoresManifestProvider);
      final louvores = await loadManifest();
      final isStale = await repository.isCatalogStale();
      state = AsyncData(
        LouvoresManifest.fromLouvores(louvores, isStale: isStale),
      );
    } on Object {
      // Mantém cache em tela; erro silencioso no boot com rede parcial.
    }
  }
}
