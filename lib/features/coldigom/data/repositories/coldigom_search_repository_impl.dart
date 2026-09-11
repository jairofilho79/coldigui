import 'dart:async';

import 'package:dio/dio.dart';

import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/entities/youtube_material.dart';
import '../../../catalog/domain/ports/search_cancellation.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../../domain/entities/coldigom_praise_metadata.dart';
import '../../domain/repositories/coldigom_search_repository.dart';
import '../adapters/coldigom_louvor_adapter.dart';
import '../coldigom_cache_writer.dart';
import '../datasources/coldigom_remote_datasource.dart';
import '../models/praise_dto.dart';

/// Orquestra busca/browse coldigom via endpoint PLPCG (1 request com materials).
///
/// Antes de devolver, funde o que veio nos caches Coldigom pelo [cache] — é
/// aqui, e não na presentation, que os caches são escritos (C.3). Sem [cache]
/// (testes de mapeamento puro) o repositório só mapeia.
class ColdigomSearchRepositoryImpl implements ColdigomSearchRepository {
  const ColdigomSearchRepositoryImpl(
    this._remote, {
    this.searchLimit = 20,
    this.cache,
  });

  final ColdigomRemoteDatasource _remote;
  final int searchLimit;

  /// Escritor dos caches Coldigom; `null` desliga a escrita.
  final ColdigomCacheWriter? cache;

  @override
  Future<ColdigomSearchResult> search(
    String query, {
    int page = 1,
    SearchCancellation? cancellation,
  }) async {
    final trimmed = query.trim();
    final safePage = page < 1 ? 1 : page;
    if (trimmed.isEmpty) {
      return ColdigomSearchResult(
        groups: const [],
        louvores: const [],
        page: safePage,
      );
    }

    final pageDto = await _listCancellable(
      ColdigomPraisesQuery(q: trimmed, limit: searchLimit, page: safePage),
      cancellation,
    );
    if (pageDto.data.isEmpty) {
      return ColdigomSearchResult(
        groups: const [],
        louvores: const [],
        page: safePage,
      );
    }

    final fetched = _mapDetails(pageDto.data);
    final groups = LouvorGroup.fromLouvores(
      fetched.louvores,
      audioTracks: fetched.audioTracks,
      youtubeMaterials: fetched.youtubeMaterials,
      chordMaterials: fetched.chordMaterials,
      gestureMaterials: fetched.gestureMaterials,
      coldigomMetaByGroupId: fetched.metaByGroupId,
      sortByNumber: false,
    );
    final result = ColdigomSearchResult(
      groups: groups,
      louvores: fetched.louvores,
      audioTracks: fetched.audioTracks,
      youtubeMaterials: fetched.youtubeMaterials,
      chordMaterials: fetched.chordMaterials,
      gestureMaterials: fetched.gestureMaterials,
      praiseMetaByGroupId: fetched.metaByGroupId,
      page: safePage,
      hasNextPage: pageDto.data.length >= searchLimit,
    );
    cache?.mergeSearchResult(result);
    return result;
  }

