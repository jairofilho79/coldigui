import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/database/storage_unavailable_exception.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const local = OfflinePdfLocalDatasource.unavailable();

  OfflinePdfIndex sampleIndex() => OfflinePdfIndex()
    ..pdfId = 'p1'
    ..storagePath = '/tmp/p1.pdf'
    ..category = 'ColAdultos'
    ..fileSize = 4
    ..downloadedAt = DateTime(2026)
    ..lastAccessedAt = DateTime(2026)
    ..isPersistent = true;

  group('leituras devolvem vazio sem Isar', () {
    test('findByPdfId / findByStoragePath devolvem null', () async {
      expect(await local.findByPdfId('p1'), isNull);
      expect(await local.findByStoragePath('/tmp/p1.pdf'), isNull);
    });

    test('listagens devolvem vazio', () async {
      expect(await local.findAll(), isEmpty);
      expect(await local.findByPdfIds({'p1'}), isEmpty);
      expect(await local.findOldestForEviction(limit: 10), isEmpty);
      expect(await local.countByCategory(), isEmpty);
      expect(await local.sumFileSizes(), 0);
    });
  });

  group('escritas lançam StorageUnavailableException', () {
    test('put', () {
      expect(
        () => local.put(sampleIndex()),
        throwsA(
          isA<StorageUnavailableException>().having(
            (e) => e.operation,
            'operation',
            'offline.put',
          ),
        ),
      );
    });

    test('deleteByPdfId', () {
      expect(
        () => local.deleteByPdfId('p1'),
        throwsA(
          isA<StorageUnavailableException>().having(
            (e) => e.operation,
            'operation',
            'offline.deleteByPdfId',
          ),
        ),
      );
    });

    test('touchLastAccessedBatch', () {
      expect(
        () => local.touchLastAccessedBatch({'p1': DateTime(2026)}),
        throwsA(
          isA<StorageUnavailableException>().having(
            (e) => e.operation,
            'operation',
            'offline.touchLastAccessedBatch',
          ),
        ),
      );
    });

    test('putAllByPdfId', () {
      expect(
        () => local.putAllByPdfId([sampleIndex()]),
        throwsA(
          isA<StorageUnavailableException>().having(
            (e) => e.operation,
            'operation',
            'offline.putAllByPdfId',
          ),
        ),
      );
    });

    test('markAllPersistent', () {
      expect(
        () => local.markAllPersistent(),
        throwsA(isA<StorageUnavailableException>()),
      );
    });

    test('clearAll', () {
      expect(
        () => local.clearAll(),
        throwsA(isA<StorageUnavailableException>()),
      );
    });

    test('deleteByPdfIds', () {
      expect(
        () => local.deleteByPdfIds({'p1'}),
        throwsA(isA<StorageUnavailableException>()),
      );
    });
  });

  group('escritas vazias continuam no-op', () {
    test('lote vazio não lança', () async {
      await local.touchLastAccessedBatch(const {});
      await local.putAllByPdfId(const []);
      expect(await local.deleteByPdfIds(const {}), 0);
    });
  });
}
