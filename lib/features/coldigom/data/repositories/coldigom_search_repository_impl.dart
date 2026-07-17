import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/louvor_group.dart';
import '../../../catalog/domain/entities/youtube_material.dart';
import '../../domain/repositories/coldigom_search_repository.dart';
import '../adapters/coldigom_louvor_adapter.dart';
import '../datasources/coldigom_remote_datasource.dart';
import '../models/praise_dto.dart';

/// Orquestra busca/browse coldigom via endpoint PLPCG (1 request com materials).
class ColdigomSearchRepositoryImpl implements ColdigomSearchRepository {
  const ColdigomSearchRepositoryImpl(this._remote, {this.searchLimit = 20});

  final ColdigomRemoteDatasource _remote;
  final int searchLimit;

  @override
  Future<ColdigomSearchResult> search(String query, {int page = 1}) async {
    final trimmed = query.trim();
    final safePage = page < 1 ? 1 : page;
    if (trimmed.isEmpty) {
      return ColdigomSearchResult(
        groups: const [],
        louvores: const [],
        page: safePage,
      );
    }

    final pageDto = await _remote.listPlpcgPraises(
      ColdigomPraisesQuery(q: trimmed, limit: searchLimit, page: safePage),
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
    );
    return ColdigomSearchResult(
      groups: groups,
      louvores: fetched.louvores,
      audioTracks: fetched.audioTracks,
      youtubeMaterials: fetched.youtubeMaterials,
      page: safePage,
      hasNextPage: pageDto.data.length >= searchLimit,
    );
  }

  @override
  Future<ColdigomBrowseResult> browse(ColdigomBrowseQuery query) async {
    final safePage = query.page < 1 ? 1 : query.page;
    final safeLimit = query.limit < 1 ? 10 : query.limit;

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
    );

    return ColdigomBrowseResult(
      groups: groups,
      louvores: fetched.louvores,
      audioTracks: fetched.audioTracks,
      youtubeMaterials: fetched.youtubeMaterials,
      page: pageDto.pagination.page,
      limit: pageDto.pagination.limit,
      totalItems: pageDto.pagination.total,
      totalPages: totalPages,
    );
  }

  static ({
    List<Louvor> louvores,
    List<AudioTrack> audioTracks,
    List<YoutubeMaterial> youtubeMaterials,
  })
  _mapDetails(List<PraiseDetailDto> details) {
    final louvores = <Louvor>[];
    final audioTracks = <AudioTrack>[];
    final youtubeMaterials = <YoutubeMaterial>[];
    for (final detail in details) {
      louvores.addAll(ColdigomLouvorAdapter.toLouvores(detail));
      audioTracks.addAll(ColdigomLouvorAdapter.toAudioTracks(detail));
      youtubeMaterials.addAll(ColdigomLouvorAdapter.toYoutubeMaterials(detail));
    }
    return (
      louvores: louvores,
      audioTracks: audioTracks,
      youtubeMaterials: youtubeMaterials,
    );
  }
}
