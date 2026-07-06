import 'dart:io';
import 'dart:math' show max;
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/features/catalog/data/datasources/catalog_local_datasource.dart';
import 'package:coldigui/features/catalog/domain/constants/catalog_materials.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/usecases/download_missing_pdfs.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import 'offline_test_helpers.dart';

final _validPdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D]);

Future<void> _seedCatalogLouvor(
  Isar isar, {
  required String pdfId,
  String categoria = CatalogMaterials.partitura,
}) async {
  isar.write((isar) {
    final coll = isar.louvorCaches;
    final entry = LouvorCache()
      ..pdfId = pdfId
      ..nome = 'Teste'
      ..numero = '001'
      ..categoria = categoria
      ..classificacao = 'ColAdultos'
      ..pdf = '001.pdf'
      ..groupId = '001:teste';
    entry.id = coll.autoIncrement();
    coll.put(entry);
  });
}

class _FakePdfBytesDatasource extends PdfBytesDatasource {
  _FakePdfBytesDatasource() : super(Dio());

  int fetchCount = 0;

  @override
  Future<Uint8List> fetchBytes(
    String filePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    fetchCount++;
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
  }
}

class _ConcurrentTrackingPdfBytesDatasource extends PdfBytesDatasource {
  _ConcurrentTrackingPdfBytesDatasource(this._delayMs) : super(Dio());

  final int _delayMs;
  int activeDownloads = 0;
  int maxConcurrent = 0;
  int fetchCount = 0;

  @override
  Future<Uint8List> fetchBytes(
    String filePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    fetchCount++;
    activeDownloads++;
    maxConcurrent = max(maxConcurrent, activeDownloads);
    await Future<void>.delayed(Duration(milliseconds: _delayMs));
    activeDownloads--;
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
  }
}

class _FailingPdfBytesDatasource extends PdfBytesDatasource {
  _FailingPdfBytesDatasource() : super(Dio());
  int fetchCount = 0;

