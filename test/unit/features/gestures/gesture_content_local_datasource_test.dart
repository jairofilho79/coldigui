import 'dart:io';

import 'package:coldigui/core/database/collections/gesture_document_cache.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../helpers/isar_plus_test_init.dart';

void main() {
  const key = 'assets/praises/p1/m1.gestures';
  const content = '{"schema":"coldigom.gestures/1","items":[]}';

  group('com Isar', () {
    late Directory tempDir;
    late Isar isar;
    late GestureContentLocalDatasource datasource;

    setUpAll(ensureIsarPlusTestCore);

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('gesture_cache_test');
      isar = Isar.open(
        schemas: [GestureDocumentCacheSchema],
        directory: tempDir.path,
      );
      datasource = GestureContentLocalDatasource(isar);
    });

    tearDown(() {
      isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('read devolve null antes de qualquer escrita', () {
      expect(datasource.read(key), isNull);
    });

    test('write persiste e read devolve de volta', () {
      datasource.write(key, content);
      expect(datasource.read(key)?.content, content);
    });

    test('write duas vezes na mesma chave nao duplica linha', () {
      datasource.write(key, content);
      datasource.write(key, '{}');
      expect(isar.gestureDocumentCaches.where().count(), 1);
      expect(datasource.read(key)?.content, '{}');
    });

    test('marcador negativo: conteudo vazio e uma entrada valida', () {
      datasource.write(key, '');
      final entry = datasource.read(key);
      expect(entry, isNotNull);
      expect(entry!.content, isEmpty);
    });

    test('chave vazia e ignorada', () {
      datasource.write('', content);
      expect(datasource.read(''), isNull);
      expect(isar.gestureDocumentCaches.where().count(), 0);
    });
  });

  group('sem Isar (degradado)', () {
    test('read devolve null e write nao lanca', () {
      const datasource = GestureContentLocalDatasource(null);
      expect(() => datasource.write(key, content), returnsNormally);
      expect(datasource.read(key), isNull);
    });
  });

  test('isStaleAt respeita kGestureCacheTtl', () {
    final now = DateTime(2026, 9, 11, 12);
    final fresh = GestureCacheEntry(content: 'x', fetchedAt: now.subtract(const Duration(hours: 23)));
    final stale = GestureCacheEntry(content: 'x', fetchedAt: now.subtract(const Duration(hours: 25)));
    expect(fresh.isStaleAt(now), isFalse);
    expect(stale.isStaleAt(now), isTrue);
  });
}
