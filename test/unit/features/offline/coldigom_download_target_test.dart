import 'dart:convert';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/utils/material_id_kind.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/offline/domain/entities/coldigom_download_target.dart';
import 'package:flutter_test/flutter_test.dart';

ColdigomPraiseCache _row(
  String id,
  String number,
  String name,
  List<Map<String, Object?>> materials,
) => ColdigomPraiseCache()
  ..praiseId = id
  ..number = number
  ..name = name
  ..author = ''
  ..rhythm = ''
  ..tonality = ''
  ..category = ''
  ..tags = const []
  ..lyrics = ''
  ..materialsJson = jsonEncode(materials)
  ..searchTokens = '';

Map<String, Object?> _m(
  String id,
  String kind,
  String type, {
  int? size,
  String? r2,
}) => {
  'id': id,
  'kind': kind,
  'kindName': kind,
  'type': type,
  'r2': r2 ?? 'assets/praises/x/$id.$type',
  'size': ?size,
};

void main() {
  final rows = [
    _row('p2', '010', 'Dez', [_m('m-pdf', 'k-grade', 'pdf', size: 1000)]),
    _row('p1', '002', 'Dois', [
      _m('m-mp3', 'k-play', 'mp3'),
      _m('m-chord', 'k-cifra', 'chord'),
      _m('m-gest', 'k-gest', 'gestures'),
      {
        'id': 'yt',
        'kind': 'k-yt',
        'kindName': '',
        'type': 'youtube',
        'r2': null,
        'url': 'https://youtu.be/x',
      },
      {
        'id': 'm-sem-r2',
        'kind': 'k-grade',
        'kindName': '',
        'type': 'pdf',
        'r2': null,
      },
    ]),
    _row('p3', '', 'Sem número', [_m('m-pdf3', 'k-grade', 'pdf')]),
  ];

  test('filtra por kind e tipo baixável, ignora youtube e sem r2Key', () {
    final targets = coldigomDownloadTargetsFrom(
      rows,
      kindIds: {'k-grade', 'k-play', 'k-yt'},
    );

    expect(targets.map((t) => t.materialId), ['m-mp3', 'm-pdf', 'm-pdf3']);
    expect(targets.first.kind, MaterialKind.audio);
    expect(targets.first.localId, encodePdfId('assets/praises/x/m-mp3.mp3'));
    expect(targets.first.praiseName, 'Dois');
  });

  test('ordena por número (numérico, vazios no fim) e depois nome', () {
    final targets = coldigomDownloadTargetsFrom(
      rows,
      kindIds: {'k-grade', 'k-play', 'k-cifra', 'k-gest'},
    );

    expect(targets.map((t) => t.praiseNumber), [
      '002',
      '002',
      '002',
      '010',
      '',
    ]);
  });

  test('estimativa: size quando existe, senão média por tipo com marca ~', () {
    final targets = coldigomDownloadTargetsFrom(
      rows,
      kindIds: {'k-grade', 'k-play', 'k-cifra', 'k-gest'},
    );
    final byId = {for (final t in targets) t.materialId: t};

    expect(byId['m-pdf']!.estimatedBytes, 1000);
    expect(byId['m-pdf']!.sizeIsEstimated, isFalse);
    expect(byId['m-mp3']!.estimatedBytes, 4 * 1024 * 1024);
    expect(byId['m-mp3']!.sizeIsEstimated, isTrue);
    expect(byId['m-chord']!.estimatedBytes, 1024);
    expect(byId['m-gest']!.estimatedBytes, 60 * 1024);
  });

  test('isColdigomDownloadableType', () {
    expect(
      [
        'pdf',
        'MP3',
        'audio',
        'chord',
        'gestures',
      ].every(isColdigomDownloadableType),
      isTrue,
    );
    expect(isColdigomDownloadableType('youtube'), isFalse);
    expect(isColdigomDownloadableType('lyrics'), isFalse);
  });
}
