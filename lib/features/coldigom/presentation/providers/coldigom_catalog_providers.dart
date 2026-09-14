import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/offline_config.dart';
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
        ColdigomCatalogSyncFailed;

/// Hidrata os caches Coldigom em memória a partir do Isar **uma vez** (O4) e
/// devolve o índice de busca local.
///
/// Corre depois de o Isar abrir e fora do caminho crítico: a Home não espera
/// por isto (o PLPCG aparece primeiro, como hoje). A conversão é fatiada em
/// [OfflineConfig.coldigomHydrationChunkSize] praises com `await
/// Future.delayed(Duration.zero)` entre fatias — na web tudo corre na thread
/// de UI, e 1690 praises de uma vez atrasariam o primeiro frame.
///
/// Sem Isar (modo degradado) devolve [ColdigomSearchIndex.empty]. Um sync
/// que substituiu o catálogo invalida este provider ([ColdigomCatalogSyncNotifier]).
final coldigomCatalogHydrationProvider = FutureProvider<ColdigomSearchIndex>((
  ref,
) async {
  if (await awaitIsarSettled(ref) != IsarStatus.available) {
    return ColdigomSearchIndex.empty;
  }
  final rows = ref.read(coldigomCatalogLocalDatasourceProvider).findAllSync();
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

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
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
    // Um praise sem material endereçável (só YouTube, ou nada) não sustenta
    // um grupo — mesma regra de `ColdigomCatalogSource.findGroupById`.
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

    if ((i + 1) % OfflineConfig.coldigomHydrationChunkSize == 0) {
      await Future<void>.delayed(Duration.zero);
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
  return ColdigomSearchIndex.build(entries);
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
    // Boot: em paralelo ao PLPCG, sem bloquear ninguém — e sem repetir o
    // pedido se o último sync foi há pouco (o app pode reabrir muitas vezes).
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

  /// Sync só quando o último foi há ≥ [OfflineConfig.coldigomCatalogSyncMinInterval]
  /// (ou nunca) **e** há rede. Sem rede fica o que está.
  Future<void> requestSyncIfStale() async {
    final metadata = ref.read(coldigomCatalogSyncMetadataStoreProvider);
    final syncedAt = metadata.readSyncedAt();
    // `metadata.readCount()` (SharedPreferences) em vez de consultar o Isar:
    // fica disponível de imediato, mesmo com o Isar ainda `opening` no boot
    // (a leitura síncrona de `count()` degradaria para 0 nesse instante e
    // pediria sync à toa a cada abertura do app).
    final hasCatalog = metadata.readCount() > 0;
    if (hasCatalog &&
        syncedAt != null &&
        DateTime.now().toUtc().difference(syncedAt) <
            OfflineConfig.coldigomCatalogSyncMinInterval) {
      return;
    }
    final hasConnection = await ref
        .read(deviceConnectivityProvider)
        .hasConnection();
    // Este pedido pode nascer como microtask de `build()`: se o container já
    // foi descartado nesse meio-tempo (fim de um teste, navegação que
    // desmonta o shell), `ref` não serve mais — mesma guarda do sync de
    // favoritos (`MaterialKindPrefsSyncNotifier`).
    if (!ref.mounted || !hasConnection) return;
    await sync();
  }

  Future<ColdigomCatalogSyncResult> _run() async {
    state = state.copyWith(isSyncing: true);
    final result = await ref.read(syncColdigomCatalogProvider).run();
    if (!ref.mounted) return result;
    final metadata = ref.read(coldigomCatalogSyncMetadataStoreProvider);
    state = state.copyWith(
      isSyncing: false,
      lastResult: result,
      lastSyncedAt: metadata.readSyncedAt(),
      count: metadata.readCount(),
    );
    if (result is ColdigomCatalogSyncReplaced) {
      // O Isar mudou por baixo dos caches: re-hidrata (o índice novo troca
      // a lista local na Home sem tocar em quem já leu `groupById`).
      ref.invalidate(coldigomCatalogHydrationProvider);
    }
    return result;
  }
}
