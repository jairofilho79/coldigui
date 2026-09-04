import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_by_pdf_id.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_group_id.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/domain/utils/coldigom_praise_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('findLouvorByPdfIdWithColdigom', () {
    final plpcgLouvor = Louvor.fromManifest(
      nome: 'PLPCG',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '001.pdf',
      pdfId: encodePdfId('ColAdultos/001.pdf'),
    );

    final coldigomLouvor = Louvor.fromManifest(
      nome: 'Coldigom',
      numero: '002',
      categoria: 'Cifra',
      classificacao: 'Country',
      pdf: 'm.pdf',
      pdfId: encodePdfId('assets/praises/p1/m.pdf'),
      groupId: 'p1',
      source: LouvorDataSource.coldigom,
    );

    test('encontra no manifest PLPCG', () {
      expect(
        findLouvorByPdfIdWithColdigom([plpcgLouvor], plpcgLouvor.pdfId),
        plpcgLouvor,
      );
    });

    test('encontra no cache coldigom', () {
      expect(
        findLouvorByPdfIdWithColdigom(
          const [],
          coldigomLouvor.pdfId,
          coldigomCache: {coldigomLouvor.pdfId: coldigomLouvor},
        ),
        coldigomLouvor,
      );
    });

    test('resolveLouvorDataSource infere coldigom pelo pdfId', () {
      expect(
        resolveLouvorDataSource(coldigomLouvor.pdfId),
        LouvorDataSource.coldigom,
      );
    });
  });

  group('findLouvorGroupByPdfId', () {
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

    final plpcgCifra = Louvor.fromManifest(
      nome: 'Grande Deus',
      numero: '001',
      categoria: 'Cifra nível I',
      classificacao: 'ColAdultos',
      pdf: '001-cifra.pdf',
      pdfId: 'plpcg-cifra',
      groupId: sharedGroupId,
    );

    test('agrupa irmãos PLPCG no manifest', () {
      final group = findLouvorGroupByPdfId([
        plpcgPartitura,
        plpcgCifra,
      ], plpcgPartitura.pdfId);

      expect(group, isNotNull);
      expect(group!.totalMaterials, 2);
      expect(
        group.sections
            .expand((s) => s.materials)
            .every((m) => m.louvor.source == LouvorDataSource.plpcg),
        isTrue,
      );
    });

    test('retorna null para material único', () {
      expect(findLouvorGroupByPdfId([plpcgPartitura], 'plpcg-part'), isNull);
    });

    test('retorna null para id órfão', () {
      expect(findLouvorGroupByPdfId([plpcgPartitura], 'nao-existe'), isNull);
    });
  });

  group('findSwapMaterialGroup', () {
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
    final track = AudioTrack(
      audioId: 'a1',
      r2Key: 'k',
      nome: 'Grande Deus',
      numero: '001',
      groupId: sharedGroupId,
      categoria: 'Áudio',
      classificacao: 'ColAdultos',
    );

    test('inclui áudio mesmo com um só PDF', () {
      final group = findSwapMaterialGroup(
        pdfId: plpcgPartitura.pdfId,
        plpcgCatalog: [plpcgPartitura],
        audioCache: {track.audioId: track},
      );
      expect(group, isNotNull);
      expect(group!.totalMaterials, 2);
    });

    test('retorna null sem alternativa', () {
      expect(
        findSwapMaterialGroup(
          pdfId: plpcgPartitura.pdfId,
          plpcgCatalog: [plpcgPartitura],
        ),
        isNull,
      );
    });

    final coldigomPdfId = encodePdfId('assets/praises/p9/mat.pdf');
    final coldigomPdf = Louvor.fromManifest(
      nome: 'Comigo habita',
      numero: '002',
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: 'mat.pdf',
      pdfId: coldigomPdfId,
      groupId: 'p9',
      source: LouvorDataSource.coldigom,
    );
    final chordId = encodePdfId('assets/praises/p9/mat.chord');
    final chord = ChordMaterial(
      chordId: chordId,
      r2Key: 'assets/praises/p9/mat.chord',
      nome: 'Comigo habita',
      numero: '002',
      groupId: 'p9',
      categoria: 'Cifra',
      classificacao: 'ColAdultos',
    );

    test('inclui cifra do cache no grupo de um PDF coldigom', () {
      final group = findSwapMaterialGroup(
        pdfId: coldigomPdfId,
        coldigomCache: {coldigomPdfId: coldigomPdf},
        chordCache: {chordId: chord},
      );

      expect(group, isNotNull);
      expect(group!.chordMaterials.single.chordId, chordId);
      expect(group.totalMaterials, 2);
    });

    test('resolve grupo a partir do id da cifra', () {
      final group = findSwapMaterialGroup(
        pdfId: chordId,
        coldigomCache: {coldigomPdfId: coldigomPdf},
        chordCache: {chordId: chord},
      );

      expect(group, isNotNull);
      expect(group!.groupId, 'p9');
      expect(group.totalPdfs, 1);
      expect(group.chordMaterials.single.chordId, chordId);
    });

    test('não mistura cifra de outro praise', () {
      final outroChordId = encodePdfId('assets/praises/p8/mat.chord');
      final group = findSwapMaterialGroup(
        pdfId: coldigomPdfId,
        coldigomCache: {coldigomPdfId: coldigomPdf},
        chordCache: {
          outroChordId: ChordMaterial(
            chordId: outroChordId,
            r2Key: 'assets/praises/p8/mat.chord',
            nome: 'Outro',
            numero: '003',
            groupId: 'p8',
            categoria: 'Cifra',
            classificacao: 'ColAdultos',
          ),
        },
      );

      expect(group, isNull);
    });
  });

  group('coldigomPraiseIdFromPdfId', () {
    test('extrai praiseId do path em pdfId', () {
      expect(
        coldigomPraiseIdFromPdfId(
          encodePdfId('assets/praises/abc-123/mat.pdf'),
        ),
        'abc-123',
      );
    });

    test('retorna null para pdfId PLPCG', () {
      expect(
        coldigomPraiseIdFromPdfId(encodePdfId('ColAdultos/001.pdf')),
        isNull,
      );
    });
  });
}
