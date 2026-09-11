import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audio_player/domain/entities/audio_track.dart';
import '../../../chords/domain/entities/chord_material.dart';
import '../../../coldigom/data/providers/coldigom_providers.dart';
import '../../../coldigom/domain/entities/coldigom_praise_metadata.dart';
import '../../../gestures/domain/entities/gesture_material.dart';
import '../../domain/entities/louvor.dart';
import '../../domain/entities/youtube_material.dart';
import 'louvores_by_pdf_id_provider.dart';

/// Leitura **síncrona** de material por id, para a presentation (C.3).
///
/// Vinte arquivos liam os caches Coldigom direto — cada um sabendo qual dos
/// cinco notifiers guardava o quê, e nenhum sabendo do manifest PLPCG. Aqui a
/// pergunta é sempre a mesma ("qual material é este id?") e a resposta vem no
/// mesmo frame: nada aqui espera rede.
///
/// Complementa (não substitui) `CatalogSource`: a porta monta **grupos** e é
/// assíncrona; o lookup só devolve o material solto que já está em memória.
final class CatalogMaterialLookup {
  const CatalogMaterialLookup({
    this.plpcgLouvoresByPdfId = const {},
    this.coldigomLouvoresByPdfId = const {},
    this.audioTracksById = const {},
    this.chordsById = const {},
    this.gesturesById = const {},
    this.praiseMetaByGroupId = const {},
    this.youtubeByGroupId = const {},
  });

  /// PDFs do manifest PLPCG, por `pdfId` (`louvoresByPdfIdProvider`).
  final Map<String, Louvor> plpcgLouvoresByPdfId;

  /// PDFs Coldigom em cache, por `pdfId`.
  final Map<String, Louvor> coldigomLouvoresByPdfId;

  /// Faixas Coldigom em cache, por `audioId`.
  final Map<String, AudioTrack> audioTracksById;

  /// Cifras Coldigom em cache, por `chordId`.
  final Map<String, ChordMaterial> chordsById;

  /// Documentos de gestos Coldigom em cache, por `gestureId`.
  final Map<String, GestureMaterial> gesturesById;

  /// Metadados do praise em cache, por `groupId`.
  final Map<String, ColdigomPraiseMetadata> praiseMetaByGroupId;

  /// Links de YouTube em cache, por `groupId`.
  final Map<String, List<YoutubeMaterial>> youtubeByGroupId;

  /// PDF de [materialId] — manifest PLPCG primeiro, cache Coldigom depois.
  ///
  /// Os dois acervos compartilham o espaço de ids, então uma consulta só
  /// atende as duas origens.
  Louvor? louvor(String materialId) =>
      plpcgLouvoresByPdfId[materialId] ?? coldigomLouvoresByPdfId[materialId];

  /// Faixa de áudio em cache, ou `null`.
  AudioTrack? audioTrack(String audioId) => audioTracksById[audioId];

  /// Cifra em cache, ou `null`.
  ChordMaterial? chord(String chordId) => chordsById[chordId];

  /// Documento de gestos em cache, ou `null`.
  GestureMaterial? gesture(String gestureId) => gesturesById[gestureId];

  /// Metadados do praise Coldigom, ou `null`.
  ColdigomPraiseMetadata? praiseMeta(String groupId) =>
      praiseMetaByGroupId[groupId];

  /// Links de YouTube do praise; lista vazia quando não há.
  List<YoutubeMaterial> youtube(String groupId) =>
      youtubeByGroupId[groupId] ?? const [];

  /// Faixas na ordem de [audioIds], **ignorando** ids sem hit no cache.
  ///
  /// Mesma regra de `tracksForAudioIds`: uma lista salva pode citar um áudio
  /// que ainda não foi aquecido, e isso não pode furar a fila.
  List<AudioTrack> tracksFor(Iterable<String> audioIds) => [
    for (final id in audioIds) ?audioTracksById[id],
  ];
}

/// Lookup síncrono do material por id (PLPCG + caches Coldigom).
final catalogMaterialLookupProvider = Provider<CatalogMaterialLookup>((ref) {
  return CatalogMaterialLookup(
    plpcgLouvoresByPdfId: ref.watch(louvoresByPdfIdProvider),
    coldigomLouvoresByPdfId: ref.watch(coldigomLouvoresCacheProvider),
    audioTracksById: ref.watch(coldigomAudioTracksCacheProvider),
    chordsById: ref.watch(coldigomChordMaterialsCacheProvider),
    gesturesById: ref.watch(coldigomGestureMaterialsCacheProvider),
    praiseMetaByGroupId: ref.watch(coldigomPraiseMetaCacheProvider),
    youtubeByGroupId: ref.watch(coldigomYoutubeCacheProvider),
  );
});
