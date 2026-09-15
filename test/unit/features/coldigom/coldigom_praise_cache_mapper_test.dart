import 'dart:convert';
import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:coldigui/features/coldigom/data/models/praise_dto.dart';
import 'package:flutter_test/flutter_test.dart';

ColdigomCatalogDto _catalog() => ColdigomCatalogDto.fromJson(
  jsonDecode(
    File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync(),
  ) as Map<String, dynamic>,
);

void main() {
  test('fromCatalogPraise copia metadados, letra e serializa materiais com kindName', () {
    final catalog = _catalog();
    final row = ColdigomPraiseCacheMapper.fromCatalogPraise(
      catalog.praises.first,
      kindNames: catalog.kindNames,
    );

    expect(row.praiseId, 'p-001');
    expect(row.number, '001');
    expect(row.name, 'Ainda há tempo');
    expect(row.tags, ['Avulsos', 'PES']);
    expect(row.lyrics, 'Ainda há tempo\nde voltar ao Senhor');

    final materials = ColdigomPraiseCacheMapper.decodeMaterials(row);
    expect(materials, hasLength(5));
    final pdf = materials.firstWhere((m) => m.id == 'm-pdf');
    expect(pdf.kindId, 'k-grade');
    expect(pdf.kindName, 'Grade');
    expect(pdf.type, 'pdf');
    expect(pdf.r2Key, 'assets/praises/p-001/m-pdf.pdf');
    expect(pdf.size, 312345);
    final yt = materials.firstWhere((m) => m.id == 'yt-1');
    expect(yt.r2Key, isNull);
    expect(yt.url, 'https://www.youtube.com/watch?v=1Pks43ceAac');
    expect(yt.kindName, '');
  });

  test('searchTokens junta nome, número, tags e autor normalizados', () {
    final tokens = ColdigomPraiseCacheMapper.buildSearchTokens(
      name: 'São João',
      number: '2',
      author: 'Autor Dois',
      tags: const ['Coro', 'PES'],
    );

    // Tokens sem acento/stop words, número com pad 3 e cru.
    expect(
      tokens.split(' '),
      containsAll(['sao', 'joao', '002', 'autor', 'dois', 'coro', 'pes']),
    );
  });

  test('toPraiseDetail reconstrói MaterialDto com r2Key/url/kind e acrescenta a letra sintética', () {
    final catalog = _catalog();
    final row = ColdigomPraiseCacheMapper.fromCatalogPraise(
      catalog.praises.first,
      kindNames: catalog.kindNames,
    );

    final detail = ColdigomPraiseCacheMapper.toPraiseDetail(row);

    expect(detail.id, 'p-001');
    expect(detail.rhythm, 'Básico');
    expect(detail.tagNames, ['Avulsos', 'PES']);
    final byId = {for (final m in detail.materials) m.id: m};
    expect(byId['m-mp3']!.r2Key, 'assets/praises/p-001/m-mp3.mp3');
    expect(byId['m-mp3']!.materialKindId, 'k-playback');
    expect(byId['m-mp3']!.materialKindName, 'Playback');
    expect(byId['yt-1']!.url, isNotNull);
    expect(byId['lyrics:p-001']!.type, 'lyrics');
  });

  test(
    'sem letra não há material sintético; r2 explícito sobrevive à ida e volta',
    () {
      final catalog = _catalog();
      final row = ColdigomPraiseCacheMapper.fromCatalogPraise(
        catalog.praises[1],
        kindNames: catalog.kindNames,
      );

      final detail = ColdigomPraiseCacheMapper.toPraiseDetail(row);

      expect(detail.materials.map((m) => m.type), isNot(contains('lyrics')));
      expect(detail.materials.single.r2Key, 'assets/praises/p-002/m-odd.m4a');
    },
  );

  test('material sem r2Key e sem ser youtube não é endereçável e fica fora do detalhe', () {
    final catalog = _catalog();
    final row = ColdigomPraiseCacheMapper.fromCatalogPraise(
      catalog.praises.first,
      kindNames: catalog.kindNames,
    );
    // Tipo desconhecido sem `r2` explícito — não vive no R2, não é youtube.
    final materials = ColdigomPraiseCacheMapper.decodeMaterials(row)
      ..add(
        const ColdigomCatalogMaterialEntry(
          id: 'm-unknown',
          kindId: null,
          kindName: '',
          type: 'unknown',
          r2Key: null,
        ),
      );
    row.materialsJson = jsonEncode([for (final m in materials) m.toJson()]);

    final detail = ColdigomPraiseCacheMapper.toPraiseDetail(row);

    expect(detail.materials.map((m) => m.id), isNot(contains('m-unknown')));
  });

  test('decodeMaterials com texto ilegível devolve lista vazia sem lançar', () {
    final row = ColdigomPraiseCache()..materialsJson = 'not json';

    expect(ColdigomPraiseCacheMapper.decodeMaterials(row), isEmpty);
  });

  test(
    'decodeMaterials com raiz que não é lista devolve lista vazia sem lançar',
    () {
      final row = ColdigomPraiseCache()..materialsJson = '{"a":1}';

      expect(ColdigomPraiseCacheMapper.decodeMaterials(row), isEmpty);
    },
  );

  test('decodeMaterials descarta item malformado sem derrubar os demais', () {
    final row = ColdigomPraiseCache()
      ..materialsJson = jsonEncode([
        {
          'id': 'm-ok',
          'kind': 'k-grade',
          'kindName': 'Grade',
          'type': 'pdf',
          'r2': 'assets/praises/p-001/m-ok.pdf',
        },
        // id de tipo errado (não string) — sem id não há como endereçar o
        // material; size de tipo errado sozinho não derrubaria o item.
        {'id': 123, 'kind': 'k-grade', 'type': 'pdf', 'size': 'abc'},
      ]);

    final materials = ColdigomPraiseCacheMapper.decodeMaterials(row);

    expect(materials, hasLength(1));
    expect(materials.single.id, 'm-ok');
  });

  test('fromPraiseDetail (página de busca) gera a mesma linha que o dump', () {
    final catalog = _catalog();
    final fromDump = ColdigomPraiseCacheMapper.fromCatalogPraise(
      catalog.praises.first,
      kindNames: catalog.kindNames,
    );
    final detail = PraiseDetailDto(
      id: 'p-001',
      name: 'Ainda há tempo',
      number: '001',
      rhythm: 'Básico',
      tonality: 'Dm',
      category: 'Dm',
      tagNames: const ['Avulsos', 'PES'],
      materials: const [
        MaterialDto(
          id: 'm-pdf',
          type: 'pdf',
          r2Key: 'assets/praises/p-001/m-pdf.pdf',
          materialKindId: 'k-grade',
          materialKindName: 'Grade',
        ),
      ],
    );

    final fromPage = ColdigomPraiseCacheMapper.fromPraiseDetail(
      detail,
      kindNames: catalog.kindNames,
      lyrics: 'Ainda há tempo\nde voltar ao Senhor',
    );

    expect(fromPage.praiseId, fromDump.praiseId);
    expect(fromPage.searchTokens, fromDump.searchTokens);
    expect(fromPage.lyrics, fromDump.lyrics);
    final pdf = ColdigomPraiseCacheMapper.decodeMaterials(fromPage).single;
    expect(pdf.r2Key, 'assets/praises/p-001/m-pdf.pdf');
    expect(pdf.kindName, 'Grade');
  });
}
