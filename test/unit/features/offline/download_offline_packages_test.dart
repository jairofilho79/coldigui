import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/offline/data/datasources/disk_space_checker.dart';
import 'package:coldigui/features/offline/data/datasources/offline_bulk_checkpoint_store.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/datasources/zip_package_downloader.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/entities/offline_bulk_checkpoint.dart';
import 'package:coldigui/features/offline/domain/entities/offline_download_progress.dart';
import 'package:coldigui/features/offline/domain/entities/offline_manifest.dart';
import 'package:coldigui/features/offline/domain/exceptions/offline_bulk_exceptions.dart';
import 'package:coldigui/features/offline/domain/usecases/download_offline_packages.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/features/offline/domain/usecases/extract_and_store_pdfs.dart';
import 'package:coldigui/features/offline/domain/entities/reconcile_result.dart';
import 'package:coldigui/features/offline/domain/usecases/reconcile_offline_index.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_test_helpers.dart';

class _FakeManifestDatasource extends FakeOfflineManifestRemoteDatasource {
  _FakeManifestDatasource(super.manifest, super.prefs);
}

class _FakeDiskSpaceChecker extends DiskSpaceChecker {
  _FakeDiskSpaceChecker(this._freeBytes);

  final int? _freeBytes;

  @override
  Future<int?> getFreeBytes() async => _freeBytes;
}

class _FakeZipDownloader extends ZipPackageDownloader {
  _FakeZipDownloader(PdfLocalStore store, this._zipPath) : super(Dio(), store);

  final String _zipPath;

  @override
  Future<String> download({
    required String url,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw const OfflineBulkCancelledException();
    }
    return _zipPath;
  }
}

class _ProgressZipDownloader extends ZipPackageDownloader {
  _ProgressZipDownloader(PdfLocalStore store, this._zipPath)
      : super(Dio(), store);

  final String _zipPath;

  @override
  Future<String> download({
    required String url,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    onReceiveProgress?.call(500, 1000);
    onReceiveProgress?.call(1000, 1000);
    return _zipPath;
  }
}

class _RetainedZipDownloader extends ZipPackageDownloader {
  _RetainedZipDownloader(PdfLocalStore store, this._sourceZipPath)
      : super(Dio(), store);

  final String _sourceZipPath;

  @override
  Future<String> download({
    required String url,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw const OfflineBulkCancelledException();
    }
    final copyPath =
        '${Directory(_sourceZipPath).parent.path}/retained_${filename}_${DateTime.now().microsecondsSinceEpoch}.zip';
    await File(_sourceZipPath).copy(copyPath);
    return copyPath;
  }
}

class _EnospcZipDownloader extends ZipPackageDownloader {
  _EnospcZipDownloader(PdfLocalStore store) : super(Dio(), store);

  @override
  Future<String> download({
    required String url,
    required String filename,
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    throw FileSystemException(
      'No space left on device',
      filename,
      const OSError('No space left on device', 28),
    );
  }
}

class _EnospcExtractAndStorePdfs extends ExtractAndStorePdfs {
  _EnospcExtractAndStorePdfs(
    super.repository,
    super.store,
    super.zipDownloader,
  );

  @override
  Future<ExtractResult> call({
    required String zipPath,
    required List<String> expectedPdfIds,
    required String materialCategory,
    int startFromPdfIndex = 0,
    void Function(int extracted, int total)? onExtractProgress,
    void Function(int done, int total)? onProgress,
    Future<void> Function(int extractedPdfCount)? onProgressCheckpoint,
  }) async {
    throw FileSystemException(
      'No space left on device',
      zipPath,
      const OSError('No space left on device', 28),
    );
  }
}

class _RecordingCheckpointStore extends OfflineBulkCheckpointStore {
  _RecordingCheckpointStore(super.prefs);

  final saves = <OfflineBulkCheckpoint>[];

  @override
  Future<void> save(OfflineBulkCheckpoint checkpoint) async {
    saves.add(checkpoint);
    await super.save(checkpoint);
  }
}

class _CountingReconcile extends ReconcileOfflineIndex {
  _CountingReconcile(super.repository, super.store);

