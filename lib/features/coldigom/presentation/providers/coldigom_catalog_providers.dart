import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/offline_config.dart';
import '../../../../core/database/collections/coldigom_praise_cache.dart';
import '../../../../core/database/isar_provider.dart';
import '../../../../core/providers/device_connectivity_provider.dart';
import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../catalog/domain/entities/catalog_material.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/entities/youtube_material.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../../data/adapters/coldigom_louvor_adapter.dart';
import '../../data/mappers/coldigom_praise_cache_mapper.dart';
import '../../data/providers/coldigom_catalog_data_providers.dart';
import '../../data/providers/coldigom_providers.dart';
import '../../domain/entities/coldigom_praise_metadata.dart';
import '../../domain/search/coldigom_search_index.dart';
import '../../domain/usecases/sync_coldigom_catalog.dart';

export '../../domain/usecases/sync_coldigom_catalog.dart'
    show
        ColdigomCatalogSyncResult,
        ColdigomCatalogSyncReplaced,
        ColdigomCatalogSyncNoop,
        ColdigomCatalogSyncFailed,
        ColdigomCatalogSyncInMemory;

/// Catálogo baixado **sem Isar** (C6, spec fim-fonte §2.1): as linhas do
/// dump, só em memória — o contrato que o manifesto tinha. Vazio enquanto o
/// Isar existe (aí o catálogo vive no banco) e até o primeiro sync em
/// memória terminar.
final coldigomInMemoryCatalogProvider =
    NotifierProvider<
      ColdigomInMemoryCatalogNotifier,
      List<ColdigomPraiseCache>
    >(ColdigomInMemoryCatalogNotifier.new);

class ColdigomInMemoryCatalogNotifier
    extends Notifier<List<ColdigomPraiseCache>> {
  @override
  List<ColdigomPraiseCache> build() => const [];

  /// Troca o catálogo inteiro — desfecho [ColdigomCatalogSyncInMemory].
  void replace(List<ColdigomPraiseCache> rows) {
    state = List<ColdigomPraiseCache>.unmodifiable(rows);
  }
}

