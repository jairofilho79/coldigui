import 'dart:io';

import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/database/isar_provider.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_availability_map_provider.dart';
import 'package:coldigui/features/pdf_opening/domain/entities/pdf_offline_availability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_test_helpers.dart';

OfflinePdfIndex _index(String pdfId, {required bool persistent}) {
  return OfflinePdfIndex()
    ..pdfId = pdfId
    ..storagePath = '/tmp/$pdfId.pdf'
    ..category = 'ColAdultos'
    ..fileSize = 10
    ..downloadedAt = DateTime(2026, 1, 1)
    ..isPersistent = persistent;
}

void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline_avail_map_');
    container = ProviderContainer(
      overrides: [
        isarOpenerProvider.overrideWithValue(
          () async => openOfflineTestIsar(tempDir),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Como no app: o mapa é lido com o Isar já aberto.
    await container.read(isarInitializerProvider.future);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('offlineAvailabilityMapProvider (A5)', () {
    test('mapa reflete o índice: persistente, LRU e ausente', () async {
      final local = container.read(offlinePdfLocalDatasourceProvider);
      await local.putAllByPdfId([
        _index('fixo', persistent: true),
        _index('lru', persistent: false),
      ]);

      final map = container.read(offlineAvailabilityMapProvider);

      expect(map['fixo'], PdfOfflineAvailability.persistentOffline);
      expect(map['lru'], PdfOfflineAvailability.cachedLru);
      expect(map.containsKey('nunca-baixado'), isFalse);
    });

    test('mapa vazio em modo degradado (sem Isar)', () {
      final degraded = ProviderContainer(
        overrides: [
          isarOpenerProvider.overrideWithValue(
            () async => throw StateError('OPFS travado'),
          ),
        ],
      );
      addTearDown(degraded.dispose);

      expect(degraded.read(offlineAvailabilityMapProvider), isEmpty);
    });

    test(
      'escrita no datasource incrementa a revisão e recomputa o mapa',
      () async {
        final local = container.read(offlinePdfLocalDatasourceProvider);
        final revisions = <int>[];
        container.listen(
          offlineIndexRevisionProvider,
          (_, next) => revisions.add(next),
        );
        // Mantém o mapa vivo, como os cards fazem, para contar recomputações.
        var recomputed = 0;
        container.listen(
          offlineAvailabilityMapProvider,
          (_, _) => recomputed++,
        );
        Map<String, PdfOfflineAvailability> map() =>
            container.read(offlineAvailabilityMapProvider);
        expect(map(), isEmpty);

        await local.put(_index('a', persistent: false));
        expect(revisions, [1]);
        expect(map()['a'], PdfOfflineAvailability.cachedLru);

        await local.put(_index('a', persistent: true));
        expect(revisions, [1, 2]);
        expect(map()['a'], PdfOfflineAvailability.persistentOffline);

        await local.deleteByPdfId('a');
        expect(revisions, [1, 2, 3]);
        expect(map(), isEmpty);

        await local.putAllByPdfId([_index('b', persistent: false)]);
        await local.markAllPersistent();
        expect(revisions, [1, 2, 3, 4, 5]);
        expect(map()['b'], PdfOfflineAvailability.persistentOffline);

        await local.deleteByPdfIds({'b'});
        expect(revisions.last, 6);
        expect(map(), isEmpty);

        await local.put(_index('c', persistent: false));
        await local.clearAll();
        expect(revisions.last, 8);
        expect(map(), isEmpty);

        // Quem observa o mapa foi avisado a cada mudança lida; as duas escritas
        // seguidas sem leitura no meio (b, c) viraram **uma** recomputação cada.
        await Future<void>.delayed(Duration.zero);
        expect(recomputed, 6);
      },
    );

    test(
      'touchLastAccessed não mexe na revisão: disponibilidade não muda',
      () async {
        final local = container.read(offlinePdfLocalDatasourceProvider);
        await local.put(_index('a', persistent: false));
        final before = container.read(offlineIndexRevisionProvider);

        await local.touchLastAccessed('a', DateTime(2026, 2, 2));

        expect(container.read(offlineIndexRevisionProvider), before);
      },
    );

    test('datasource sem callback continua funcionando', () async {
      final isar = openOfflineTestIsar(tempDir);
      addTearDown(() => isar.close());
      final local = OfflinePdfLocalDatasource(isar);

      await local.put(_index('a', persistent: true));

      expect(local.findAllSync().map((e) => e.pdfId), ['a']);
    });
  });
}
