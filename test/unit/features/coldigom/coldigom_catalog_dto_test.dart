import 'dart:convert';
import 'dart:io';

import 'package:coldigui/features/coldigom/data/models/coldigom_catalog_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture() => jsonDecode(
  File('test/fixtures/coldigom_catalog_sample.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  test('parseia kinds e praises do dump', () {
    final dto = ColdigomCatalogDto.fromJson(_fixture());

    expect(dto.generatedAt, '2026-09-14T12:00:00.000Z');
    expect(dto.kindNames, {
      'k-grade': 'Grade',
      'k-playback': 'Playback',
      'k-cifra': 'Cifra',
      'k-gestos': 'Gestos',
    });
    expect(dto.praises, hasLength(3));
    final first = dto.praises.first;
    expect(first.id, 'p-001');
    expect(first.number, '001');
    expect(first.name, 'Ainda há tempo');
    expect(first.tags, ['Avulsos', 'PES']);
    expect(first.lyrics, 'Ainda há tempo\nde voltar ao Senhor');
  });

  test(
    'r2Key derivado por tipo: assets/praises/<praiseId>/<materialId>.<ext>',
    () {
      final materials = ColdigomCatalogDto.fromJson(_fixture())
          .praises
          .first
          .materials;
      final byId = {for (final m in materials) m.id: m};

      expect(byId['m-pdf']!.r2Key, 'assets/praises/p-001/m-pdf.pdf');
      expect(byId['m-mp3']!.r2Key, 'assets/praises/p-001/m-mp3.mp3');
      expect(byId['m-chord']!.r2Key, 'assets/praises/p-001/m-chord.chord');
      expect(byId['m-gest']!.r2Key, 'assets/praises/p-001/m-gest.gestures');
      expect(byId['m-pdf']!.kindId, 'k-grade');
      expect(byId['m-pdf']!.size, 312345);
      expect(byId['m-mp3']!.size, isNull);
    },
  );

  test('youtube usa url e não tem r2Key', () {
    final yt = ColdigomCatalogDto.fromJson(_fixture())
        .praises
        .first
        .materials
        .last;

    expect(yt.type, 'youtube');
    expect(yt.kindId, isNull);
    expect(yt.url, 'https://www.youtube.com/watch?v=1Pks43ceAac');
    expect(yt.r2Key, isNull);
  });

  test('r2 explícito tem precedência sobre o derivado', () {
    final odd = ColdigomCatalogDto.fromJson(_fixture())
        .praises[1]
        .materials
        .single;

    expect(odd.type, 'audio');
    expect(odd.r2Key, 'assets/praises/p-002/m-odd.m4a');
  });

  test('lyrics ausente vira string vazia; campos ausentes viram vazios', () {
    final praises = ColdigomCatalogDto.fromJson(_fixture()).praises;

    expect(praises[1].lyrics, '');
    expect(praises[2].number, '');
    expect(praises[2].materials, isEmpty);
    expect(praises[2].tags, ['Coro']);
  });

  test('material corrompido é descartado sem derrubar o praise', () {
    final json = _fixture();
    final praise = (json['praises'] as List).first as Map<String, dynamic>;
    (praise['materials'] as List).add('não é um mapa');

    final dto = ColdigomCatalogDto.fromJson(json);

    expect(dto.praises.first.materials, hasLength(5));
  });

  test('tipo desconhecido com r2 explícito usa o valor explícito', () {
    final json = _fixture();
    final praise = (json['praises'] as List)[1] as Map<String, dynamic>;
    (praise['materials'] as List).add({
      'id': 'm-unknown-r2',
      'kind': 'k-playback',
      'type': 'zip',
      'r2': 'assets/praises/p-002/m-unknown-r2.zip',
    });

    final materials = ColdigomCatalogDto.fromJson(json).praises[1].materials;
    final unknown = materials.firstWhere((m) => m.id == 'm-unknown-r2');

    expect(unknown.type, 'zip');
    expect(unknown.r2Key, 'assets/praises/p-002/m-unknown-r2.zip');
  });

  test('tipo desconhecido sem r2 não é endereçável (r2Key nulo)', () {
    final json = _fixture();
    final praise = (json['praises'] as List)[1] as Map<String, dynamic>;
    (praise['materials'] as List).add({
      'id': 'm-unknown-sem-r2',
      'kind': 'k-playback',
      'type': 'zip',
    });

    final materials = ColdigomCatalogDto.fromJson(json).praises[1].materials;
    final unknown = materials.firstWhere((m) => m.id == 'm-unknown-sem-r2');

    expect(unknown.type, 'zip');
    expect(unknown.r2Key, isNull);
  });

  test('coldigomCatalogExtensionForType cobre os quatro tipos baixáveis', () {
    expect(coldigomCatalogExtensionForType('pdf'), 'pdf');
    expect(coldigomCatalogExtensionForType('MP3'), 'mp3');
    expect(coldigomCatalogExtensionForType('audio'), 'mp3');
    expect(coldigomCatalogExtensionForType('chord'), 'chord');
    expect(coldigomCatalogExtensionForType('gestures'), 'gestures');
    expect(coldigomCatalogExtensionForType('youtube'), isNull);
    expect(coldigomCatalogExtensionForType('lyrics'), isNull);
  });

  test('praises com tipo errado (string) vira lista vazia sem lançar', () {
    final json = _fixture();
    json['praises'] = 'não é uma lista';

    final dto = ColdigomCatalogDto.fromJson(json);

    expect(dto.praises, isEmpty);
  });

  test('kinds com tipo errado (map) vira mapa vazio sem lançar', () {
    final json = _fixture();
    json['kinds'] = {'não': 'é uma lista'};

    final dto = ColdigomCatalogDto.fromJson(json);

    expect(dto.kindNames, isEmpty);
  });

  test('material com size de tipo errado é mantido com size nulo', () {
    final json = _fixture();
    final praise = (json['praises'] as List).first as Map<String, dynamic>;
    (praise['materials'] as List).add({
      'id': 'm-size-errado',
      'kind': 'k-grade',
      'type': 'pdf',
      'size': 'big',
    });

    final materials = ColdigomCatalogDto.fromJson(json).praises.first.materials;
    final material = materials.firstWhere((m) => m.id == 'm-size-errado');

    expect(material.size, isNull);
    expect(material.r2Key, 'assets/praises/p-001/m-size-errado.pdf');
  });
}
