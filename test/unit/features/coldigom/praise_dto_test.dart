import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MaterialDto.fromJson', () {
    test('type nulo vira unknown', () {
      final dto = MaterialDto.fromJson({'id': 'm1', 'type': null});
      expect(dto.type, 'unknown');
    });

    test('type não-string vira unknown', () {
      final dto = MaterialDto.fromJson({'id': 'm1', 'type': 42});
      expect(dto.type, 'unknown');
    });

    test('type string válido é preservado', () {
      final dto = MaterialDto.fromJson({'id': 'm1', 'type': 'pdf'});
      expect(dto.type, 'pdf');
    });

    test('lê material_kind como materialKindId e tolera ausência', () {
      final withKind = MaterialDto.fromJson({
        'id': 'm1',
        'type': 'pdf',
        'material_kind': 'kind-uuid',
        'material_kind_name': 'Partitura',
      });
      expect(withKind.materialKindId, 'kind-uuid');

      final without = MaterialDto.fromJson({'id': 'm2', 'type': 'pdf'});
      expect(without.materialKindId, isNull);
    });
  });

  group('PraiseDetailDto.fromJson', () {
    test('descarta material cujo fromJson lança e mantém os demais', () {
      final detail = PraiseDetailDto.fromJson({
        'id': 'p1',
        'name': 'Hino',
        'number': '001',
        'rhythm': 'Fox',
        'materials': [
          {'id': 'm1', 'type': 'pdf'},
          'não é um mapa', // força exceção no cast dentro do fromJson
          {'id': 'm2', 'type': 'chord'},
        ],
      });

      expect(detail.materials, hasLength(2));
      expect(detail.materials[0].id, 'm1');
      expect(detail.materials[1].id, 'm2');
    });

    test('lista de materials totalmente inválida resulta em lista vazia', () {
      final detail = PraiseDetailDto.fromJson({
        'id': 'p1',
        'name': 'Hino',
        'number': '001',
        'rhythm': 'Fox',
        'materials': ['x', 42, null],
      });

      expect(detail.materials, isEmpty);
    });

    test('lê lyrics_excerpt quando presente e tolera ausência', () {
      final comTrecho = PraiseDetailDto.fromJson({
        'id': 'p1',
        'name': 'Hino',
        'number': '001',
        'rhythm': 'Fox',
        'lyrics_excerpt': '…e a chuva de bênçãos cai sobre nós…',
        'materials': const [],
      });
      expect(comTrecho.lyricsExcerpt, '…e a chuva de bênçãos cai sobre nós…');

      final semTrecho = PraiseDetailDto.fromJson({
        'id': 'p2',
        'name': 'Hino',
        'number': '002',
        'rhythm': 'Fox',
        'materials': const [],
      });
      expect(semTrecho.lyricsExcerpt, isNull);
    });
  });
}
