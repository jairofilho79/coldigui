import 'dart:io';

import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/database/isar_app_schemas.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

void main() {
  late Isar isar;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('legacy_catalog_');
    isar = Isar.open(
      schemas: kAppIsarSchemas,
      directory: dir.path,
      name: 'legacy_catalog_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(() async {
      isar.close(deleteFromDisk: true);
      if (dir.existsSync()) await dir.delete(recursive: true);
    });
  });

  test('clearLegacyCatalogCache esvazia LouvorCache e não toca nas outras coleções', () async {
    isar.write((isar) {
      isar.louvorCaches.putAll([
        for (var i = 0; i < 3; i++)
          LouvorCache()
            ..id = isar.louvorCaches.autoIncrement()
            ..pdfId = 'legado-$i'
            ..nome = 'Louvor $i'
            ..numero = '00$i'
            ..categoria = 'Partitura'
            ..classificacao = 'ColAdultos'
            ..pdf = '00$i.pdf'
            ..groupId = '',
      ]);
      isar.offlinePdfIndexs.put(
        OfflinePdfIndex()
          ..id = isar.offlinePdfIndexs.autoIncrement()
          ..pdfId = 'pdf-offline'
          ..storagePath = 'plpcg_pdfs/x.pdf'
          ..category = 'praises'
          ..fileSize = 4
          ..downloadedAt = DateTime(2026, 9, 1),
      );
      isar.coldigomPraiseCaches.put(
        ColdigomPraiseCache()
          ..id = isar.coldigomPraiseCaches.autoIncrement()
          ..praiseId = 'p1'
          ..number = '1'
          ..name = 'Praise'
          ..author = ''
          ..rhythm = ''
          ..tonality = ''
          ..category = ''
          ..tags = const []
          ..lyrics = ''
          ..materialsJson = '[]'
          ..searchTokens = 'praise',
      );
    });
    var indexChanges = 0;
    final local = OfflinePdfLocalDatasource(
      isar,
      onIndexChanged: () => indexChanges++,
    );

    await local.clearLegacyCatalogCache();

    expect(isar.louvorCaches.count(), 0);
    expect(isar.offlinePdfIndexs.count(), 1);
    expect(isar.coldigomPraiseCaches.count(), 1);
    expect(indexChanges, 0, reason: 'o índice offline não mudou');
  });
}
