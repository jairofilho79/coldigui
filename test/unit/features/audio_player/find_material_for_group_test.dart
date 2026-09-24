import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/domain/utils/find_material_for_group.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final coldigomPdfId = encodePdfId('assets/praises/p1/partitura.pdf');
  final coldigomOtherPdfId = encodePdfId('assets/praises/p1/gestos.pdf');
  final chordId = encodePdfId('assets/praises/p1/cifra.chord');
  final gestureId = encodePdfId('assets/praises/p1/m1.gestures');
  final otherPraisePdfId = encodePdfId('assets/praises/p9/partitura.pdf');

  Louvor coldigomLouvor(String pdfId, String groupId, String categoria) {
    return Louvor.fromManifest(
      nome: 'Shekinah',
      numero: '047',
      categoria: categoria,
      classificacao: 'Coro',
      pdf: 'x.pdf',
      pdfId: pdfId,
      groupId: groupId,
      source: LouvorDataSource.coldigom,
    );
  }

  final coldigomCache = <String, Louvor>{
    coldigomPdfId: coldigomLouvor(coldigomPdfId, 'p1', 'Partitura'),
    coldigomOtherPdfId: coldigomLouvor(coldigomOtherPdfId, 'p1', 'Gestos'),
    otherPraisePdfId: coldigomLouvor(otherPraisePdfId, 'p9', 'Partitura'),
  };

  final chord = ChordMaterial(
    chordId: chordId,
    r2Key: 'assets/praises/p1/cifra.chord',
    nome: 'Shekinah',
    numero: '047',
    groupId: 'p1',
    categoria: 'Cifra',
    classificacao: 'Coro',
  );

  final gesture = GestureMaterial(
    gestureId: gestureId,
    r2Key: 'assets/praises/p1/m1.gestures',
    nome: 'Shekinah',
    numero: '047',
    groupId: 'p1',
    categoria: 'Gestos',
    classificacao: 'Coro',
  );

  group('findMaterialForGroup', () {
    test('prefere o material do grupo que já está na lista ativa', () {
      final found = findMaterialForGroup(
        groupId: 'p1',
        carouselPdfIds: [otherPraisePdfId, coldigomOtherPdfId, coldigomPdfId],
        byPdfId: coldigomCache,
      );

      expect(found, coldigomOtherPdfId);
    });

    test('aceita cifra da lista ativa como material do grupo', () {
      final found = findMaterialForGroup(
        groupId: 'p1',
        carouselPdfIds: [otherPraisePdfId, chordId],
        byPdfId: coldigomCache,
        chordsById: {chordId: chord},
      );

      expect(found, chordId);
    });

    test('prefere o gesto do carousel quando ele é o material do grupo', () {
      final found = findMaterialForGroup(
        groupId: 'p1',
        carouselPdfIds: [otherPraisePdfId, gestureId],
        byPdfId: coldigomCache,
        gesturesById: {gestureId: gesture},
      );

      expect(found, gestureId);
    });

    test('cai para o primeiro PDF do grupo no catálogo', () {
      final found = findMaterialForGroup(
        groupId: 'p1',
        carouselPdfIds: [otherPraisePdfId],
        byPdfId: coldigomCache,
      );

      expect(found, coldigomPdfId);
    });

    test('retorna null sem material do grupo', () {
      expect(
        findMaterialForGroup(
          groupId: 'p42',
          carouselPdfIds: [coldigomPdfId],
          byPdfId: coldigomCache,
        ),
        isNull,
      );
    });

    test('retorna null para groupId vazio', () {
      expect(
        findMaterialForGroup(
          groupId: '',
          carouselPdfIds: [coldigomPdfId],
          byPdfId: coldigomCache,
        ),
        isNull,
      );
    });
  });

  group('groupIdForMaterialId', () {
    test('resolve pelo cache coldigom', () {
      expect(
        groupIdForMaterialId(materialId: coldigomPdfId, byPdfId: coldigomCache),
        'p1',
      );
    });

    test('resolve pelo cache de cifras', () {
      expect(
        groupIdForMaterialId(
          materialId: chordId,
          byPdfId: coldigomCache,
          chordsById: {chordId: chord},
        ),
        'p1',
      );
    });

    test('resolve o grupo de um id de gesto pelo cache', () {
      expect(
        groupIdForMaterialId(
          materialId: gestureId,
          byPdfId: coldigomCache,
          gesturesById: {gestureId: gesture},
        ),
        'p1',
      );
    });

    test('retorna null para id desconhecido', () {
      expect(
        groupIdForMaterialId(materialId: 'nada', byPdfId: coldigomCache),
        isNull,
      );
    });
  });

  group('findAudioForGroup', () {
    const playback = AudioTrack(
      audioId: 'a-playback',
      r2Key: 'assets/praises/p1/playback.mp3',
      nome: 'Shekinah',
      numero: '047',
      groupId: 'p1',
      categoria: 'Playback',
      classificacao: 'Coro',
    );
    const audio = AudioTrack(
      audioId: 'a-audio',
      r2Key: 'assets/praises/p1/audio.mp3',
      nome: 'Shekinah',
      numero: '047',
      groupId: 'p1',
      categoria: 'Áudio',
      classificacao: 'Coro',
    );
    const otherGroup = AudioTrack(
      audioId: 'a-outro',
      r2Key: 'assets/praises/p9/audio.mp3',
      nome: 'Outro',
      numero: '002',
      groupId: 'p9',
      categoria: 'Áudio',
      classificacao: 'Coro',
    );

    test('prefere a faixa de categoria Áudio', () {
      expect(
        findAudioForGroup('p1', const [otherGroup, playback, audio]),
        same(audio),
      );
    });

    test('cai para a primeira faixa do grupo sem categoria Áudio', () {
      expect(
        findAudioForGroup('p1', const [otherGroup, playback]),
        same(playback),
      );
    });

    test('ignora faixas de outros grupos', () {
      expect(findAudioForGroup('p1', const [otherGroup]), isNull);
    });

    test('retorna null para groupId vazio', () {
      expect(findAudioForGroup('', const [audio]), isNull);
    });
  });

  group('tracksForGroup', () {
    const first = AudioTrack(
      audioId: 'a1',
      r2Key: 'k1',
      nome: 'n',
      numero: '1',
      groupId: 'p1',
      categoria: 'Áudio',
      classificacao: 'c',
    );
    const second = AudioTrack(
      audioId: 'a2',
      r2Key: 'k2',
      nome: 'n',
      numero: '1',
      groupId: 'p2',
      categoria: 'Áudio',
      classificacao: 'c',
    );

    test('mantém a ordem e filtra pelo grupo', () {
      expect(tracksForGroup('p1', const [second, first]), [first]);
    });

    test('retorna vazio para groupId vazio', () {
      expect(tracksForGroup('', const [first]), isEmpty);
    });
  });
}
