import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

ColdigomPraiseCache _row(String praiseId, {String number = '001'}) =>
    ColdigomPraiseCache()
      ..praiseId = praiseId
      ..number = number
      ..name = 'Louvor $praiseId'
      ..author = ''
      ..rhythm = ''
      ..tonality = ''
      ..category = ''
      ..tags = const []
      ..lyrics = ''
      ..materialsJson = '[]'
      ..searchTokens = 'louvor $praiseId';

void main() {
  late Directory tempDir;
  late Isar isar;
  late ColdigomCatalogLocalDatasource datasource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('coldigom_catalog_');
    isar = Isar.open(
      schemas: [ColdigomPraiseCacheSchema],
      directory: tempDir.path,
      name: 'coldigom_catalog_${DateTime.now().microsecondsSinceEpoch}',
    );
    datasource = ColdigomCatalogLocalDatasource(isar);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('replaceAll substitui o catálogo inteiro numa transação', () async {
    await datasource.replaceAll([_row('p1'), _row('p2', number: '002')]);
    expect(datasource.count(), 2);

    await datasource.replaceAll([_row('p3', number: '003')]);

    expect(datasource.count(), 1);
    expect(datasource.findAllSync().single.praiseId, 'p3');
  });

  test('upsertMany insere novos e substitui existentes por praiseId', () async {
    await datasource.replaceAll([_row('p1')]);

    await datasource.upsertMany([
      _row('p1')..name = 'Renomeado',
      _row('p9', number: '009'),
    ]);

    expect(datasource.count(), 2);
    expect(datasource.findByPraiseIdSync('p1')!.name, 'Renomeado');
    expect(datasource.findByPraiseIdSync('p9')!.number, '009');
    expect(datasource.findByPraiseIdSync('nope'), isNull);
  });

  test(
    'hasAnyShortId: falso sem linhas ou sem shortId; verdadeiro com um',
    () async {
      expect(datasource.hasAnyShortId(), isFalse);

      await datasource.replaceAll([_row('p1'), _row('p2', number: '002')]);
      expect(datasource.hasAnyShortId(), isFalse);

      await datasource.replaceAll([_row('p1'), _row('p2')..shortId = '0a1']);
      expect(datasource.hasAnyShortId(), isTrue);
    },
  );

  test(
    'sem Isar: leituras vazias, escritas lançam StorageUnavailableException',
    () async {
      const degraded = ColdigomCatalogLocalDatasource.unavailable();

      expect(degraded.isAvailable, isFalse);
      expect(degraded.findAllSync(), isEmpty);
      expect(degraded.findByPraiseIdSync('p1'), isNull);
      expect(degraded.count(), 0);
      expect(degraded.hasAnyShortId(), isFalse);
      await expectLater(
        degraded.replaceAll([_row('p1')]),
        throwsA(isA<StorageUnavailableException>()),
      );
      await expectLater(
        degraded.upsertMany([_row('p1')]),
        throwsA(isA<StorageUnavailableException>()),
      );
    },
  );
}
