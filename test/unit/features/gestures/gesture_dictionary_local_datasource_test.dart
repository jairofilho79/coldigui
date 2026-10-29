import 'dart:io';

import 'package:coldigui/core/database/collections/gesture_dictionary_cache.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_dictionary_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import '../../../helpers/isar_plus_test_init.dart';

void main() {
  const content = '{"version":3,"gestures":[]}';

  group('com Isar', () {
    late Directory tempDir;
    late Isar isar;
    late GestureDictionaryLocalDatasource datasource;

    setUpAll(ensureIsarPlusTestCore);

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('gesture_dict_test');
      isar = Isar.open(
        schemas: [GestureDictionaryCacheSchema],
        directory: tempDir.path,
      );
      datasource = GestureDictionaryLocalDatasource(isar);
    });

    tearDown(() {
      isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('read devolve null antes de qualquer escrita', () {
      expect(datasource.read(), isNull);
    });

    test('write guarda conteudo e etag numa linha so', () {
      datasource.write(content: content, etag: '"abc"');
      datasource.write(content: '{}', etag: null);
      expect(isar.gestureDictionaryCaches.where().count(), 1);
      final entry = datasource.read()!;
      expect(entry.content, '{}');
      expect(entry.etag, isNull);
    });

    test('touch atualiza fetchedAt sem trocar o conteudo', () async {
      datasource.write(content: content, etag: '"abc"');
      final before = datasource.read()!.fetchedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      datasource.touch();
      final after = datasource.read()!;
      expect(after.content, content);
      expect(after.etag, '"abc"');
      expect(after.fetchedAt.isAfter(before), isTrue);
    });

    test('touch sem linha e no-op', () {
      expect(datasource.touch, returnsNormally);
      expect(datasource.read(), isNull);
    });
  });

  test('sem Isar: read null, write/touch nao lancam', () {
    const datasource = GestureDictionaryLocalDatasource(null);
    expect(() => datasource.write(content: content, etag: null), returnsNormally);
    expect(datasource.touch, returnsNormally);
    expect(datasource.read(), isNull);
  });

  test('isStaleAt respeita kGestureDictionaryTtl (1 h)', () {
    final now = DateTime(2026, 9, 11, 12);
    final fresh = GestureDictionaryCacheEntry(content: 'x', etag: null, fetchedAt: now.subtract(const Duration(minutes: 59)));
    final stale = GestureDictionaryCacheEntry(content: 'x', etag: null, fetchedAt: now.subtract(const Duration(minutes: 61)));
    expect(fresh.isStaleAt(now), isFalse);
    expect(stale.isStaleAt(now), isTrue);
  });
}