/// Hidrata os caches Coldigom em memória a partir do Isar **uma vez** (O4) e
/// devolve o índice de busca local.
///
/// Corre depois de o Isar assentar e fora do caminho crítico: a página
/// inicial e a /biblioteca mostram carregamento até o índice ter praises
/// (`catalogIndexStatusProvider`). A conversão é fatiada em
/// [OfflineConfig.coldigomHydrationChunkSize] praises com `await
/// Future.delayed(Duration.zero)` entre fatias — na web tudo corre na thread
/// de UI, e 2063 praises de uma vez atrasariam o primeiro frame.
///
/// Com Isar, lê o banco. Sem Isar (modo degradado), lê as linhas que o sync
/// baixou para [coldigomInMemoryCatalogProvider] (C6). Um sync que
/// substituiu o catálogo no Isar invalida este provider
/// ([ColdigomCatalogSyncNotifier]); o sync em memória troca as linhas
/// observadas.
///
/// Os caches por tipo (`coldigomLouvoresCacheProvider` e irmãos) só
/// **fundem**: um praise removido no servidor some do Isar e do índice novo
/// na próxima hidratação, mas a entrada antiga desses caches em memória
/// sobrevive até o app reiniciar — a Home nunca lê os caches direto, só o
/// índice (autoritativo), então isso não afeta a busca.
final coldigomCatalogHydrationProvider = FutureProvider<ColdigomSearchIndex>((
  ref,
) async {
  // Observado antes de qualquer `await`: sem Isar as linhas vêm do sync em
  // memória, e trocá-las re-hidrata sozinho.
  final memoryRows = ref.watch(coldigomInMemoryCatalogProvider);
  final List<ColdigomPraiseCache> rows;
  if (await awaitIsarSettled(ref) == IsarStatus.available) {
    rows = ref.read(coldigomCatalogLocalDatasourceProvider).findAllSync();
  } else {
    rows = memoryRows;
  }
  if (rows.isEmpty) return ColdigomSearchIndex.empty;

  final stopwatch = Stopwatch()..start();
  final louvores = <Louvor>[];
  final audioTracks = <AudioTrack>[];
  final chords = <ChordMaterial>[];
  final gestures = <GestureMaterial>[];
  final youtube = <YoutubeMaterial>[];
  final lyrics = <LyricsMaterial>[];
  final meta = <String, ColdigomPraiseMetadata>{};
  final entries = <ColdigomIndexedPraise>[];
  // Todo o Isar, não só quem entra no índice de busca — vira `catalogIds`
  // (ver doc do campo): um praise só-YouTube não sustenta grupo, mas já foi
  // adotado, e não pode continuar marcado «novo» na pesquisa remota.
  final catalogIds = <String>{};

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    catalogIds.add(row.praiseId);
    final detail = ColdigomPraiseCacheMapper.toPraiseDetail(row);
    final praiseLouvores = ColdigomLouvorAdapter.toLouvores(detail);
    final praiseTracks = ColdigomLouvorAdapter.toAudioTracks(detail);
    final praiseChords = ColdigomLouvorAdapter.toChordMaterials(detail);
    final praiseGestures = ColdigomLouvorAdapter.toGestureMaterials(detail);
    final praiseYoutube = ColdigomLouvorAdapter.toYoutubeMaterials(detail);
    final praiseLyrics = ColdigomLouvorAdapter.toLyricsMaterial(
      detail,
      row.lyrics,
    );
    final praiseMeta = ColdigomLouvorAdapter.toMetadata(detail);

    louvores.addAll(praiseLouvores);
    audioTracks.addAll(praiseTracks);
    chords.addAll(praiseChords);
    gestures.addAll(praiseGestures);
    youtube.addAll(praiseYoutube);
    if (praiseLyrics != null) lyrics.add(praiseLyrics);
    meta[row.praiseId] = praiseMeta;

    // Um praise sem material endereçável (nem PDF, nem áudio, nem cifra, nem
    // gesto, nem letra) não sustenta um grupo — mesma checagem de
    // `ColdigomCatalogSource.findGroupById`. YouTube sozinho não conta:
    // `LouvorGroup.fromLouvores` monta grupo a partir de `youtubeByGroup`
    // também, então sem este `if` explícito um praise só-YouTube entraria no
    // índice (card sem PDF/áudio/cifra/gesto/letra para abrir) mesmo
    // `findGroupById` devolvendo `null` para o mesmo id.
    final hasAddressableMaterial =
        praiseLouvores.isNotEmpty ||
        praiseTracks.isNotEmpty ||
        praiseChords.isNotEmpty ||
        praiseGestures.isNotEmpty ||
        praiseLyrics != null;
    if (hasAddressableMaterial) {
      final groups = LouvorGroup.fromLouvores(
        praiseLouvores,
        audioTracks: praiseTracks,
        chordMaterials: praiseChords,
        gestureMaterials: praiseGestures,
        youtubeMaterials: praiseYoutube,
        lyricsByGroupId: praiseLyrics == null
            ? null
            : {row.praiseId: praiseLyrics},
        coldigomMetaByGroupId: {row.praiseId: praiseMeta},
      );
      final group = groups.where((g) => g.groupId == row.praiseId).firstOrNull;
      if (group != null) {
        entries.add(
          ColdigomIndexedPraise.build(
            praiseId: row.praiseId,
            numero: row.number,
            nome: row.name,
            searchTokens: row.searchTokens,
            group: group,
          ),
        );
      }
    }

    if ((i + 1) % OfflineConfig.coldigomHydrationChunkSize == 0) {
      await Future<void>.delayed(Duration.zero);
      if (!ref.mounted) return ColdigomSearchIndex.empty;
    }
  }

  ref
      .read(coldigomCacheWriterProvider)
      .mergeCatalog(
        louvores: louvores,
        audioTracks: audioTracks,
        chordMaterials: chords,
        gestureMaterials: gestures,
        youtubeMaterials: youtube,
        lyrics: lyrics,
        metaByGroupId: meta,
      );
  debugPrint(
    '[coldigom] catálogo hidratado: ${rows.length} praises em '
    '${stopwatch.elapsedMilliseconds} ms',
  );
  return ColdigomSearchIndex.build(entries, catalogIds: catalogIds);
});