  int callCount = 0;
  final scopedCalls = <String?>[];

  @override
  Future<ReconcileResult> call({
    OfflineMaterialPackage? materialPackage,
    String? materialCategory,
  }) async {
    callCount++;
    scopedCalls.add(materialCategory);
    return super.call(
      materialPackage: materialPackage,
      materialCategory: materialCategory,
    );
  }
}

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late PdfLocalStore store;
  late OfflinePdfRepositoryImpl repository;
  late String zipPath;
  late String pdfId1;
  late String pdfId2;

  final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    pdfId1 = encodePdfId('ColAdultos/010.pdf');
    pdfId2 = encodePdfId('ColAdultos/011.pdf');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('download_packages_');
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

    zipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/010.pdf': pdfBytes,
        'ColAdultos/011.pdf': pdfBytes,
      },
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  OfflineManifest buildManifest() {
    return OfflineManifest(
      version: '1.0.0',
      packages: {
        'Partitura': OfflineMaterialPackage(
          parts: [
            OfflinePackagePart(
              filename: 'Partitura-1.zip',
              size: 1000,
              url: '/packages/Partitura-1.zip',
              pdfs: [pdfId1, pdfId2],
            ),
          ],
          totalSize: 1000,
          totalParts: 1,
        ),
      },
    );
  }

  test('falha quando espaço em disco insuficiente', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(buildManifest(), prefs),
      zipDownloader: _FakeZipDownloader(store, zipPath),
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        _FakeZipDownloader(store, zipPath),
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(10),
      checkpointStore: OfflineBulkCheckpointStore(prefs),
    );

