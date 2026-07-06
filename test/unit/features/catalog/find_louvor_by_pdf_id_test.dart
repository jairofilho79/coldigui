import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/catalog/domain/utils/find_louvor_by_pdf_id.dart';
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
}
