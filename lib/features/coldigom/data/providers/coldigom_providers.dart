import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../catalog/domain/entities/louvor.dart';
import '../../../catalog/domain/entities/youtube_material.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../domain/entities/coldigom_praise_metadata.dart';
import '../../domain/repositories/coldigom_search_repository.dart';
import '../coldigom_cache_writer.dart';
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

/// Cache em memória de cifras coldigom indexadas por `chordId`.
class ColdigomChordMaterialsCacheNotifier
    extends Notifier<Map<String, ChordMaterial>> {
  @override
  Map<String, ChordMaterial> build() => const {};

  void mergeChords(Iterable<ChordMaterial> chords) {
    if (chords.isEmpty) return;
    final next = Map<String, ChordMaterial>.from(state);
    for (final chord in chords) {
      next[chord.chordId] = chord;
    }
    state = next;
  }

  ChordMaterial? findByChordId(String chordId) => state[chordId];
}

final coldigomChordMaterialsCacheProvider =
    NotifierProvider<
      ColdigomChordMaterialsCacheNotifier,
      Map<String, ChordMaterial>
    >(ColdigomChordMaterialsCacheNotifier.new);

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

/// Cache de links de YouTube indexados por praise/`groupId` (sobra 6a).
///
/// É o único cache Coldigom por **lista**: um praise pode ter vários vídeos, e
/// YouTube não tem id endereçável no espaço de ids do app.
class ColdigomYoutubeCacheNotifier
    extends Notifier<Map<String, List<YoutubeMaterial>>> {
  @override
  Map<String, List<YoutubeMaterial>> build() => const {};

  /// Funde por `groupId`, sem repetir o mesmo vídeo (dedupe por `id`).
  void mergeYoutube(Iterable<YoutubeMaterial> materials) {
    final incoming = <String, List<YoutubeMaterial>>{};
    for (final material in materials) {
      final groupId = material.groupId.trim();
      if (groupId.isEmpty) continue;
      incoming.putIfAbsent(groupId, () => []).add(material);
    }
    if (incoming.isEmpty) return;

    final next = Map<String, List<YoutubeMaterial>>.from(state);
    for (final entry in incoming.entries) {
      final merged = [...?next[entry.key]];
      final seen = merged.map((m) => m.id).toSet();
      for (final material in entry.value) {
        if (seen.add(material.id)) merged.add(material);
      }
      next[entry.key] = List<YoutubeMaterial>.unmodifiable(merged);
    }
    state = next;
  }

  List<YoutubeMaterial> findByGroupId(String groupId) =>
      state[groupId] ?? const [];
}

final coldigomYoutubeCacheProvider =
    NotifierProvider<
      ColdigomYoutubeCacheNotifier,
      Map<String, List<YoutubeMaterial>>
    >(ColdigomYoutubeCacheNotifier.new);

final coldigomRemoteDatasourceProvider = Provider<ColdigomRemoteDatasource>((
  ref,
) {
  return ColdigomRemoteDatasource(ref.watch(coldigomDioProvider));
});

/// Ponto único de escrita nos caches acima — ver [ColdigomCacheWriter].
///
/// Não observa nada: a instância vive enquanto o container viver, e não
/// invalida quem a lê a cada merge.
final coldigomCacheWriterProvider = Provider<ColdigomCacheWriter>((ref) {
  return ColdigomCacheWriter(ref);
});

final coldigomSearchRepositoryProvider = Provider<ColdigomSearchRepository>((
  ref,
) {
  return ColdigomSearchRepositoryImpl(
    ref.watch(coldigomRemoteDatasourceProvider),
    cache: ref.watch(coldigomCacheWriterProvider),
  );
});
