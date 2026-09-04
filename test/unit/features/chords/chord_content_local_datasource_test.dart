import 'dart:io';

import 'package:coldigui/core/database/collections/chord_content_cache.dart';
import 'package:coldigui/features/chords/data/datasources/chord_content_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../helpers/isar_plus_test_init.dart';

void main() {
  const key = 'assets/praises/p1/m1.chord';
  const content = '{title: Comigo}\n\nA [Bb]noite vem,\n';

  group('ChordContentLocalDatasource — com Isar', () {
    late Directory tempDir;
    late Isar isar;
    late ChordContentLocalDatasource datasource;

    setUpAll(ensureIsarPlusTestCore);

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('chord_cache_test');
      isar = Isar.open(
        schemas: [ChordContentCacheSchema],
        directory: tempDir.path,
      );
      datasource = ChordContentLocalDatasource(isar);
    });

    tearDown(() {
      isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('read devolve null antes de qualquer escrita', () {
      expect(datasource.read(key), isNull);
    });

    test('write persiste o conteudo e read devolve de volta', () {
      datasource.write(key, content);

      expect(datasource.read(key), content);
    });

    test('write duas vezes na mesma chave nao duplica linha', () {
      datasource.write(key, content);
      datasource.write(key, 'novo conteudo\n');

      expect(datasource.read(key), 'novo conteudo\n');
      expect(isar.chordContentCaches.where().findAll().length, 1);
    });

    test('write registra fetchedAt', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      datasource.write(key, content);

      final row = isar.chordContentCaches
          .where()
          .r2KeyEqualTo(key)
          .findFirst()!;
      expect(row.fetchedAt.isAfter(before), isTrue);
    });

    test('chave vazia nao escreve nem le', () {
      datasource.write('', content);

      expect(datasource.read(''), isNull);
      expect(isar.chordContentCaches.where().findAll(), isEmpty);
    });
  });

  group('ChordContentLocalDatasource — sem Isar (modo degradado)', () {
    const datasource = ChordContentLocalDatasource(null);

    test('read devolve null sem lancar', () {
      expect(datasource.read(key), isNull);
    });

    test('write nao lanca — cache e best-effort', () {
      expect(() => datasource.write(key, content), returnsNormally);
    });
  });
}
