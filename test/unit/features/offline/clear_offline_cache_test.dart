import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/features/offline/data/datasources/offline_available_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_bulk_checkpoint_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/entities/offline_bulk_checkpoint.dart';
import 'package:coldigui/features/offline/domain/usecases/clear_offline_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_test_helpers.dart';

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late PdfLocalStore store;
  late OfflinePdfRepositoryImpl repository;
  late SharedPreferences prefs;
  late ClearOfflineCache useCase;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clear_offline_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = await openOfflineTestIsar(tempDir);
    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: store,
      local: OfflinePdfLocalDatasource(isar),
    );
    prefs = await SharedPreferences.getInstance();
    final checkpointStore = OfflineBulkCheckpointStore(prefs);
    final offlineAvailableStore = OfflineAvailableStore(prefs);
    useCase = ClearOfflineCache(
      repository,
      store,
      checkpointStore,
      offlineAvailableStore,
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('limpa índice, diretório PDFs, checkpoint bulk e flag offline',
      () async {
    await repository.upsert(
      pdfId: encodePdfId('ColAdultos/a.pdf'),
      bytes: Uint8List.fromList([1]),
      category: 'ColAdultos',
    );

    final checkpointStore = OfflineBulkCheckpointStore(prefs);
    final offlineAvailableStore = OfflineAvailableStore(prefs);
    await offlineAvailableStore.markConfigured();
    await checkpointStore.save(
      OfflineBulkCheckpoint(
        categories: const ['Partitura'],
        categoryIndex: 0,
        partIndex: 0,
        extractedPdfCount: 0,
        startedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final rootBefore = await store.rootDirectory;
    expect(await rootBefore.list(recursive: true).length, greaterThan(0));

    await useCase();

    expect((await repository.listAll()).length, 0);
    final rootAfter = await store.rootDirectory;
    expect(await rootAfter.list().length, 0);
    expect(await checkpointStore.load(), isNull);
    expect(prefs.getString(StorageKeys.offlineAvailable),
        OfflineAvailableStore.disabledValue);
  });
}
