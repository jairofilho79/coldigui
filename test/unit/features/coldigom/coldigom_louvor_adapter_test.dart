import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_data_source.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ColdigomLouvorAdapter', () {
    test('mapeia PDFs com source coldigom e pdfId do r2_key', () {
      const praise = PraiseDetailDto(
        id: 'praise-1',
        name: 'Grande Deus',
        number: '001',
        rhythm: 'Coletânea',
        materials: [
          MaterialDto(
            id: 'mat-1',
            type: 'pdf',
            r2Key: 'assets/praises/praise-1/mat-1.pdf',
            materialKindName: 'Partitura',
          ),
          MaterialDto(
            id: 'mat-2',
            type: 'mp3',
            r2Key: 'assets/praises/praise-1/mat-2.mp3',
          ),
        ],
      );

      final louvores = ColdigomLouvorAdapter.toLouvores(praise);

      expect(louvores, hasLength(1));
      expect(louvores.first.nome, 'Grande Deus');
      expect(louvores.first.numero, '001');
      expect(louvores.first.categoria, 'Partitura');
      expect(louvores.first.classificacao, 'Coletânea');
      expect(louvores.first.pdf, 'mat-1.pdf');
      expect(louvores.first.groupId, 'praise-1');
      expect(louvores.first.source, LouvorDataSource.coldigom);
      expect(
        louvores.first.pdfId,
        encodePdfId('assets/praises/praise-1/mat-1.pdf'),
      );
    });
  });
}
