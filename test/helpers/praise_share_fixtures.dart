// Catálogo mínimo por praise para os testes do link `?p=` (plano 2).
// O `shortId` vive em `coldigomMeta` (C3) e o índice monta os mapas
// `shortId → grupo` e `material → grupo` no `build` (C4).
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/catalog_material.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/domain/entities/coldigom_praise_metadata.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';

/// Id de material Coldigom — `encodePdfId` do path R2, como no app.
String praiseMaterialId(String praiseId, String file) =>
    encodePdfId('assets/praises/$praiseId/$file');

Louvor praisePdf({
  required String praiseId,
  required String pdfId,
  String categoria = 'Partitura',
  String? materialKindId,
}) => Louvor(
  nome: 'Louvor $praiseId',
  numero: '001',
  categoria: categoria,
  classificacao: 'Coro',
  pdf: 'https://coldigom.test/$pdfId',
  pdfId: pdfId,
  groupId: praiseId,
  searchTitleNorm: 'louvor $praiseId',
  searchContentTokens: const [],
  searchCompactContent: '',
  materialKindId: materialKindId,
  praiseId: praiseId,
);

AudioTrack praiseAudio({
  required String praiseId,
  required String audioId,
  String? materialKindId,
}) => AudioTrack(
  audioId: audioId,
  r2Key: 'assets/praises/$praiseId/audio.mp3',
  nome: 'Louvor $praiseId',
  numero: '001',
  groupId: praiseId,
  categoria: 'Áudio',
  classificacao: 'Coro',
  materialKindId: materialKindId,
);

ChordMaterial praiseChord({
  required String praiseId,
  required String chordId,
}) => ChordMaterial(
  chordId: chordId,
  r2Key: 'assets/praises/$praiseId/cifra.chord',
  nome: 'Louvor $praiseId',
  numero: '001',
  groupId: praiseId,
  categoria: 'Cifra',
  classificacao: 'Coro',
);

GestureMaterial praiseGesture({
  required String praiseId,
  required String gestureId,
}) => GestureMaterial(
  gestureId: gestureId,
  r2Key: 'assets/praises/$praiseId/gestos.gestures',
  nome: 'Louvor $praiseId',
  numero: '001',
  groupId: praiseId,
  categoria: 'Gestos',
  classificacao: 'Coro',
);

LouvorGroup praiseGroup({
  required String praiseId,
  String? shortId,
  List<Louvor> pdfs = const [],
  List<AudioTrack> audios = const [],
  List<ChordMaterial> chords = const [],
  List<GestureMaterial> gestures = const [],
  bool withLyrics = false,
}) => LouvorGroup(
  groupId: praiseId,
  numero: '001',
  nome: 'Louvor $praiseId',
  sections: [
    if (pdfs.isNotEmpty)
      LouvorMaterialSection(
        classificacao: 'Coro',
        displayLabel: 'Coro',
        materials: [
          for (final pdf in pdfs)
            LouvorMaterialEntry(
              categoria: pdf.categoria,
              pdfId: pdf.pdfId,
              louvor: pdf,
            ),
        ],
      ),
  ],
  audioTracks: audios,
  chordMaterials: chords,
  gestureMaterials: gestures,
  lyrics: withLyrics
      ? LyricsMaterial(
          praiseId: praiseId,
          nome: 'Louvor $praiseId',
          numero: '001',
        )
      : null,
  coldigomMeta: ColdigomPraiseMetadata(
    name: 'Louvor $praiseId',
    shortId: shortId,
  ),
);

ColdigomSearchIndex praiseIndex(List<LouvorGroup> groups) =>
    ColdigomSearchIndex.build([
      for (final group in groups)
        ColdigomIndexedPraise.build(
          praiseId: group.groupId,
          numero: group.numero,
          nome: group.nome,
          searchTokens: group.nome.toLowerCase(),
          group: group,
        ),
    ]);
