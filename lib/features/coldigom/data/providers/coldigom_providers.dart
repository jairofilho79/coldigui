import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../domain/entities/coldigom_praise_metadata.dart';
import '../../domain/repositories/coldigom_search_repository.dart';
import '../datasources/coldigom_remote_datasource.dart';
import '../providers/coldigom_dio_provider.dart';
import '../repositories/coldigom_search_repository_impl.dart';

/// Cache em memória de louvores coldigom indexados por `pdfId`.
class ColdigomLouvoresCacheNotifier extends Notifier<Map<String, Louvor>> {
  @override
  Map<String, Louvor> build() => const {};

  void mergeLouvores(Iterable<Louvor> louvores) {
    if (louvores.isEmpty) return;
    final next = Map<String, Louvor>.from(state);
    for (final louvor in louvores) {
      next[louvor.pdfId] = louvor;
    }
    state = next;
  }

  Louvor? findByPdfId(String pdfId) => state[pdfId];
}

final coldigomLouvoresCacheProvider =
    NotifierProvider<ColdigomLouvoresCacheNotifier, Map<String, Louvor>>(
      ColdigomLouvoresCacheNotifier.new,
    );

/// Cache em memória de faixas coldigom indexadas por `audioId`.
class ColdigomAudioTracksCacheNotifier
    extends Notifier<Map<String, AudioTrack>> {
  @override
  Map<String, AudioTrack> build() => const {};

  void mergeTracks(Iterable<AudioTrack> tracks) {
    if (tracks.isEmpty) return;
    final next = Map<String, AudioTrack>.from(state);
    for (final track in tracks) {
      next[track.audioId] = track;
    }
    state = next;
  }

  AudioTrack? findByAudioId(String audioId) => state[audioId];
}

final coldigomAudioTracksCacheProvider =
    NotifierProvider<ColdigomAudioTracksCacheNotifier, Map<String, AudioTrack>>(
      ColdigomAudioTracksCacheNotifier.new,
    );

/// Cache de metadados Coldigom indexados por praise/`groupId`.
class ColdigomPraiseMetaCacheNotifier
    extends Notifier<Map<String, ColdigomPraiseMetadata>> {
  @override
  Map<String, ColdigomPraiseMetadata> build() => const {};

  void mergeMeta(Map<String, ColdigomPraiseMetadata> byGroupId) {
    if (byGroupId.isEmpty) return;
    state = {...state, ...byGroupId};
  }

  void put(String groupId, ColdigomPraiseMetadata meta) {
    if (groupId.isEmpty) return;
    state = {...state, groupId: meta};
  }

  ColdigomPraiseMetadata? findByGroupId(String groupId) => state[groupId];
}

final coldigomPraiseMetaCacheProvider =
    NotifierProvider<
      ColdigomPraiseMetaCacheNotifier,
      Map<String, ColdigomPraiseMetadata>
    >(ColdigomPraiseMetaCacheNotifier.new);

final coldigomRemoteDatasourceProvider = Provider<ColdigomRemoteDatasource>((
  ref,
) {
  return ColdigomRemoteDatasource(ref.watch(coldigomDioProvider));
});

final coldigomSearchRepositoryProvider = Provider<ColdigomSearchRepository>((
  ref,
) {
  return ColdigomSearchRepositoryImpl(
    ref.watch(coldigomRemoteDatasourceProvider),
  );
});
