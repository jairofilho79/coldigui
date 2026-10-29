import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';

ColdigomIndexedPraise _entry(
  String id,
  String numero,
  String nome, {
  String author = '',
  List<String> tags = const [],
}) {
  return ColdigomIndexedPraise.build(
    praiseId: id,
    numero: numero,
    nome: nome,
    searchTokens: ColdigomPraiseCacheMapper.buildSearchTokens(
      name: nome,
      number: numero,
      author: author,
      tags: tags,
    ),
    group: LouvorGroup(
      groupId: id,
      numero: numero,
      nome: nome,
      sections: const [],
    ),
  );
}

void main() {
  final index = ColdigomSearchIndex.build([
    _entry('p1', '001', 'Ainda há tempo', tags: const ['PES']),
    _entry('p2', '010', 'Tempo de louvar'),
    _entry('p3', '100', 'São João', author: 'Autor Dois'),
    _entry('p4', '', 'Ainda há tempo', tags: const ['Coro']),
  ]);

  List<String> ids(String query) =>
      index.search(query).map((g) => g.groupId).toList();

  test('índice vazio devolve vazio; query vazia devolve vazio', () {
    expect(ColdigomSearchIndex.empty.search('tempo'), isEmpty);
    expect(index.search('   '), isEmpty);
    expect(index.praiseIds, {'p1', 'p2', 'p3', 'p4'});
  });

  test('sem catalogIds explícito, cai para praiseIds', () {
    expect(index.catalogIds, index.praiseIds);
  });

  test('catalogIds ⊇ praiseIds e inclui ids sem material endereçável '
      '(ex. praise só-YouTube, que fica fora de praiseIds)', () {
    final withCatalogIds = ColdigomSearchIndex.build(
      [_entry('p1', '001', 'Ainda há tempo')],
      catalogIds: {'p1', 'p-yt'},
    );
    expect(withCatalogIds.catalogIds, containsAll(withCatalogIds.praiseIds));
    expect(withCatalogIds.catalogIds, containsAll(['p1', 'p-yt']));
    expect(withCatalogIds.praiseIds, isNot(contains('p-yt')));
  });

  test('número exato primeiro (com e sem pad)', () {
    expect(ids('10').first, 'p2');
    expect(ids('010').first, 'p2');
    expect(ids('1').first, 'p1');
  });

  test('título exato antes do parcial; ordem estável entre iguais', () {
    // p2 ("Tempo de louvar") fica de fora: o match parcial exige TODOS os
    // tokens da query como prefixo de algum token do praise (E lógico, como
    // em `matchesText`) — "ainda" e "ha" não prefixam nenhum token de p2.
    expect(ids('ainda há tempo'), ['p1', 'p4']);
    expect(ids('Ainda ha tempo'), ['p1', 'p4']);
  });

  test('parcial sem acento por prefixo de token e compacto', () {
    expect(ids('tem'), ['p1', 'p2', 'p4']);
    expect(ids('aindaha'), ['p1', 'p4']);
    expect(ids('joao'), ['p3']);
  });

  test('tags e autor entram na busca', () {
    expect(ids('pes'), ['p1']);
    expect(ids('coro'), ['p4']);
    expect(ids('autor dois'), ['p3']);
  });

  test('sem hit devolve vazio e nunca repete um praise', () {
    expect(ids('zzz'), isEmpty);
    final all = ids('a');
    expect(all.toSet().length, all.length);
  });

  // Fix round 1 — `compactContent` é só o compacto do título (como
  // `Louvor.searchCompactContent` no PLPCG), não o compacto de todos os
  // tokens pesquisáveis (nome+autor+tags+número).
  test('compactContent não cria ponte entre nome e autor', () {
    // p3 é "São João" de "Autor Dois": se compactContent fosse o compacto de
    // todos os tokens, "saojoao" + "autor" + "dois" + "100" concatenados
    // conteriam "joaoau" (fim de "joao" + início de "autor") — falso
    // positivo. Compacto só do título ("saojoao") não contém "joaoau".
    expect(ids('joaoau'), isEmpty);
  });

  test('compactContent mantém stop words do título, como o PLPCG', () {
    // "A Ti, Senhor" → compacto do título é "atisenhor" (a vírgula e os
    // espaços são separadores removidos por `compact`, mas o "a" inicial —
    // stop word — fica, porque `compact` normaliza o texto inteiro sem
    // tokenizar). Igual a `Louvor.searchCompactContent` no PLPCG.
    final localIndex = ColdigomSearchIndex.build([
      _entry('b1', '200', 'A Ti, Senhor'),
    ]);
    expect(localIndex.search('atisenh').map((g) => g.groupId).toList(), ['b1']);
  });

  group('mapas O(1) (C4)', () {
    final aleluia = catalogGroup(
      praiseId: 'p1',
      number: '001',
      name: 'Aleluia',
      shortId: '000',
      pdfKinds: const {'k-grade': 'Grade'},
      audioKinds: const {'k-play': 'Playback'},
    );
    final semShortId = catalogGroup(
      praiseId: 'p2',
      number: '002',
      name: 'Sem shortId',
    );
    final mapped = catalogIndexOf([aleluia, semShortId]);

    test('groups segue a ordem das entries; vazio no índice vazio', () {
      expect(mapped.groups.map((g) => g.groupId), ['p1', 'p2']);
      expect(ColdigomSearchIndex.empty.groups, isEmpty);
    });

    test(
      'groupByShortId acha o praise, normaliza a entrada e ignora inválidos',
      () {
        expect(mapped.groupByShortId('000')?.groupId, 'p1');
        expect(mapped.groupByShortId(' 000 ')?.groupId, 'p1');
        expect(mapped.groupByShortId('fff'), isNull);
        expect(mapped.groupByShortId('zz'), isNull);
        expect(ColdigomSearchIndex.empty.groupByShortId('000'), isNull);
      },
    );

    test('groupByShortId acha praise cujo shortId nos metadados é '
        'mixed-case/com espaço (o build normaliza igual à busca)', () {
      final mistoCase = catalogGroup(
        praiseId: 'p5',
        number: '005',
        name: 'Grão de mostarda',
        shortId: ' 0A1 ',
      );
      final withMistoCase = catalogIndexOf([aleluia, semShortId, mistoCase]);
      expect(withMistoCase.groupByShortId('0a1')?.groupId, 'p5');
      expect(withMistoCase.groupByShortId(' 0A1 ')?.groupId, 'p5');
    });

    test('groupForMaterialId cobre todo material do grupo', () {
      expect(aleluia.materials, hasLength(2));
      for (final material in aleluia.materials) {
        expect(
          mapped.groupForMaterialId(material.id)?.groupId,
          'p1',
          reason: material.id,
        );
      }
      expect(mapped.groupForMaterialId('desconhecido'), isNull);
    });
  });
}
