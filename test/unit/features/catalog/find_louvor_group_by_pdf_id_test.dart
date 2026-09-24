import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart';
import 'package:coldigui/features/chords/domain/entities/chord_material.dart';
import 'package:coldigui/features/coldigom/data/sources/coldigom_catalog_source.dart';
import 'package:coldigui/features/coldigom/domain/utils/coldigom_praise_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('findSwapMaterialGroup', () {
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
    const track = AudioTrack(
      audioId: 'a1',
      r2Key: 'k',
      nome: 'Comigo habita',
      numero: '002',
      groupId: 'p9',
      categoria: 'Áudio',
      classificacao: 'ColAdultos',
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

    test('inclui áudio mesmo com um só PDF', () {
      final group = findSwapMaterialGroup(
        pdfId: coldigomPdfId,
        source: ColdigomCatalogSource(
          louvores: {coldigomPdfId: coldigomPdf},
          audioTracks: {track.audioId: track},
        ),
      );
      expect(group, isNotNull);
      expect(group!.totalMaterials, 2);
    });

    test('retorna null sem alternativa', () {
      expect(
        findSwapMaterialGroup(
          pdfId: coldigomPdfId,
          source: ColdigomCatalogSource(louvores: {coldigomPdfId: coldigomPdf}),
        ),
        isNull,
      );
    });

    test('inclui cifra do cache no grupo de um PDF coldigom', () {
      final group = findSwapMaterialGroup(
        pdfId: coldigomPdfId,
        source: ColdigomCatalogSource(
          louvores: {coldigomPdfId: coldigomPdf},
          chords: {chordId: chord},
        ),
      );

      expect(group, isNotNull);
      expect(group!.chordMaterials.single.chordId, chordId);
      expect(group.totalMaterials, 2);
    });

    test('resolve grupo a partir do id da cifra', () {
      final group = findSwapMaterialGroup(
        pdfId: chordId,
        source: ColdigomCatalogSource(
          louvores: {coldigomPdfId: coldigomPdf},
          chords: {chordId: chord},
        ),
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
        source: ColdigomCatalogSource(
          louvores: {coldigomPdfId: coldigomPdf},
          chords: {
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
        ),
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
