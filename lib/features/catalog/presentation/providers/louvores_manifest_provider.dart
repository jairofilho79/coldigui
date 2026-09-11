import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_provider.dart';
import '../../data/datasources/manifest_checksum_store.dart';
import '../../data/providers/catalog_providers.dart';
import '../../domain/entities/louvor.dart';
import '../../domain/entities/louvores_manifest.dart';
import '../../domain/repositories/catalog_repository.dart';

/// Estado async do manifest carregado no boot da aplicação (UC-12).
///
/// Disparado via `ref.listen` em [ColdiguiApp] (evita rebuild do router ao concluir
/// ~4600 itens); consumido por `plpcgCatalogSourceProvider` e demais `ref.watch`.
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
  /// Boot com o Isar ainda abrindo: rede e abertura em paralelo (A8).
  ///
  /// `BootstrapApp` passou a montar o app durante [IsarStatus.opening], então
  /// `build()` roda enquanto o WASM + OPFS ainda abre (até `isarOpenTimeout`).
  /// Em vez de decidir cache-first já — o que jogaria todo boot web frio no
  /// download completo mesmo tendo cache — dispara o `GET /api/catalog/checksum`
  /// na hora e só então espera a abertura terminar. O checksum volta de graça
  /// junto com a espera e ainda diz se o catálogo mudou.
  ///
  /// Nada de `watch` antes da espera. `catalogRepositoryProvider` depende de
  /// `optionalIsarProvider` (o datasource local sai de `unavailable()` quando o
  /// Isar abre) e `isarStatusProvider` muda junto: observar qualquer um dos
  /// dois aqui reconstruiria o notifier no exato instante em que a abertura
  /// termina, e o boot baixaria o manifest duas vezes. A dependência de rebuild
  /// fica em `isarInitializerProvider.future`, que só troca quando alguém
  /// invalida o provider (o "tentar novamente" do `StorageRequiredGate`), e o
  /// repositório é observado depois — já com o Isar no lugar.
  @override
  Future<LouvoresManifest> build() async {
    var status = ref.read(isarStatusProvider);
    final isarSettled = ref.watch(isarInitializerProvider.future);

    Future<String?>? bootChecksum;

    if (status == IsarStatus.opening) {
      bootChecksum = _prefetchChecksum(ref.read(catalogRepositoryProvider));
      try {
        await isarSettled;
        status = IsarStatus.available;
      } on Object catch (error) {
        debugPrint('[catalog] Isar não abriu no boot: $error');
        status = IsarStatus.unavailable;
      }
    } else {
      // Em modo degradado `isarSettled` já falhou; sem este dreno o erro
      // ficaria sem dono e viraria exceção assíncrona não tratada.
      unawaited(isarSettled.then((_) {}, onError: (Object _, StackTrace _) {}));
    }

    final repository = ref.watch(catalogRepositoryProvider);

    if (status == IsarStatus.available) {
      final cached = await repository.loadCachedLouvores();

      if (cached.isNotEmpty) {
        unawaited(_refreshFromRemote(cached, bootChecksum: bootChecksum));
        final isStale = await repository.isCatalogStale();
        return LouvoresManifest.fromLouvores(cached, isStale: isStale);
      }
    }

    return _loadFromRemote(bootChecksum: bootChecksum);
  }

  /// Dispara o `GET /api/catalog/checksum` do boot sem deixar o erro solto.
  ///
  /// A falha vira `null` de propósito — o prefetch é só uma otimização. Quem
  /// realmente precisa da rede é `syncManifest`, que trata a queda logo abaixo.
  Future<String?> _prefetchChecksum(CatalogRepository repository) {
    return repository.fetchManifestChecksum().then<String?>(
      (checksum) => checksum,
      onError: (Object error, StackTrace _) {
        debugPrint('[catalog] checksum do boot falhou: $error');
        return null;
      },
    );
  }

  /// Boot frio (sem cache) — baixa o manifest inteiro e **guarda o checksum**.
  ///
  /// Passa por `syncManifest` em vez do download direto só
  /// para não descartar `outcome.checksum` (A3): sem ele o `If-None-Match` só
  /// entraria em cena no terceiro boot, porque o segundo ainda não teria
  /// checksum salvo para enviar.
  Future<LouvoresManifest> _loadFromRemote({
    Future<String?>? bootChecksum,
  }) async {
    final repository = ref.read(catalogRepositoryProvider);
    final checksumStore = ref.read(manifestChecksumStoreProvider);
    final knownChecksum = await checksumStore.getLastKnownChecksum();

    final outcome = await repository.syncManifest(
      cached: const [],
      knownChecksum: knownChecksum,
    );

    // `cached` vazio desliga o `If-None-Match`, então `syncManifest` só devolve
    // checksum quando o corpo trouxe `ETag`; o checksum do boot cobre o resto —
    // mas só quando o manifest realmente entrou no cache. Um corpo vazio
    // (`cacheReplaced: false`) não pode armar o gate condicional.
    final checksum =
        outcome.checksum ?? (outcome.cacheReplaced ? await bootChecksum : null);
    await _persistChecksum(checksumStore, checksum, knownChecksum);

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
  /// descartado quando `catalogRepositoryProvider` troca (o datasource local
  /// muda ao Isar abrir), e escrever `state` depois disso lança no Riverpod 3
  /// sem ninguém para pegar o erro (A2).
  Future<void> _refreshFromRemote(
    List<Louvor> cached, {
    Future<String?>? bootChecksum,
  }) async {
    final repository = ref.read(catalogRepositoryProvider);

    try {
      final checksumStore = ref.read(manifestChecksumStoreProvider);
      final knownChecksum = await checksumStore.getLastKnownChecksum();
      if (!ref.mounted) return;

      // O checksum pedido durante a abertura do Isar (A8) já responde a
      // pergunta do `If-None-Match`: quando ele difere do salvo, o catálogo
      // mudou e mandar o condicional de novo só custaria um round-trip antes
      // do download. Quando é igual (ou não veio), `syncManifest` segue com o
      // gate condicional de sempre — é ele que marca o catálogo como sincado.
      final booted = await bootChecksum;
      if (!ref.mounted) return;
      final knownIsOutdated =
          booted != null && knownChecksum != null && booted != knownChecksum;

      final outcome = await repository.syncManifest(
        cached: cached,
        knownChecksum: knownIsOutdated ? null : knownChecksum,
      );
      if (!ref.mounted) return;

      // Mesma precedência de `CatalogRepositoryImpl`: `ETag` do corpo primeiro,
      // checksum avulso só como reserva — e **só** se o corpo realmente entrou.
      // `syncManifest` engole falha de rede e devolve o cache com
      // `cacheReplaced: false` e `checksum: null`; gravar o checksum do boot aí
      // congelaria o catálogo, porque o próximo boot mandaria esse valor no
      // `If-None-Match` e ouviria "nada mudou" para um corpo que nunca chegou.
      final bootFallback = knownIsOutdated && outcome.cacheReplaced
          ? booted
          : null;
      await _persistChecksum(
        checksumStore,
        outcome.checksum ?? bootFallback,
        knownChecksum,
      );
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
