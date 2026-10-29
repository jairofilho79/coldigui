import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/domain/utils/praise_group_id.dart';
import 'package:flutter_test/flutter_test.dart';

const _anchor = '3f2a9c1e-0000-4000-8000-000000000001';

void main() {
  group('normalizePraiseGroupId', () {
    test('string não vazia → aparada, com a caixa preservada', () {
      expect(normalizePraiseGroupId(_anchor), _anchor);
      expect(normalizePraiseGroupId('  AbC '), 'AbC');
    });

    test('nulo, vazio, só espaços ou não-string → null (nunca lança)', () {
      for (final raw in <Object?>[null, '', '   ', 7, true]) {
        expect(normalizePraiseGroupId(raw), isNull, reason: '$raw');
      }
    });
  });

  group('groupId atravessa as camadas', () {
    ColdigomCatalogPraiseDto dump(Map<String, dynamic> extra) =>
        ColdigomCatalogPraiseDto.fromJson({
          'id': 'p1',
          'name': 'Hino',
          'materials': <Object>[],
          ...extra,
        });

    test('dump: groupId lido; ausente ou vazio fica null', () {
      expect(dump({'groupId': _anchor}).groupId, _anchor);
      expect(dump({}).groupId, isNull);
      expect(dump({'groupId': ' '}).groupId, isNull);
    });

    test('API: group_id no detalhe; ausente ou vazio fica null', () {
      PraiseDetailDto detail(Map<String, dynamic> extra) =>
          PraiseDetailDto.fromJson({'id': 'p1', 'name': 'Hino', ...extra});

      expect(detail({'group_id': _anchor}).groupId, _anchor);
      expect(detail({}).groupId, isNull);
      expect(detail({'group_id': ''}).groupId, isNull);
    });

    test('dump → linha Isar → detalhe → metadados preservam o groupId', () {
      final row = ColdigomPraiseCacheMapper.fromCatalogPraise(
        dump({'groupId': _anchor}),
        kindNames: const {},
      );

      expect(row.groupId, _anchor);
      final detail = ColdigomPraiseCacheMapper.toPraiseDetail(row);
      expect(detail.groupId, _anchor);
      expect(ColdigomLouvorAdapter.toMetadata(detail).groupId, _anchor);
      expect(ColdigomPraiseCache().groupId, isNull);
    });

    test('página remota e adoção de «novos» levam o groupId à linha', () {
      final detail = PraiseDetailDto.fromJson({
        'id': 'p9',
        'name': 'Novo',
        'number': '9',
        'group_id': _anchor,
        'materials': [
          {
            'id': 'm1',
            'type': 'pdf',
            'r2_key': 'assets/praises/p9/m1.pdf',
            'material_kind': 'k1',
          },
        ],
      });

      expect(
        ColdigomPraiseCacheMapper.fromPraiseDetail(
          detail,
          kindNames: const {},
        ).groupId,
        _anchor,
      );

      final group = LouvorGroup.fromLouvores(
        ColdigomLouvorAdapter.toLouvores(detail),
        coldigomMetaByGroupId: {'p9': ColdigomLouvorAdapter.toMetadata(detail)},
      ).single;
      expect(group.coldigomMeta?.groupId, _anchor);
      expect(ColdigomPraiseCacheMapper.fromLouvorGroup(group).groupId, _anchor);
    });
  });
}
