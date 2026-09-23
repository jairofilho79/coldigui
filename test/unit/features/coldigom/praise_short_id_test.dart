import 'dart:convert';
import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/data/adapters/coldigom_louvor_adapter.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:coldigui/features/coldigom/domain/utils/praise_short_id.dart';
import 'package:flutter_test/flutter_test.dart';

ColdigomCatalogDto _catalog() => ColdigomCatalogDto.fromJson(
  jsonDecode(
    File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync(),
  ) as Map<String, dynamic>,
);

void main() {
  group('normalizePraiseShortId', () {
    test('aceita [0-9a-f]{3,8}; normaliza maiúsculas e espaços', () {
      expect(normalizePraiseShortId('1a2'), '1a2');
      expect(normalizePraiseShortId(' 0A1 '), '0a1');
      expect(normalizePraiseShortId('1000'), '1000');
      expect(normalizePraiseShortId('abcdef01'), 'abcdef01');
    });

    test('fora do padrão, vazio ou não-string → null (nunca lança)', () {
      for (final raw in <Object?>[
        null,
        '',
        '12',
        '123456789',
        'xyz',
        '1g2',
        7,
      ]) {
        expect(normalizePraiseShortId(raw), isNull, reason: '$raw');
      }
    });
  });

  group('shortId atravessa as camadas', () {
    test('dump: um shortId por praise; ausente fica null', () {
      final praises = _catalog().praises;

      expect(praises[0].shortId, '000');
      expect(praises[1].shortId, '0a1');
      expect(praises[2].shortId, isNull);
    });

    test('dump com shortId inválido vira null sem derrubar o praise', () {
      final dto = ColdigomCatalogPraiseDto.fromJson({
        'id': 'p',
        'shortId': 'ZZ',
        'materials': <Object>[],
      });

      expect(dto.id, 'p');
      expect(dto.shortId, isNull);
    });

    test('API: short_id no detalhe e no resumo', () {
      final detail = PraiseDetailDto.fromJson({
        'id': 'p1',
        'name': 'Hino',
        'short_id': '00F',
      });
      final summary = PraiseSummaryDto.fromJson({
        'id': 'p1',
        'name': 'Hino',
        'short_id': '00f',
      });

      expect(detail.shortId, '00f');
      expect(summary.shortId, '00f');
      expect(
        PraiseDetailDto.fromJson({'id': 'p2', 'name': 'x'}).shortId,
        isNull,
      );
    });

    test('linha Isar → detalhe → metadados preservam o shortId', () {
      final catalog = _catalog();
      final row = ColdigomPraiseCacheMapper.fromCatalogPraise(
        catalog.praises.first,
        kindNames: catalog.kindNames,
      );

      expect(row.shortId, '000');
      final detail = ColdigomPraiseCacheMapper.toPraiseDetail(row);
      expect(detail.shortId, '000');
      expect(ColdigomLouvorAdapter.toMetadata(detail).shortId, '000');
      expect(ColdigomPraiseCache().shortId, isNull);
    });

    test('página remota e adoção de «novos» levam o shortId à linha', () {
      final detail = PraiseDetailDto.fromJson({
        'id': 'p9',
        'name': 'Novo',
        'number': '9',
        'short_id': 'a0b',
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
        ).shortId,
        'a0b',
      );

      final group = LouvorGroup.fromLouvores(
        ColdigomLouvorAdapter.toLouvores(detail),
        coldigomMetaByGroupId: {'p9': ColdigomLouvorAdapter.toMetadata(detail)},
      ).single;
      expect(ColdigomPraiseCacheMapper.fromLouvorGroup(group).shortId, 'a0b');
    });
  });
}
