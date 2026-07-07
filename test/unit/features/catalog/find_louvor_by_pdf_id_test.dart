import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_by_pdf_id.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_group_by_pdf_id.dart';
import 'package:coldigui/features/catalog/domain/utils/louvor_group_id.dart';
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

  group('findLouvorGroupByPdfIdWithColdigom', () {
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

    final coldigomPartitura = Louvor.fromManifest(
      nome: 'Grande Deus',
      numero: '001',
      categoria: 'Partitura',
      classificacao: 'Country',
      pdf: 'm1.pdf',
      pdfId: encodePdfId('assets/praises/p1/m1.pdf'),
      groupId: 'p1',
      source: LouvorDataSource.coldigom,
    );

    final coldigomCifra = Louvor.fromManifest(
      nome: 'Grande Deus',
      numero: '001',
      categoria: 'Cifra I',
      classificacao: 'Country',
      pdf: 'm2.pdf',
      pdfId: encodePdfId('assets/praises/p1/m2.pdf'),
      groupId: 'p1',
      source: LouvorDataSource.coldigom,
    );

    test('agrupa irmãos coldigom no cache', () {
      final group = findLouvorGroupByPdfIdWithColdigom(
        const [],
        coldigomPartitura.pdfId,
        coldigomCache: {
          coldigomPartitura.pdfId: coldigomPartitura,
          coldigomCifra.pdfId: coldigomCifra,
        },
      );

      expect(group, isNotNull);
      expect(group!.totalMaterials, 2);
      expect(group.groupId, 'p1');
    });

    test('agrupa irmãos PLPCG no manifest', () {
      final group = findLouvorGroupByPdfIdWithColdigom([
        plpcgPartitura,
        plpcgCifra,
      ], plpcgPartitura.pdfId);

      expect(group, isNotNull);
      expect(group!.totalMaterials, 2);
    });

    test('não mistura PLPCG e coldigom com mesmo groupId', () {
      final plpcgGroup = findLouvorGroupByPdfIdWithColdigom(
        [plpcgPartitura, plpcgCifra],
        plpcgPartitura.pdfId,
        coldigomCache: {
          coldigomPartitura.pdfId: coldigomPartitura,
          coldigomCifra.pdfId: coldigomCifra,
        },
      );

      expect(plpcgGroup!.totalMaterials, 2);
      expect(
        plpcgGroup.sections
            .expand((s) => s.materials)
            .every((m) => m.louvor.source == LouvorDataSource.plpcg),
        isTrue,
      );

      final coldigomGroup = findLouvorGroupByPdfIdWithColdigom(
        [plpcgPartitura, plpcgCifra],
        coldigomPartitura.pdfId,
        coldigomCache: {
          coldigomPartitura.pdfId: coldigomPartitura,
          coldigomCifra.pdfId: coldigomCifra,
        },
      );

      expect(coldigomGroup!.totalMaterials, 2);
      expect(
        coldigomGroup.sections
            .expand((s) => s.materials)
            .every((m) => m.louvor.source == LouvorDataSource.coldigom),
        isTrue,
      );
    });

    test('retorna null para material único', () {
      expect(
        findLouvorGroupByPdfIdWithColdigom([
          plpcgPartitura,
        ], plpcgPartitura.pdfId),
        isNull,
      );
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
