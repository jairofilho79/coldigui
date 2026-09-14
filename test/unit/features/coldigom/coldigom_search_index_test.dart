import 'package:coldigui/features/catalog/domain/entities/louvor_group.dart';
import 'package:coldigui/features/coldigom/data/mappers/coldigom_praise_cache_mapper.dart';
import 'package:coldigui/features/coldigom/domain/search/coldigom_search_index.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('número exato primeiro (com e sem pad)', () {
    expect(ids('10').first, 'p2');
    expect(ids('010').first, 'p2');
    expect(ids('1').first, 'p1');
  });

  test('título exato antes do parcial; ordem estável entre iguais', () {
    // p2 ("Tempo de louvar") fica de fora: o match parcial exige TODOS os
    // tokens da query como prefixo de algum token do praise (E lógico, igual
    // a `SearchLouvorByNumberOrText`/`matchesText`) — "ainda" e "ha" não
    // prefixam nenhum token de p2.
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
}
