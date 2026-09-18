import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/data/sources/composite_catalog_source.dart';
import 'package:coldigui/features/catalog/data/sources/plpcg_catalog_source.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/entities/manifest_material_aliases.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Precedência do botão layers com uma entrada de áudio focada: manda a
/// faixa tocando — agora sobre o composite fundido por praise.
void main() {
  final focusedPdfId = encodePdfId('assets/praises/p1/partitura.pdf');
  final focusedChordId = encodePdfId('assets/praises/p1/cifra.chord');
  final playingPdfId = encodePdfId('assets/praises/p9/partitura.pdf');
  final playingOtherPdfId = encodePdfId('assets/praises/p9/gestos.pdf');

  Louvor coldigomLouvor(String pdfId, String praiseId) => Louvor.fromManifest(
    nome: 'Louvor $praiseId',
    numero: '001',
    categoria: 'Partitura',
    classificacao: 'Coro',
    pdf: 'x.pdf',
    pdfId: pdfId,
    groupId: praiseId,
    source: LouvorDataSource.coldigom,
    praiseId: praiseId,
  );

  const playingTrack = AudioTrack(
    audioId: 'aud-p9',
    r2Key: 'assets/praises/p9/a.mp3',
    nome: 'Louvor p9',
    numero: '002',
    groupId: 'p9',
    categoria: 'Áudio',
    classificacao: 'Coro',
  );

  final chord = ChordMaterial(
    chordId: focusedChordId,
    r2Key: 'assets/praises/p1/cifra.chord',
    nome: 'Louvor p1',
    numero: '001',
    groupId: 'p1',
    categoria: 'Cifra',
    classificacao: 'Coro',
  );

  CompositeCatalogSource source({
    List<Louvor> manifest = const [],
    Map<String, Louvor> coldigom = const {},
    Map<String, AudioTrack> audio = const {},
    Map<String, ChordMaterial> chords = const {},
  }) => CompositeCatalogSource(
    plpcg: PlpcgCatalogSource(catalog: manifest),
    coldigom: ColdigomCatalogSource(
      louvores: coldigom,
      audioTracks: audio,
      chords: chords,
    ),
    aliases: ManifestMaterialAliases.fromLouvores(manifest),
  );

  final coldigomCache = <String, Louvor>{
    focusedPdfId: coldigomLouvor(focusedPdfId, 'p1'),
    playingPdfId: coldigomLouvor(playingPdfId, 'p9'),
    playingOtherPdfId: coldigomLouvor(playingOtherPdfId, 'p9'),
  };

  test('grupo da faixa tocando vence o pdfId de outro louvor', () {
    final group = findSwapMaterialGroup(
      pdfId: focusedPdfId,
      audioId: playingTrack.audioId,
      source: source(
        coldigom: coldigomCache,
        audio: {playingTrack.audioId: playingTrack},
      ),
    );

    expect(group, isNotNull);
    expect(group!.groupId, 'p9');
  });

  test('pdfId do mesmo louvor da faixa continua montando o grupo', () {
    final group = findSwapMaterialGroup(
      pdfId: playingPdfId,
      audioId: playingTrack.audioId,
      source: source(
        coldigom: coldigomCache,
        audio: {playingTrack.audioId: playingTrack},
      ),
    );

    expect(group, isNotNull);
    expect(group!.groupId, 'p9');
    expect(group.totalPdfs, 2);
    expect(group.audioTracks.single.audioId, playingTrack.audioId);
  });

  test('não perde PDFs do manifest do praise da faixa tocando', () {
    final partitura = Louvor.fromManifest(
      nome: 'Louvor p9',
      numero: '002',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: 'https://coldigom.test/assets/praises/p9/legado.pdf',
      pdfId: 'legado-p9',
      groupId: '002:louvor-p9',
      praiseId: 'p9',
      materialId: 'legado',
    );

    final group = findSwapMaterialGroup(
      pdfId: focusedPdfId,
      audioId: playingTrack.audioId,
      source: source(
        manifest: [partitura],
        coldigom: coldigomCache,
        audio: {playingTrack.audioId: playingTrack},
      ),
    );

    expect(group!.groupId, 'p9');
    expect(
      group.flatPdfMaterials.map((m) => m.pdfId),
      containsAll(['legado-p9', playingPdfId, playingOtherPdfId]),
    );
  });

  test('cifra focada resolve o grupo do praise pelo id da cifra', () {
    final group = findSwapMaterialGroup(
      pdfId: focusedChordId,
      source: source(
        coldigom: coldigomCache,
        chords: {focusedChordId: chord},
      ),
    );

    expect(group, isNotNull);
    expect(group!.groupId, 'p1');
    expect(group.totalMaterials, 2);
  });

  test('só a faixa: grupo pelo groupId da faixa', () {
    final group = findSwapMaterialGroup(
      audioId: playingTrack.audioId,
      source: source(
        coldigom: coldigomCache,
        audio: {playingTrack.audioId: playingTrack},
      ),
    );
    expect(group!.groupId, 'p9');
  });

  test('null sem alternativa de material', () {
    expect(
      findSwapMaterialGroup(
        pdfId: focusedPdfId,
        source: source(coldigom: {focusedPdfId: coldigomCache[focusedPdfId]!}),
      ),
      isNull,
    );
    expect(findSwapMaterialGroup(source: source()), isNull);
  });
}
