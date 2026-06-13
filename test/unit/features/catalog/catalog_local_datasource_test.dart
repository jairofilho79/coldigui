import 'dart:io';

import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

Louvor _sampleLouvor({
  required String pdfId,
  required String numero,
  String groupId = '',
}) =>
    Louvor.fromManifest(
      nome: 'Louvor $numero',
      numero: numero,
      categoria: 'Partitura',
      classificacao: 'ColAdultos',
      pdf: '$numero.pdf',
      pdfId: pdfId,
      groupId: groupId,
    );

void main() {
  late Directory tempDir;
  late Isar isar;
  late CatalogLocalDatasource datasource;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('catalog_local_');
    isar = await Isar.open(
      [LouvorCacheSchema, OfflinePdfIndexSchema],
      directory: tempDir.path,
    );
    datasource = CatalogLocalDatasource(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saveLouvores substitui cache inteiro', () async {
    await datasource.saveLouvores([
      _sampleLouvor(pdfId: 'id-1', numero: '001'),
    ]);
    expect(await isar.louvorCaches.count(), 1);

    await datasource.saveLouvores([
      _sampleLouvor(pdfId: 'id-2', numero: '002'),
      _sampleLouvor(pdfId: 'id-3', numero: '003'),
    ]);
    expect(await isar.louvorCaches.count(), 2);
  });

  test('loadLouvores retorna entidades de domínio', () async {
    await datasource.saveLouvores([
      _sampleLouvor(pdfId: 'id-1', numero: '001'),
    ]);

    final loaded = await datasource.loadLouvores();
    expect(loaded, hasLength(1));
    expect(loaded.first.numero, '001');
    expect(loaded.first.pdfId, 'id-1');
  });

  test('persiste e restaura groupId no cache Isar', () async {
    await datasource.saveLouvores([
      _sampleLouvor(
        pdfId: 'id-1',
        numero: '003',
        groupId: '003:clamo-a-ti',
      ),
    ]);

    final loaded = await datasource.loadLouvores();
    expect(loaded.single.groupId, '003:clamo-a-ti');
    expect(loaded.single.effectiveGroupId, '003:clamo-a-ti');
  });
}