  /// `listPlpcgPraises` com [SearchCancellation] traduzida para `CancelToken`.
  ///
  /// O cancelamento vira [SearchCancelledException] para o chamador não
  /// confundir "chegou tecla nova" com "a rede caiu".
  Future<PlpcgPraisesPageDto> _listCancellable(
    ColdigomPraisesQuery query,
    SearchCancellation? cancellation,
  ) async {
    if (cancellation == null) return _remote.listPlpcgPraises(query);
    if (cancellation.isCancelled) throw const SearchCancelledException();

    final cancelToken = CancelToken();
    unawaited(
      cancellation.whenCancelled.then((_) {
        if (!cancelToken.isCancelled) cancelToken.cancel();
      }),
    );

    try {
      return await _remote.listPlpcgPraises(query, cancelToken: cancelToken);
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        throw const SearchCancelledException();
      }
      rethrow;
    }
  }

  @override
  Future<ColdigomBrowseResult> browse(ColdigomBrowseQuery query) async {
    final safePage = query.page < 1 ? 1 : query.page;
    final safeLimit = query.limit < 1 ? 10 : query.limit;
    final hasQuery = query.q != null && query.q!.trim().isNotEmpty;

    final pageDto = await _remote.listPlpcgPraises(
      ColdigomPraisesQuery(
        q: query.q,
        tonalities: query.tonalities,
        rhythms: query.rhythms,
        categories: query.categories,
        tagIds: query.tagIds,
        materialKindIds: query.materialKindIds,
        page: safePage,
        limit: safeLimit,
        sort: query.apiSort,
      ),
    );

    final totalPages = pageDto.pagination.totalPages < 1
        ? 1
        : pageDto.pagination.totalPages;

    if (pageDto.data.isEmpty) {
      return ColdigomBrowseResult(
        groups: const [],
        louvores: const [],
        page: pageDto.pagination.page,
        limit: pageDto.pagination.limit,
        totalItems: pageDto.pagination.total,
        totalPages: totalPages,
      );
    }

    final fetched = _mapDetails(pageDto.data);
    final groups = LouvorGroup.fromLouvores(
      fetched.louvores,
      audioTracks: fetched.audioTracks,
      youtubeMaterials: fetched.youtubeMaterials,
      chordMaterials: fetched.chordMaterials,
      gestureMaterials: fetched.gestureMaterials,
      coldigomMetaByGroupId: fetched.metaByGroupId,
      // Com q a API já ranqueia; sem q ordenamos por número localmente.
      sortByNumber: !hasQuery,
    );

    final result = ColdigomBrowseResult(
      groups: groups,
      louvores: fetched.louvores,
      audioTracks: fetched.audioTracks,
      youtubeMaterials: fetched.youtubeMaterials,
      chordMaterials: fetched.chordMaterials,
      gestureMaterials: fetched.gestureMaterials,
      praiseMetaByGroupId: fetched.metaByGroupId,
      page: pageDto.pagination.page,
      limit: pageDto.pagination.limit,
      totalItems: pageDto.pagination.total,
      totalPages: totalPages,
    );
    cache?.mergeBrowseResult(result);
    return result;
  }

  static ({
    List<Louvor> louvores,
    List<AudioTrack> audioTracks,
    List<YoutubeMaterial> youtubeMaterials,
    List<ChordMaterial> chordMaterials,
    List<GestureMaterial> gestureMaterials,
    Map<String, ColdigomPraiseMetadata> metaByGroupId,
  })
  _mapDetails(List<PraiseDetailDto> details) {
    final louvores = <Louvor>[];
    final audioTracks = <AudioTrack>[];
    final youtubeMaterials = <YoutubeMaterial>[];
    final chordMaterials = <ChordMaterial>[];
    final gestureMaterials = <GestureMaterial>[];
    final metaByGroupId = <String, ColdigomPraiseMetadata>{};
    for (final detail in details) {
      louvores.addAll(ColdigomLouvorAdapter.toLouvores(detail));
      audioTracks.addAll(ColdigomLouvorAdapter.toAudioTracks(detail));
      youtubeMaterials.addAll(ColdigomLouvorAdapter.toYoutubeMaterials(detail));
      chordMaterials.addAll(ColdigomLouvorAdapter.toChordMaterials(detail));
      gestureMaterials.addAll(ColdigomLouvorAdapter.toGestureMaterials(detail));
      metaByGroupId[detail.id] = ColdigomLouvorAdapter.toMetadata(detail);
    }
    return (
      louvores: louvores,
      audioTracks: audioTracks,
      youtubeMaterials: youtubeMaterials,
      chordMaterials: chordMaterials,
      gestureMaterials: gestureMaterials,
      metaByGroupId: metaByGroupId,
    );
  }
}
