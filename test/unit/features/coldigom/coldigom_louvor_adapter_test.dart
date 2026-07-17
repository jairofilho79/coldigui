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
      final tracks = ColdigomLouvorAdapter.toAudioTracks(praise);

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

      expect(tracks, hasLength(1));
      expect(
        tracks.first.audioId,
        encodePdfId('assets/praises/praise-1/mat-2.mp3'),
      );
      expect(tracks.first.r2Key, 'assets/praises/praise-1/mat-2.mp3');
      expect(tracks.first.nome, 'Grande Deus');
      expect(tracks.first.groupId, 'praise-1');
      expect(tracks.first.categoria, 'Áudio');
      expect(tracks.first.source, LouvorDataSource.coldigom);
    });

    test('mapeia YouTube com URL válida e ignora url null/inválida', () {
      const praise = PraiseDetailDto(
        id: 'praise-1',
        name: 'Leão',
        number: '010',
        rhythm: 'Fox',
        author: 'CIAS',
        materials: [
          MaterialDto(
            id: 'yt-ok',
            type: 'youtube',
            url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
            materialKindName: 'Áudio',
          ),
          MaterialDto(
            id: 'yt-short',
            type: 'youtube',
            url: 'https://youtu.be/1Pks43ceAac',
            materialKindName: 'Gestos CIAs',
          ),
          MaterialDto(
            id: 'yt-null',
            type: 'youtube',
            url: null,
            materialKindName: 'Áudio',
          ),
          MaterialDto(
            id: 'yt-bad',
            type: 'youtube',
            url: 'https://example.com/v/1',
            materialKindName: 'Áudio',
          ),
        ],
      );

      final items = ColdigomLouvorAdapter.toYoutubeMaterials(praise);

      expect(items, hasLength(2));
      expect(items.first.id, 'yt-ok');
      expect(items.first.url, 'https://www.youtube.com/watch?v=1Pks43ceAac');
      expect(items.first.categoria, 'Áudio');
      expect(items.first.groupId, 'praise-1');
      expect(items.first.author, 'CIAS');
      expect(items.first.source, LouvorDataSource.coldigom);
      expect(items.last.url, 'https://youtu.be/1Pks43ceAac');
    });

    test('fromJson lê campo url do material', () {
      final dto = MaterialDto.fromJson({
        'id': 'm1',
        'type': 'youtube',
        'r2_key': null,
        'url': 'https://www.youtube.com/watch?v=1Pks43ceAac',
        'material_kind_name': 'Áudio',
      });
      expect(dto.url, 'https://www.youtube.com/watch?v=1Pks43ceAac');
    });
  });
}