    await expectLater(
      useCase.call(categories: const ['Partitura']),
      throwsA(isA<InsufficientDiskSpaceException>()),
    );
  });

  test('retorna failedPdfIds quando PDF esperado falha na extração', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final corruptedZipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/010.pdf':
            Uint8List.fromList([0x3C, 0x68, 0x74, 0x6D, 0x6C]),
        'ColAdultos/011.pdf': pdfBytes,
      },
    );

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(buildManifest(), prefs),
      zipDownloader: _FakeZipDownloader(store, corruptedZipPath),
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        _FakeZipDownloader(store, corruptedZipPath),
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: OfflineBulkCheckpointStore(prefs),
    );

    final result = await useCase.call(categories: const ['Partitura']);

    expect(result.hasWarnings, isTrue);
    expect(result.failedPdfIds, contains(pdfId1));
    expect(await repository.lookup(pdfId2), isNotNull);
    expect(await repository.lookup(pdfId1), isNull);
  });

  test('retorna unmatchedZipEntries quando ZIP tem PDFs extras', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final extraZipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/010.pdf': pdfBytes,
        'ColAdultos/011.pdf': pdfBytes,
        'ColAdultos/extra.pdf': pdfBytes,
      },
    );

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(buildManifest(), prefs),
      zipDownloader: _FakeZipDownloader(store, extraZipPath),
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        _FakeZipDownloader(store, extraZipPath),
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: OfflineBulkCheckpointStore(prefs),
    );

    final result = await useCase.call(categories: const ['Partitura']);

    expect(result.hasWarnings, isTrue);
    expect(result.unmatchedZipEntries, contains('ColAdultos/extra.pdf'));
  });

  test('baixa e indexa categoria com sucesso', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(buildManifest(), prefs),
      zipDownloader: _FakeZipDownloader(store, zipPath),
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        _FakeZipDownloader(store, zipPath),
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: OfflineBulkCheckpointStore(prefs),
    );

    await useCase.call(categories: const ['Partitura']);

    expect(await repository.lookup(pdfId1), isNotNull);
    expect(await repository.lookup(pdfId2), isNotNull);
    expect(await OfflineBulkCheckpointStore(prefs).load(), isNull);
  });

  test('resume de checkpoint continua da part correta', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final checkpointStore = OfflineBulkCheckpointStore(prefs);

    await checkpointStore.save(
      OfflineBulkCheckpoint(
        categories: const ['Partitura'],
        categoryIndex: 0,
        partIndex: 0,
        extractedPdfCount: 1,
        startedAt: DateTime.now(),
      ),
    );

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(buildManifest(), prefs),
      zipDownloader: _FakeZipDownloader(store, zipPath),
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        _FakeZipDownloader(store, zipPath),
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: checkpointStore,
    );

    await useCase.call(
      categories: const ['Partitura'],
      resumeCheckpoint: await checkpointStore.load(),
    );

    expect(await repository.lookup(pdfId2), isNotNull);
  });

  test('prossegue quando getFreeBytes retorna null', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(buildManifest(), prefs),
      zipDownloader: _FakeZipDownloader(store, zipPath),
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        _FakeZipDownloader(store, zipPath),
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(null),
      checkpointStore: OfflineBulkCheckpointStore(prefs),
    );

    await useCase.call(categories: const ['Partitura']);

    expect(await repository.lookup(pdfId1), isNotNull);
    expect(await repository.lookup(pdfId2), isNotNull);
  });

  test('ENOSPC no download lança InsufficientDiskSpaceException', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(buildManifest(), prefs),
      zipDownloader: _EnospcZipDownloader(store),
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        _FakeZipDownloader(store, zipPath),
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: OfflineBulkCheckpointStore(prefs),
    );

    await expectLater(
      useCase.call(categories: const ['Partitura']),
      throwsA(
        isA<InsufficientDiskSpaceException>().having(
          (e) => e.availableBytes,
          'availableBytes',
          0,
        ),
      ),
    );
  });

  test('ENOSPC na extração lança InsufficientDiskSpaceException', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fakeZip = _FakeZipDownloader(store, zipPath);

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(buildManifest(), prefs),
      zipDownloader: fakeZip,
      extractAndStorePdfs: _EnospcExtractAndStorePdfs(
        repository,
        store,
        fakeZip,
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: OfflineBulkCheckpointStore(prefs),
    );

    await expectLater(
      useCase.call(categories: const ['Partitura']),
      throwsA(
        isA<InsufficientDiskSpaceException>().having(
          (e) => e.availableBytes,
          'availableBytes',
          0,
        ),
      ),
    );
  });

  test('cancel token interrompe com exceção', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cancelToken = CancelToken()..cancel('test');

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(buildManifest(), prefs),
      zipDownloader: _FakeZipDownloader(store, zipPath),
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        _FakeZipDownloader(store, zipPath),
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: OfflineBulkCheckpointStore(prefs),
    );

    await expectLater(
      useCase.call(
        categories: const ['Partitura'],
        cancelToken: cancelToken,
      ),
      throwsA(isA<OfflineBulkCancelledException>()),
    );
  });

  test('persiste checkpoint intra-part durante extração', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final checkpointStore = _RecordingCheckpointStore(prefs);

    const pdfCount = 55;
    final pdfIds = List.generate(
      pdfCount,
      (i) =>
          encodePdfId('ColAdultos/${(i + 10).toString().padLeft(3, '0')}.pdf'),
    );
    final zipEntries = {
      for (var i = 0; i < pdfCount; i++)
        'ColAdultos/${(i + 10).toString().padLeft(3, '0')}.pdf': pdfBytes,
    };
    final largeZipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: zipEntries,
    );

    final manifest = OfflineManifest(
      version: '1.0.0',
      packages: {
        'Partitura': OfflineMaterialPackage(
          parts: [
            OfflinePackagePart(
              filename: 'Partitura-bulk.zip',
              size: 1000,
              url: '/packages/Partitura-bulk.zip',
              pdfs: pdfIds,
            ),
          ],
          totalSize: 1000,
          totalParts: 1,
        ),
      },
    );

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(manifest, prefs),
      zipDownloader: _FakeZipDownloader(store, largeZipPath),
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        _FakeZipDownloader(store, largeZipPath),
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: checkpointStore,
    );

    await useCase.call(categories: const ['Partitura']);

    expect(
      checkpointStore.saves.any((c) => c.extractedPdfCount == 50),
      isTrue,
      reason: 'deve salvar checkpoint intra-part a cada 50 PDFs',
    );
    expect(await checkpointStore.load(), isNull);
  });

  test('resume intra-part após crash não re-indexa PDFs já processados',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final checkpointStore = OfflineBulkCheckpointStore(prefs);

    const pdfCount = 60;
    const resumeFrom = 50;
    final pdfIds = List.generate(
      pdfCount,
      (i) =>
          encodePdfId('ColAdultos/${(i + 20).toString().padLeft(3, '0')}.pdf'),
    );

    for (var i = 0; i < resumeFrom; i++) {
      final marker = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, i & 0xFF]);
      await repository.upsert(
        pdfId: pdfIds[i],
        bytes: marker,
        category: 'ColAdultos',
      );
    }

    final zipEntries = {
      for (var i = 0; i < pdfCount; i++)
        'ColAdultos/${(i + 20).toString().padLeft(3, '0')}.pdf':
            Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0xFF]),
    };
    final largeZipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: zipEntries,
    );

    final manifest = OfflineManifest(
      version: '1.0.0',
      packages: {
        'Partitura': OfflineMaterialPackage(
          parts: [
            OfflinePackagePart(
              filename: 'Partitura-resume.zip',
              size: 1000,
              url: '/packages/Partitura-resume.zip',
              pdfs: pdfIds,
            ),
          ],
          totalSize: 1000,
          totalParts: 1,
        ),
      },
    );

    final startedAt = DateTime.now();
    await checkpointStore.save(
      OfflineBulkCheckpoint(
        categories: const ['Partitura'],
        categoryIndex: 0,
        partIndex: 0,
        extractedPdfCount: resumeFrom,
        startedAt: startedAt,
      ),
    );

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(manifest, prefs),
      zipDownloader: _FakeZipDownloader(store, largeZipPath),
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        _FakeZipDownloader(store, largeZipPath),
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: checkpointStore,
    );

    await useCase.call(
      categories: const ['Partitura'],
      resumeCheckpoint: await checkpointStore.load(),
    );

    for (var i = 0; i < resumeFrom; i++) {
      final entry = await repository.lookup(pdfIds[i]);
      expect(entry, isNotNull);
      expect(
        await File(entry!.absolutePath).readAsBytes(),
        Uint8List.fromList([0x25, 0x50, 0x44, 0x46, i & 0xFF]),
        reason: 'PDF #$i não deve ser re-escrito no resume intra-part',
      );
    }

    for (var i = resumeFrom; i < pdfCount; i++) {
      expect(await repository.lookup(pdfIds[i]), isNotNull);
    }

    expect(await checkpointStore.load(), isNull);
  });

  test('emite progresso byte-a-byte durante fetching', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final progressZip = _ProgressZipDownloader(store, zipPath);

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(buildManifest(), prefs),
      zipDownloader: progressZip,
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        progressZip,
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: OfflineBulkCheckpointStore(prefs),
    );

    final fetchProgress = <OfflineDownloadProgress>[];
    await useCase.call(
      categories: const ['Partitura'],
      onProgress: (progress) {
        if (progress.phase == OfflineDownloadPhase.fetching &&
            progress.zipBytesReceived != null) {
          fetchProgress.add(progress);
        }
      },
    );

    expect(fetchProgress, isNotEmpty);
    expect(
      fetchProgress.any(
        (p) => p.zipBytesReceived == 500 && p.zipBytesTotal == 1000,
      ),
      isTrue,
    );
    expect(
      fetchProgress.any(
        (p) => p.zipBytesReceived == 1000 && p.zipBytesTotal == 1000,
      ),
      isTrue,
    );
  });

  test('emite progresso durante extração a cada 25 PDFs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    const pdfCount = 55;
    final pdfIds = List.generate(
      pdfCount,
      (i) =>
          encodePdfId('ColAdultos/${(i + 10).toString().padLeft(3, '0')}.pdf'),
    );
    final zipEntries = {
      for (var i = 0; i < pdfCount; i++)
        'ColAdultos/${(i + 10).toString().padLeft(3, '0')}.pdf': pdfBytes,
    };
    final largeZipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: zipEntries,
    );

    final manifest = OfflineManifest(
      version: '1.0.0',
      packages: {
        'Partitura': OfflineMaterialPackage(
          parts: [
            OfflinePackagePart(
              filename: 'Partitura-extract-progress.zip',
              size: 1000,
              url: '/packages/Partitura-extract-progress.zip',
              pdfs: pdfIds,
            ),
          ],
          totalSize: 1000,
          totalParts: 1,
        ),
      },
    );

    final useCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(manifest, prefs),
      zipDownloader: _FakeZipDownloader(store, largeZipPath),
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        _FakeZipDownloader(store, largeZipPath),
      ),
      reconcileOfflineIndex: ReconcileOfflineIndex(repository, store),
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: OfflineBulkCheckpointStore(prefs),
    );

    final extractingDonePdfs = <int>[];
    await useCase.call(
      categories: const ['Partitura'],
      onProgress: (progress) {
        if (progress.phase == OfflineDownloadPhase.extracting) {
          extractingDonePdfs.add(progress.donePdfs);
        }
      },
    );

    expect(extractingDonePdfs.any((d) => d >= 25), isTrue);
  });

  test('bulk de múltiplas categorias executa reconcile único ao final',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final pdfId3 = encodePdfId('ColAdultos/012.pdf');
    final multiCategoryZipPath = await createSampleZip(
      dir: tempDir,
      pdfEntries: {
        'ColAdultos/010.pdf': pdfBytes,
        'ColAdultos/011.pdf': pdfBytes,
        'ColAdultos/012.pdf': pdfBytes,
      },
    );

    final manifest = OfflineManifest(
      version: '1.0.0',
      packages: {
        'Partitura': OfflineMaterialPackage(
          parts: [
            OfflinePackagePart(
              filename: 'Partitura-1.zip',
              size: 1000,
              url: '/packages/Partitura-1.zip',
              pdfs: [pdfId1, pdfId2],
            ),
          ],
          totalSize: 1000,
          totalParts: 1,
        ),
        'Cifra': OfflineMaterialPackage(
          parts: [
            OfflinePackagePart(
              filename: 'Cifra-1.zip',
              size: 500,
              url: '/packages/Cifra-1.zip',
              pdfs: [pdfId3],
            ),
          ],
          totalSize: 500,
          totalParts: 1,
        ),
      },
    );

    final reconcile = _CountingReconcile(repository, store);
    final retainedZipDownloader =
        _RetainedZipDownloader(store, multiCategoryZipPath);
    final dualUseCase = DownloadOfflinePackages(
      manifestDatasource: _FakeManifestDatasource(manifest, prefs),
      zipDownloader: retainedZipDownloader,
      extractAndStorePdfs: ExtractAndStorePdfs(
        repository,
        store,
        retainedZipDownloader,
      ),
      reconcileOfflineIndex: reconcile,
      diskSpaceChecker: _FakeDiskSpaceChecker(999999999),
      checkpointStore: OfflineBulkCheckpointStore(prefs),
    );

    final syncingPhases = <OfflineDownloadPhase>[];
    await dualUseCase.call(
      categories: const ['Partitura', 'Cifra'],
      onProgress: (progress) {
        if (progress.phase == OfflineDownloadPhase.syncing) {
          syncingPhases.add(progress.phase);
        }
      },
    );

    expect(reconcile.callCount, 1);
    expect(reconcile.scopedCalls, [null]);
    expect(syncingPhases.length, 1);
    expect(await repository.lookup(pdfId1), isNotNull);
    expect(await repository.lookup(pdfId2), isNotNull);
    expect(await repository.lookup(pdfId3), isNotNull);
    expect(await OfflineBulkCheckpointStore(prefs).load(), isNull);
  });
}
