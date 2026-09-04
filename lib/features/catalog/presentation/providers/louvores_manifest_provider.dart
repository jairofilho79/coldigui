import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../data/datasources/manifest_checksum_store.dart';
import '../../data/providers/catalog_providers.dart';
import '../../domain/entities/louvor.dart';
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

  /// Boot frio (sem cache) — baixa o manifest inteiro e **guarda o checksum**.
  ///
  /// Passa por `syncManifest` em vez do download direto só
  /// para não descartar `outcome.checksum` (A3): sem ele o `If-None-Match` só
  /// entraria em cena no terceiro boot, porque o segundo ainda não teria
  /// checksum salvo para enviar.
  Future<LouvoresManifest> _loadFromRemote() async {
    final repository = ref.read(catalogRepositoryProvider);
    final checksumStore = ref.read(manifestChecksumStoreProvider);
    final knownChecksum = await checksumStore.getLastKnownChecksum();

    final outcome = await repository.syncManifest(
      cached: const [],
      knownChecksum: knownChecksum,
    );

    await _persistChecksum(checksumStore, outcome.checksum, knownChecksum);

    final isStale = await repository.isCatalogStale();
    return LouvoresManifest.fromLouvores(outcome.louvores, isStale: isStale);
  }

  /// Revalida o catálogo em background reaproveitando [cached] (A1).
  ///
  /// O checksum salvo é enviado como `If-None-Match`: se nada mudou, o manifest
  /// não é baixado, o Isar não é reescrito (`clear()` + ~4600 `put`, síncronos na
  /// thread da UI na web) e **nenhum estado novo é emitido** — só o selo
  /// [LouvoresManifest.isStale] é reavaliado.
  ///
  /// A chamada é `unawaited`, então **todo** o corpo fica dentro do `try` e cada
  /// retomada depois de um `await` confere [Ref.mounted]: o notifier é
  /// descartado quando `isarAvailableProvider` vira, e escrever `state` depois
  /// disso lança no Riverpod 3 sem ninguém para pegar o erro (A2).
  Future<void> _refreshFromRemote(List<Louvor> cached) async {
    final repository = ref.read(catalogRepositoryProvider);

    try {
      final checksumStore = ref.read(manifestChecksumStoreProvider);
      final knownChecksum = await checksumStore.getLastKnownChecksum();
      if (!ref.mounted) return;

      final outcome = await repository.syncManifest(
        cached: cached,
        knownChecksum: knownChecksum,
      );
      if (!ref.mounted) return;

      await _persistChecksum(checksumStore, outcome.checksum, knownChecksum);
      if (!ref.mounted) return;

      final isStale = await repository.isCatalogStale();
      if (!ref.mounted) return;

      if (!outcome.cacheReplaced) {
        _updateStaleFlag(isStale);
        return;
      }

      state = AsyncData(
        LouvoresManifest.fromLouvores(outcome.louvores, isStale: isStale),
      );
    } on Object catch (error) {
      // Mantém cache em tela; erro silencioso no boot com rede parcial.
      debugPrint('[catalog] refresh em background falhou: $error');
    }
  }

  /// Grava o checksum do manifest recém-aceito, pulando regravação idêntica.
  Future<void> _persistChecksum(
    ManifestChecksumStore store,
    String? checksum,
    String? knownChecksum,
  ) async {
    if (checksum == null || checksum == knownChecksum) return;
    await store.saveChecksum(checksum);
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