/// Índice de busca local Coldigom — vazio até a hidratação terminar.
final coldigomSearchIndexProvider = Provider<ColdigomSearchIndex>((ref) {
  return ref.watch(coldigomCatalogHydrationProvider).value ??
      ColdigomSearchIndex.empty;
});

/// Estado do sync do catálogo Coldigom — a linha «Catálogo: N louvores ·
/// atualizado há …» do `/offline` lê daqui.
class ColdigomCatalogSyncState {
  const ColdigomCatalogSyncState({
    this.isSyncing = false,
    this.lastResult,
    this.lastSyncedAt,
    this.count = 0,
  });

  final bool isSyncing;
  final ColdigomCatalogSyncResult? lastResult;
  final DateTime? lastSyncedAt;
  final int count;

  ColdigomCatalogSyncState copyWith({
    bool? isSyncing,
    ColdigomCatalogSyncResult? lastResult,
    DateTime? lastSyncedAt,
    int? count,
  }) {
    return ColdigomCatalogSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastResult: lastResult ?? this.lastResult,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      count: count ?? this.count,
    );
  }
}

/// Orquestra [SyncColdigomCatalog] (O5): boot com rede, foreground com ≥ 30
/// min, pedido explícito («Atualizar» no `/offline`, «novo» na pesquisa).
final coldigomCatalogSyncProvider =
    NotifierProvider<ColdigomCatalogSyncNotifier, ColdigomCatalogSyncState>(
      ColdigomCatalogSyncNotifier.new,
    );

class ColdigomCatalogSyncNotifier extends Notifier<ColdigomCatalogSyncState> {
  Future<ColdigomCatalogSyncResult>? _inFlight;

  @override
  ColdigomCatalogSyncState build() {
    final metadata = ref.read(coldigomCatalogSyncMetadataStoreProvider);
    // Boot: sem bloquear ninguém — e sem repetir o pedido se o último sync
    // foi há pouco (o app pode reabrir muitas vezes).
    unawaited(Future<void>.microtask(requestSyncIfStale));
    return ColdigomCatalogSyncState(
      lastSyncedAt: metadata.readSyncedAt(),
      count: metadata.readCount(),
    );
  }

  /// Sync incondicional, deduplicado: um segundo pedido durante um em voo
  /// recebe o mesmo future.
  Future<ColdigomCatalogSyncResult> sync() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _run();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  /// Sync depois de uma adoção pontual (§6.2, `homeRemoteSearchProvider`).
  ///
  /// Um praise adotado no Isar só sai da lista «novo» quando o índice em
  /// memória re-hidrata — e isso só acontece sozinho quando [sync] devolve
  /// [ColdigomCatalogSyncReplaced]. Três caminhos reais nunca chegam lá: 304
  /// (`ColdigomCatalogSyncNoop`, ETag não mudou), falha de sync, e praise
  /// só-YouTube (fica fora do índice de busca mesmo depois de hidratar — mas
  /// entra em `catalogIds`, ver `ColdigomSearchIndex`). Nesses três casos as
  /// linhas adotadas já estão no Isar; só falta reler.
  Future<void> syncAfterAdoption() async {
    final result = await sync();
    if (result is! ColdigomCatalogSyncReplaced && ref.mounted) {
      ref.invalidate(coldigomCatalogHydrationProvider);
    }
  }

