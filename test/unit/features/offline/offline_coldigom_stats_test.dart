import 'dart:convert';
import 'dart:io';

import 'package:coldigui/core/database/collections/chord_content_cache.dart';
import 'package:coldigui/core/database/collections/coldigom_praise_cache.dart';
import 'package:coldigui/core/database/collections/gesture_document_cache.dart';
import 'package:coldigui/core/database/collections/offline_audio_index.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/coldigom/data/datasources/coldigom_catalog_local_datasource.dart';
import 'package:coldigui/features/offline/data/providers/offline_repository_providers.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_coldigom_stats_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

ColdigomPraiseCache _row(String id, List<Map<String, Object?>> materials) =>
    ColdigomPraiseCache()
      ..praiseId = id
      ..number = '001'
      ..name = 'x'
      ..author = ''
      ..rhythm = ''
      ..tonality = ''
      ..category = ''
      ..tags = const []
      ..lyrics = ''
      ..materialsJson = jsonEncode(materials)
      ..searchTokens = '';

Map<String, Object?> _m(String id, String kind, String type, {int? size}) => {
  'id': id,
  'kind': kind,
  'kindName': 'Kind $kind',
  'type': type,
  'r2': 'assets/praises/x/$id.$type',
  'size': ?size,
};

void main() {
  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stats_');
    isar = Isar.open(
      schemas: [
        OfflinePdfIndexSchema,
        OfflineAudioIndexSchema,
        ChordContentCacheSchema,
        GestureDocumentCacheSchema,
        ColdigomPraiseCacheSchema,
      ],
      directory: tempDir.path,
      name: 'stats_${DateTime.now().microsecondsSinceEpoch}',
    );
    container = ProviderContainer(
      overrides: [isarInitializerProvider.overrideWith((ref) async => isar)],
    );
    addTearDown(container.dispose);
    await container.read(isarInitializerProvider.future);
    await ColdigomCatalogLocalDatasource(isar).replaceAll([
      _row('p1', [
        _m('a', 'k-pdf', 'pdf', size: 1000),
        _m('b', 'k-mp3', 'mp3'),
      ]),
      _row('p2', [_m('c', 'k-pdf', 'pdf'), _m('yt', 'k-yt', 'youtube')]),
    ]);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test(
    'conta total/baixados e soma bytes conhecidos + estimados por kind',
    () async {
      await container
          .read(offlinePdfLocalDatasourceProvider)
          .put(
            OfflinePdfIndex()
              ..pdfId = encodePdfId('assets/praises/x/a.pdf')
              ..storagePath = '/x'
              ..category = 'x'
              ..fileSize = 1000
              ..downloadedAt = DateTime(2026)
              ..isPersistent = true,
          );

      final stats = await container.read(offlineColdigomStatsProvider.future);

      final pdf = stats.byKind['k-pdf']!;
      expect(pdf.kindName, 'Kind k-pdf');
      expect(pdf.total, 2);
      expect(pdf.downloaded, 1);
      expect(pdf.bytesKnown, 1000);
      expect(pdf.bytesEstimated, 350 * 1024);
      expect(pdf.hasEstimate, isTrue);
      final mp3 = stats.byKind['k-mp3']!;
      expect(mp3.total, 1);
      expect(mp3.downloaded, 0);
      expect(mp3.bytesEstimated, 4 * 1024 * 1024);
      expect(stats.byKind.containsKey('k-yt'), isFalse);
      // Pendente = só o que falta baixar dos kinds pedidos.
      expect(
        stats.pendingBytes({'k-pdf', 'k-mp3'}),
        350 * 1024 + 4 * 1024 * 1024,
      );
    },
  );
}
