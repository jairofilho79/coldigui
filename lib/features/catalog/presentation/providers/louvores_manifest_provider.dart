import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/catalog_providers.dart';
import '../../domain/entities/louvor.dart';
import '../../domain/entities/louvores_manifest.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../../../core/database/isar_provider.dart';

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
    final isarAvailable = ref.watch(isarAvailableProvider);

    if (isarAvailable) {
      final cached = await repository.loadCachedLouvores();

      if (cached.isNotEmpty) {
        unawaited(_refreshFromRemote(cached));
        final isStale = await repository.isCatalogStale();
        return LouvoresManifest.fromLouvores(cached, isStale: isStale);
      }
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

  /// Revalida o catálogo em background reaproveitando [cached] (A1).
  ///
  /// O checksum salvo é enviado como `If-None-Match`: se nada mudou, o manifest
  /// não é baixado, o Isar não é reescrito (`clear()` + ~4600 `put`, síncronos na
  /// thread da UI na web) e **nenhum estado novo é emitido** — só o selo
  /// [LouvoresManifest.isStale] é reavaliado.
  Future<void> _refreshFromRemote(List<Louvor> cached) async {
    final repository = ref.read(catalogRepositoryProvider);

    final ManifestSyncOutcome outcome;
    try {
      final checksumStore = ref.read(manifestChecksumStoreProvider);
      final knownChecksum = await checksumStore.getLastKnownChecksum();

      outcome = await repository.syncManifest(
        cached: cached,
        knownChecksum: knownChecksum,
      );

      final checksum = outcome.checksum;
      if (checksum != null && checksum != knownChecksum) {
        await checksumStore.saveChecksum(checksum);
      }
    } on Object catch (error) {
      // Mantém cache em tela; erro silencioso no boot com rede parcial.
      debugPrint('[catalog] refresh em background falhou: $error');
      return;
    }

    final isStale = await repository.isCatalogStale();

    if (!outcome.cacheReplaced) {
      _updateStaleFlag(isStale);
      return;
    }

    state = AsyncData(
      LouvoresManifest.fromLouvores(outcome.louvores, isStale: isStale),
    );
  }

  /// Atualiza só o selo de catálogo desatualizado, reaproveitando o snapshot.
  ///
  /// Evita `LouvoresManifest.fromLouvores`, que varreria ~4600 louvores de novo
  /// para recomputar [LouvoresManifest.availableArranjos] sem nada ter mudado.
  void _updateStaleFlag(bool isStale) {
    final current = state.value;
    if (current == null || current.isStale == isStale) return;

    state = AsyncData(
      LouvoresManifest(
        louvores: current.louvores,
        availableArranjos: current.availableArranjos,
        isStale: isStale,
      ),
    );
  }
}