  @override
  Future<Uint8List> fetchBytes(
    String filePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    fetchCount++;
    if (filePath.contains('fail.pdf')) {
      throw DioException(
        requestOptions: RequestOptions(path: filePath),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: filePath),
          statusCode: 404,
        ),
      );
    }
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
  }
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late OfflinePdfRepositoryImpl repository;
  late CatalogLocalDatasource catalogLocal;
  late _FakePdfBytesDatasource bytesDatasource;
  late DownloadMissingPdfs useCase;
  late String pdfId1;
  late String pdfId2;

  setUpAll(() async {
    pdfId1 = encodePdfId('ColAdultos/a.pdf');
    pdfId2 = encodePdfId('ColAdultos/b.pdf');
  });

  Future<DownloadMissingPdfs> buildUseCase(PdfBytesDatasource bytesDatasource) {
    return Future.value(
      DownloadMissingPdfs(
        catalogLocal,
        repository,
        createTestFetchAndStorePdf(bytesDatasource, repository),
      ),
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('download_missing_');
    final docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = openOfflineCatalogTestIsar(tempDir);
    final store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: pdfStoragePortFor(store),
      local: OfflinePdfLocalDatasource(isar),
    );
    catalogLocal = CatalogLocalDatasource(isar);
    bytesDatasource = _FakePdfBytesDatasource();

    useCase = await buildUseCase(bytesDatasource);
  });

  tearDown(() async {
    isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('materialCategories vazio não baixa nada', () async {
    await _seedCatalogLouvor(isar, pdfId: pdfId1);
    await _seedCatalogLouvor(isar, pdfId: pdfId2);

    final result = await useCase(materialCategories: {});

    expect(result.downloadedCount, 0);
    expect(result.failedCount, 0);
    expect(bytesDatasource.fetchCount, 0);
  });

  test('baixa apenas PDFs ausentes no índice', () async {
    await _seedCatalogLouvor(isar, pdfId: pdfId1);
    await _seedCatalogLouvor(isar, pdfId: pdfId2);
    await repository.upsert(
      pdfId: pdfId1,
      bytes: _validPdfBytes,
      category: 'ColAdultos',
    );

    final result = await useCase(
      materialCategories: {CatalogMaterials.partitura},
    );

    expect(result.skippedCount, 1);
    expect(result.downloadedCount, 1);
    expect(result.failedCount, 0);
    expect(bytesDatasource.fetchCount, 1);
    expect(await repository.lookup(pdfId2), isNotNull);
  });

  test('inclui pdf do catálogo fora de qualquer package do manifest', () async {
    final catalogOnlyId = encodePdfId('ColAdultos/only-catalog.pdf');
    await _seedCatalogLouvor(isar, pdfId: catalogOnlyId);

    final result = await useCase(
      materialCategories: {CatalogMaterials.partitura},
    );

    expect(result.downloadedCount, 1);
    expect(result.failedCount, 0);
    expect(await repository.lookup(catalogOnlyId), isNotNull);
  });

  test('progresso usa total de faltantes, não o manifest completo', () async {
    await _seedCatalogLouvor(isar, pdfId: pdfId1);
    await _seedCatalogLouvor(isar, pdfId: pdfId2);
    await repository.upsert(
      pdfId: pdfId1,
      bytes: _validPdfBytes,
      category: 'ColAdultos',
    );

    int? lastTotal;
    await useCase(
      materialCategories: {CatalogMaterials.partitura},
      onProgress: (_, total) => lastTotal = total,
    );

    expect(lastTotal, 1);
    expect(bytesDatasource.fetchCount, 1);
  });

  test('não refaz fetch quando arquivo local já é válido', () async {
    await _seedCatalogLouvor(isar, pdfId: pdfId1);
    await _seedCatalogLouvor(isar, pdfId: pdfId2);
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

    final result = await useCase(
      materialCategories: {CatalogMaterials.partitura},
    );

    expect(result.skippedCount, 2);
    expect(result.downloadedCount, 0);
    expect(bytesDatasource.fetchCount, 0);
  });

  test('re-baixa PDF com conteúdo HTML inválido no disco', () async {
    await _seedCatalogLouvor(isar, pdfId: pdfId1);
    await _seedCatalogLouvor(isar, pdfId: pdfId2);
    await repository.upsert(
      pdfId: pdfId1,
      bytes: Uint8List.fromList('<html>'.codeUnits),
      category: 'ColAdultos',
    );

    final result = await useCase(
      materialCategories: {CatalogMaterials.partitura},
    );

    expect(result.skippedCount, 0);
    expect(result.downloadedCount, 2);
    expect(result.failedCount, 0);
    expect(bytesDatasource.fetchCount, 2);
  });

  test('baixa PDFs faltantes em paralelo com limite de concorrência', () async {
    const pdfCount = 10;
    final pdfIds = List.generate(
      pdfCount,
      (i) => encodePdfId('ColAdultos/${i.toString().padLeft(3, '0')}.pdf'),
    );

    for (final pdfId in pdfIds) {
      await _seedCatalogLouvor(isar, pdfId: pdfId);
    }

    final trackingDatasource = _ConcurrentTrackingPdfBytesDatasource(30);
    final concurrentUseCase = await buildUseCase(trackingDatasource);

    final progressUpdates = <int>[];
    final result = await concurrentUseCase(
      materialCategories: {CatalogMaterials.partitura},
      onProgress: (done, total) {
        progressUpdates.add(done);
        expect(total, pdfCount);
      },
    );

    expect(result.downloadedCount, pdfCount);
    expect(result.failedCount, 0);
    expect(trackingDatasource.fetchCount, pdfCount);
    expect(trackingDatasource.maxConcurrent, greaterThan(1));
    expect(trackingDatasource.maxConcurrent, lessThanOrEqualTo(3));
    expect(progressUpdates, [0, for (var i = 1; i <= pdfCount; i++) i]);
  });

  test('falha em um PDF não aborta os demais downloads', () async {
    final failPdfId = encodePdfId('ColAdultos/fail.pdf');
    final okPdfId = encodePdfId('ColAdultos/ok.pdf');

    await _seedCatalogLouvor(isar, pdfId: failPdfId);
    await _seedCatalogLouvor(isar, pdfId: okPdfId);

    final failingDatasource = _FailingPdfBytesDatasource();
    final failingUseCase = await buildUseCase(failingDatasource);

    final result = await failingUseCase(
      materialCategories: {CatalogMaterials.partitura},
    );

    expect(result.downloadedCount, 1);
    expect(result.failedCount, 1);
    expect(failingDatasource.fetchCount, 2);
    expect(await repository.lookup(okPdfId), isNotNull);
    expect(await repository.lookup(failPdfId), isNull);
  });
}
