import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../helpers/legacy_isar/coldigom_praise_cache_v1.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('isar_praise_cache_mig_');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  // `isar` é o motor nativo; `sqlite` é o da web (isar_bootstrap_web.dart),
  // onde está a maior parte dos caches gravados com `category`.
  for (final engine in [IsarEngine.isar, IsarEngine.sqlite]) {
    test('cache gravado com category (fase 2) abre com o schema atual '
        '(${engine.name})', () {
      final antigo = Isar.open(
        schemas: [ColdigomPraiseCacheV1Schema],
        directory: dir.path,
        engine: engine,
      );
      antigo.write((isar) {
        final row = ColdigomPraiseCacheV1()
          ..praiseId = 'p1'
          ..number = '001'
          ..name = 'Ainda há tempo'
          ..author = ''
          ..rhythm = ''
          ..tonality = 'Dm'
          ..category = 'Clamor'
          ..tags = ['Coletânea · Clamor']
          ..lyrics = ''
          ..materialsJson = '[]'
          ..searchTokens = 'ainda ha tempo'
          ..shortId = '2cf';
        row.id = isar.coldigomPraiseCacheV1s.autoIncrement();
        isar.coldigomPraiseCacheV1s.put(row);
      });
      antigo.close();

      final atual = Isar.open(
        schemas: [ColdigomPraiseCacheSchema],
        directory: dir.path,
        engine: engine,
      );
      addTearDown(() => atual.close(deleteFromDisk: true));
      final lido = atual.coldigomPraiseCaches
          .where()
          .praiseIdEqualTo('p1')
          .findFirst();
      expect(lido, isNotNull);
      expect(lido!.name, 'Ainda há tempo');
      expect(lido.tonality, 'Dm');
      expect(lido.tags, ['Coletânea · Clamor']);
      expect(lido.searchTokens, 'ainda ha tempo');
      expect(lido.shortId, '2cf');

      // O próximo sync grava por cima com o schema novo.
      atual.write((isar) {
        final novo = ColdigomPraiseCache()
          ..praiseId = 'p2'
          ..number = '002'
          ..name = 'Outro'
          ..author = ''
          ..rhythm = ''
          ..tonality = ''
          ..tags = const []
          ..lyrics = ''
          ..materialsJson = '[]'
          ..searchTokens = 'outro';
        novo.id = isar.coldigomPraiseCaches.autoIncrement();
        isar.coldigomPraiseCaches.put(novo);
      });
      expect(atual.coldigomPraiseCaches.count(), 2);
    });
  }
}