  /// Sync só quando o último foi há ≥ [OfflineConfig.coldigomCatalogSyncMinInterval]
  /// (ou nunca, ou não há catálogo) **e** há rede.
  ///
  /// Espera o Isar assentar: é ele que decide entre o catálogo gravado (ETag
  /// e `syncedAt` nas prefs) e o catálogo só em memória (C6), que não
  /// sobrevive ao reinício e por isso ignora o `syncedAt` das prefs. Sem
  /// catálogo e sem rede grava a falha: é o que faz a página inicial e a
  /// /biblioteca trocarem o carregamento por erro + «tentar de novo».
  Future<void> requestSyncIfStale() async {
    final status = await awaitIsarSettled(ref);
    // Este pedido pode nascer como microtask de `build()`: se o container já
    // foi descartado nesse meio-tempo (fim de um teste, navegação que
    // desmonta o shell), `ref` não serve mais.
    if (!ref.mounted) return;
    final inMemory = status != IsarStatus.available;
    if (_hasFreshCatalog(inMemory: inMemory)) return;
    final hasConnection = await ref
        .read(deviceConnectivityProvider)
        .hasConnection();
    if (!ref.mounted) return;
    if (!hasConnection) {
      // Um sync concorrente pode ter enchido o catálogo durante os awaits.
      if (_inFlight == null && !_hasCatalog(inMemory: inMemory)) {
        state = state.copyWith(
          lastResult: const ColdigomCatalogSyncFailed('sem rede'),
        );
      }
      return;
    }
    await sync();
  }

  /// Há catálogo local? Com Isar conta as linhas (já assentado: a leitura
  /// síncrona é segura); uma leitura que falhe conta como «não há».
  bool _hasCatalog({required bool inMemory}) {
    if (inMemory) return ref.read(coldigomInMemoryCatalogProvider).isNotEmpty;
    try {
      return ref.read(coldigomCatalogLocalDatasourceProvider).count() > 0;
    } on Object {
      return false;
    }
  }

  bool _hasFreshCatalog({required bool inMemory}) {
    if (!_hasCatalog(inMemory: inMemory)) return false;
    final syncedAt = inMemory
        ? state.lastSyncedAt
        : ref.read(coldigomCatalogSyncMetadataStoreProvider).readSyncedAt();
    return syncedAt != null &&
        DateTime.now().toUtc().difference(syncedAt) <
            OfflineConfig.coldigomCatalogSyncMinInterval;
  }

  Future<ColdigomCatalogSyncResult> _run() async {
    // O shell monta (e o boot agenda `requestSyncIfStale`) enquanto o Isar
    // ainda pode estar abrindo. Sincronizar antes disso faria o use case ver
    // o datasource `.unavailable()` e tratar um catálogo bom, só ainda não
    // aberto, como ausente. Espera o Isar assentar; sem ele, o dump vai para
    // a memória (C6).
    await awaitIsarSettled(ref);
    if (!ref.mounted) return const ColdigomCatalogSyncFailed('descartado');
    state = state.copyWith(isSyncing: true);
    final result = await ref.read(syncColdigomCatalogProvider).run();
    if (!ref.mounted) return result;
    if (result is ColdigomCatalogSyncInMemory) {
      // Nada gravado: o índice re-hidrata porque observa estas linhas.
      ref.read(coldigomInMemoryCatalogProvider.notifier).replace(result.rows);
      state = state.copyWith(
        isSyncing: false,
        lastResult: result,
        lastSyncedAt: DateTime.now().toUtc(),
        count: result.count,
      );
      return result;
    }
    final metadata = ref.read(coldigomCatalogSyncMetadataStoreProvider);
    state = state.copyWith(
      isSyncing: false,
      lastResult: result,
      lastSyncedAt: metadata.readSyncedAt(),
      count: metadata.readCount(),
    );
    if (result is ColdigomCatalogSyncReplaced) {
      // O Isar mudou por baixo dos caches: re-hidrata (o índice novo troca
      // a lista local sem tocar em quem já leu `groupById`).
      ref.invalidate(coldigomCatalogHydrationProvider);
    }
    return result;
  }
}
