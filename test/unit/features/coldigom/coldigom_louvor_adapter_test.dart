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

    test('ignora material type lyrics (ainda sem suporte na UI)', () {
      const praise = PraiseDetailDto(
        id: 'praise-1',
        name: 'Hino',
        number: '001',
        rhythm: 'Fox',
        materials: [
          MaterialDto(
            id: 'lyrics:praise-1',
            type: 'lyrics',
            materialKindName: 'Letra',
          ),
          MaterialDto(
            id: 'mat-1',
            type: 'pdf',
            r2Key: 'assets/praises/praise-1/mat-1.pdf',
            materialKindName: 'Partitura',
          ),
        ],
      );

      expect(ColdigomLouvorAdapter.toLouvores(praise), hasLength(1));
      expect(ColdigomLouvorAdapter.toAudioTracks(praise), isEmpty);
      expect(ColdigomLouvorAdapter.toYoutubeMaterials(praise), isEmpty);
    });

    test('propaga materialKindId para as cinco famílias', () {
      const praise = PraiseDetailDto(
        id: 'praise-1',
        name: 'Grande Deus',
        number: '001',
        rhythm: 'Coletânea',
        materials: [
          MaterialDto(
            id: 'p',
            type: 'pdf',
            r2Key: 'a/p.pdf',
            materialKindId: 'k-pdf',
          ),
          MaterialDto(
            id: 'a',
            type: 'mp3',
            r2Key: 'a/a.mp3',
            materialKindId: 'k-audio',
          ),
          MaterialDto(
            id: 'c',
            type: 'chord',
            r2Key: 'a/c.chord',
            materialKindId: 'k-chord',
          ),
          MaterialDto(
            id: 'g',
            type: 'gestures',
            r2Key: 'a/g.gestures',
            materialKindId: 'k-gesture',
          ),
          MaterialDto(
            id: 'y',
            type: 'youtube',
            url: 'https://www.youtube.com/watch?v=1Pks43ceAac',
            materialKindId: 'k-yt',
          ),
        ],
      );

      expect(
        ColdigomLouvorAdapter.toLouvores(praise).single.materialKindId,
        'k-pdf',
      );
      expect(
        ColdigomLouvorAdapter.toAudioTracks(praise).single.materialKindId,
        'k-audio',
      );
      expect(
        ColdigomLouvorAdapter.toChordMaterials(praise).single.materialKindId,
        'k-chord',
      );
      expect(
        ColdigomLouvorAdapter.toGestureMaterials(praise).single.materialKindId,
        'k-gesture',
      );
      expect(
        ColdigomLouvorAdapter.toYoutubeMaterials(praise).single.materialKindId,
        'k-yt',
      );
    });
  });

  // Migrado de test/widget/features/coldigom/coldigom_material_sheet_test.dart
  // (o sheet Coldigom virou o MaterialSheet único).
  test('toMetadata e DetailDto parseiam tag_names', () {
    final detail = PraiseDetailDto.fromJson({
      'id': 'p1',
      'name': 'Hino',
      'number': '001',
      'rhythm': 'Fox',
      'tonality': 'G',
      'category': 'Clamor',
      'author': 'Autor',
      'tag_names': 'PES,Coletânea',
      'materials': const [],
    });

    expect(detail.tagNames, ['PES', 'Coletânea']);

    final meta = ColdigomLouvorAdapter.toMetadata(detail);
    expect(meta.tonality, 'G');
    expect(meta.rhythm, 'Fox');
    expect(meta.tagNames, ['PES', 'Coletânea']);
    expect(meta.hasAnyField, isTrue);
  });
}
