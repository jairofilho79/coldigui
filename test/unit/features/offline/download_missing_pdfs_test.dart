import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/offline/data/datasources/offline_manifest_remote_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/entities/offline_manifest.dart';
import 'package:coldigui/features/offline/domain/usecases/download_missing_pdfs.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'offline_test_helpers.dart';

final _validPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);

class _FakeManifestDatasource extends OfflineManifestRemoteDatasource {
  _FakeManifestDatasource(this._manifest) : super(Dio());

  final OfflineManifest _manifest;

  @override
  Future<OfflineManifest> fetchManifest() async => _manifest;
}

class _FakePdfBytesDatasource extends PdfBytesDatasource {
  _FakePdfBytesDatasource() : super(Dio());

  int fetchCount = 0;

  @override
  Future<Uint8List> fetchBytes(
    String filePath, {
    ProgressCallback? onReceiveProgress,
  }) async {
    fetchCount++;
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
  }
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late OfflinePdfRepositoryImpl repository;
  late _FakePdfBytesDatasource bytesDatasource;
  late DownloadMissingPdfs useCase;
  late String pdfId1;
  late String pdfId2;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    pdfId1 = encodePdfId('ColAdultos/a.pdf');
    pdfId2 = encodePdfId('ColAdultos/b.pdf');
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download_missing_');
    final docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = await openOfflineTestIsar(tempDir);
    final store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: store,
      local: OfflinePdfLocalDatasource(isar),
    );
    bytesDatasource = _FakePdfBytesDatasource();

    final manifest = OfflineManifest(
      version: '1',
      packages: {
        'Partitura': OfflineMaterialPackage(
          parts: [
            OfflinePackagePart(
              filename: 'p1.zip',
              size: 100,
              url: '/p1.zip',
              pdfs: [pdfId1, pdfId2],
            ),
          ],
          totalSize: 100,
          totalParts: 1,
        ),
      },
    );

    useCase = DownloadMissingPdfs(
      _FakeManifestDatasource(manifest),
      repository,
      createTestFetchAndStorePdf(bytesDatasource, repository),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('baixa apenas PDFs ausentes no índice', () async {
    await repository.upsert(
      pdfId: pdfId1,
      bytes: _validPdfBytes,
      category: 'ColAdultos',
    );

    final result = await useCase(materialCategories: {'Partitura'});

    expect(result.skippedCount, 1);
    expect(result.downloadedCount, 1);
    expect(result.failedCount, 0);
    expect(bytesDatasource.fetchCount, 1);
    expect(await repository.lookup(pdfId2), isNotNull);
  });

  test('progresso usa total de faltantes, não o manifest completo', () async {
    await repository.upsert(
      pdfId: pdfId1,
      bytes: _validPdfBytes,
      category: 'ColAdultos',
    );

    int? lastTotal;
    await useCase(
      materialCategories: {'Partitura'},
      onProgress: (_, total) => lastTotal = total,
    );

    expect(lastTotal, 1);
    expect(bytesDatasource.fetchCount, 1);
  });

  test('não refaz fetch quando arquivo local já é válido', () async {
    await repository.upsert(
      pdfId: pdfId1,
      bytes: _validPdfBytes,
      category: 'ColAdultos',
    );
    await repository.upsert(
      pdfId: pdfId2,
      bytes: _validPdfBytes,
      category: 'ColAdultos',
    );

    final result = await useCase(materialCategories: {'Partitura'});

    expect(result.skippedCount, 2);
    expect(result.downloadedCount, 0);
    expect(bytesDatasource.fetchCount, 0);
  });

  test('re-baixa PDF com conteúdo HTML inválido no disco', () async {
    await repository.upsert(
      pdfId: pdfId1,
      bytes: Uint8List.fromList('<html>'.codeUnits),
      category: 'ColAdultos',
    );

    final result = await useCase(materialCategories: {'Partitura'});

    expect(result.skippedCount, 0);
    expect(result.downloadedCount, 2);
    expect(bytesDatasource.fetchCount, 2);
  });
}
