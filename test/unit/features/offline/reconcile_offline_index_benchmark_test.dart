import 'dart:io';

import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/usecases/reconcile_offline_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import 'offline_test_helpers.dart';

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late PdfLocalStore store;
  late OfflinePdfRepositoryImpl repository;
  late ReconcileOfflineIndex useCase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reconcile_bench_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = openOfflineTestIsar(tempDir);
    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: store,
      local: OfflinePdfLocalDatasource(isar),
    );
    useCase = ReconcileOfflineIndex(repository, store);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'reconcile global 5000 entradas válidas completa em menos de 20s',
    () async {
      await seedOfflineEntries(repository: repository, count: 5000);

      final stopwatch = Stopwatch()..start();
      final result = await useCase();
      stopwatch.stop();

      expect(result.removedFromIndex, 0);
      expect(result.orphanFiles, 0);
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 20)),
        reason: 'reconcile demorou ${stopwatch.elapsed.inMilliseconds}ms',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
    tags: ['benchmark'],
  );
}
