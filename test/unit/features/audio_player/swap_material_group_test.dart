import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_group_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// Precedência do botão layers na face de áudio: manda a faixa tocando.
void main() {
  final focusedPdfId = encodePdfId('assets/praises/p1/partitura.pdf');
  final focusedChordId = encodePdfId('assets/praises/p1/cifra.pdf');
  final playingPdfId = encodePdfId('assets/praises/p9/partitura.pdf');
  final playingOtherPdfId = encodePdfId('assets/praises/p9/gestos.pdf');

  Louvor coldigomLouvor(String pdfId, String groupId) {
    return Louvor.fromManifest(
      nome: 'Louvor $groupId',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'Coro',
      pdf: 'x.pdf',
      pdfId: pdfId,
      groupId: groupId,
      source: LouvorDataSource.coldigom,
    );
  }

  final coldigomCache = <String, Louvor>{
    focusedPdfId: coldigomLouvor(focusedPdfId, 'p1'),
    focusedChordId: coldigomLouvor(focusedChordId, 'p1'),
    playingPdfId: coldigomLouvor(playingPdfId, 'p9'),
    playingOtherPdfId: coldigomLouvor(playingOtherPdfId, 'p9'),
  };

  const playingTrack = AudioTrack(
    audioId: 'aud-p9',
    r2Key: 'assets/praises/p9/a.mp3',
    nome: 'Louvor p9',
    numero: '002',
    groupId: 'p9',
    categoria: 'Áudio',
    classificacao: 'Coro',
  );

  test('grupo da faixa tocando vence o pdfId de outro louvor', () {
    final group = findSwapMaterialGroup(
      pdfId: focusedPdfId,
      audioId: playingTrack.audioId,
      coldigomCache: coldigomCache,
      audioCache: {playingTrack.audioId: playingTrack},
    );

    expect(group, isNotNull);
    expect(group!.groupId, 'p9');
  });

  test('pdfId do mesmo louvor da faixa continua montando o grupo', () {
    final group = findSwapMaterialGroup(
      pdfId: playingPdfId,
      audioId: playingTrack.audioId,
      coldigomCache: coldigomCache,
      audioCache: {playingTrack.audioId: playingTrack},
    );

    expect(group, isNotNull);
    expect(group!.groupId, 'p9');
    expect(group.totalPdfs, 2);
    expect(group.audioTracks.single.audioId, playingTrack.audioId);
  });

  test('não perde PDFs PLPCG do grupo da faixa tocando', () {
    final sharedGroupId = LouvorGroupId.compute(
      numero: '001',
      nome: 'Grande Deus',
    );
    final plpcgPartitura = Louvor.fromManifest(
      nome: 'Grande Deus',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '001.pdf',
      pdfId: 'plpcg-part',
      groupId: sharedGroupId,
    );
    final plpcgTrack = AudioTrack(
      audioId: 'aud-plpcg',
      r2Key: 'k',
      nome: 'Grande Deus',
      numero: '001',
      groupId: sharedGroupId,
      categoria: 'Áudio',
      classificacao: 'ColAdultos',
    );

    final group = findSwapMaterialGroup(
      pdfId: plpcgPartitura.pdfId,
      audioId: plpcgTrack.audioId,
      plpcgCatalog: [plpcgPartitura],
      audioCache: {plpcgTrack.audioId: plpcgTrack},
    );

    expect(group, isNotNull);
    expect(group!.totalPdfs, 1);
    expect(group.audioTracks.single.audioId, plpcgTrack.audioId);
  });

  test('sem faixa tocando o pdfId continua mandando', () {
    final group = findSwapMaterialGroup(
      pdfId: focusedPdfId,
      coldigomCache: coldigomCache,
      audioCache: {playingTrack.audioId: playingTrack},
    );

    expect(group, isNotNull);
    expect(group!.groupId, 'p1');
  });
}
