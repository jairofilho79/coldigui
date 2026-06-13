import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/louvor_cache.dart';
import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

String _encodePdfId(String path) {
  return base64Url
      .encode(utf8.encode(path))
      .replaceAll('+', '-')
      .replaceAll('/', '_')
      .replaceAll('=', '');
}

class _FakeFetchAndStorePdf extends FetchAndStorePdf {
  _FakeFetchAndStorePdf(this._onCall)
      : super(_UnusedPdfBytesDatasource(), _UnusedRepository());

  final Future<LocalPdfSource> Function({
    required String pdfId,
    required String remotePath,
    String? category,
  }) _onCall;

  @override
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    String? category,
  }) =>
      _onCall(pdfId: pdfId, remotePath: remotePath, category: category);
}

class _UnusedPdfBytesDatasource extends PdfBytesDatasource {
  _UnusedPdfBytesDatasource() : super(Dio());

  @override
  Future<Uint8List> fetchBytes(String filePath) {
    throw StateError('_FakeFetchAndStorePdf não deve chamar fetchBytes');
  }
}

class _UnusedRepository implements OfflinePdfRepository {
  @override
  Future<Map<String, int>> countByCategory() => throw UnimplementedError();

  @override
  Future<OfflinePdfEntry?> findIndexEntry(String pdfId) =>
      throw UnimplementedError();

  @override
  Future<List<OfflinePdfEntry>> listAll() => throw UnimplementedError();

  @override
  Future<OfflinePdfEntry?> lookup(String pdfId) => throw UnimplementedError();

  @override
  Future<Set<String>> lookupBatch(Set<String> pdfIds) =>
      throw UnimplementedError();

  @override
  Future<void> remove(String pdfId) => throw UnimplementedError();

  @override
  Future<OfflinePdfEntry> upsert({
    required String pdfId,
    required Uint8List bytes,
    required String category,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> indexExtractedBatch(
    List<ExtractedPdfItem> items,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> upsertBatch(List<OfflinePdfBatchItem> items) =>
      throw UnimplementedError();

  @override
  Future<int> removeIndexEntries(Set<String> pdfIds) =>
      throw UnimplementedError();

  @override
  Future<void> clearAll() => throw UnimplementedError();
}

class _FakePdfBytesDatasource extends PdfBytesDatasource {
  _FakePdfBytesDatasource(this._bytes) : super(Dio());

  final Uint8List _bytes;

  @override
  Future<Uint8List> fetchBytes(String filePath) async => _bytes;
}

void main() {
  late Directory tempDir;
  late Directory docsDir;
  late Isar isar;
  late PdfLocalStore store;
  late OfflinePdfRepositoryImpl repository;

  const category = 'ColAdultos';
  const relPath = 'ColAdultos/001.pdf';
  const remotePath = '/assets/ColAdultos/001.pdf';
  late String pdfId;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    pdfId = _encodePdfId(relPath);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('resolve_pdf_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);

    isar = await Isar.open(
      [LouvorCacheSchema, OfflinePdfIndexSchema],
      directory: tempDir.path,
    );

    store = PdfLocalStore(
      getApplicationDocumentsDirectory: () async => docsDir,
    );
    repository = OfflinePdfRepositoryImpl(
      store: store,
      local: OfflinePdfLocalDatasource(isar),
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('hit retorna LocalPdfSource com fromCache true', () async {
    final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: category,
    );

    var fetchCalled = false;
    final resolver = ResolvePdfForReader(
      repository,
      _FakeFetchAndStorePdf(({
        required String pdfId,
        required String remotePath,
        String? category,
      }) async {
        fetchCalled = true;
        throw StateError('fetch não deveria ser chamado em hit');
      }),
    );

    final source = await resolver(
      pdfId: pdfId,
      remotePath: remotePath,
    );

    expect(fetchCalled, isFalse);
    expect(source.fromCache, isTrue);
    expect(source.pdfId, pdfId);
    expect(source.absolutePath, entry.absolutePath);
    expect(await File(source.absolutePath).exists(), isTrue);
  });

  test('miss com FetchAndStorePdf real persiste e retorna fromCache false',
      () async {
    final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
    final fetchAndStore = FetchAndStorePdf(
      _FakePdfBytesDatasource(bytes),
      repository,
    );
    final resolver = ResolvePdfForReader(repository, fetchAndStore);

    final source = await resolver(
      pdfId: pdfId,
      remotePath: remotePath,
    );

    expect(source.fromCache, isFalse);
    expect(source.pdfId, pdfId);
    expect(await File(source.absolutePath).exists(), isTrue);
    expect(await repository.lookup(pdfId), isNotNull);
  });

  test('miss delega fetch e retorna fromCache false', () async {
    const fetchedPath = '/docs/plpcg_pdfs/ColAdultos/001.pdf';
    String? capturedPdfId;
    String? capturedRemotePath;

    final resolver = ResolvePdfForReader(
      repository,
      _FakeFetchAndStorePdf(({
        required String pdfId,
        required String remotePath,
        String? category,
      }) async {
        capturedPdfId = pdfId;
        capturedRemotePath = remotePath;
        return LocalPdfSource(
          pdfId: pdfId,
          absolutePath: fetchedPath,
          fromCache: false,
        );
      }),
    );

    final source = await resolver(
      pdfId: pdfId,
      remotePath: remotePath,
    );

    expect(capturedPdfId, pdfId);
    expect(capturedRemotePath, remotePath);
    expect(source.fromCache, isFalse);
    expect(source.absolutePath, fetchedPath);
  });

  test('apagado externamente + offline lança PdfExternallyDeletedException',
      () async {
    final bytes = Uint8List.fromList([1]);
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: category,
    );
    await File(entry.absolutePath).delete();

    final resolver = ResolvePdfForReader(
      repository,
      _FakeFetchAndStorePdf(({
        required String pdfId,
        required String remotePath,
        String? category,
      }) async {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: remotePath),
          reason: 'offline',
        );
      }),
    );

    expect(
      () => resolver(pdfId: pdfId, remotePath: remotePath),
      throwsA(
        isA<PdfExternallyDeletedException>()
            .having((e) => e.pdfId, 'pdfId', pdfId)
            .having((e) => e.canRetryWhenOnline, 'canRetryWhenOnline', isTrue),
      ),
    );
  });

  test('nunca cacheado + offline lança PdfOfflineUnavailableException',
      () async {
    final resolver = ResolvePdfForReader(
      repository,
      _FakeFetchAndStorePdf(({
        required String pdfId,
        required String remotePath,
        String? category,
      }) async {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: remotePath),
          reason: 'offline',
        );
      }),
    );

    expect(
      () => resolver(pdfId: pdfId, remotePath: remotePath),
      throwsA(
        isA<PdfOfflineUnavailableException>()
            .having((e) => e.pdfId, 'pdfId', pdfId),
      ),
    );
  });

  test('apagado externamente + online re-fetch retorna fromCache false',
      () async {
    final bytes = Uint8List.fromList([1]);
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: category,
    );
    await File(entry.absolutePath).delete();

    const refetchedPath = '/docs/plpcg_pdfs/ColAdultos/001.pdf';

    final resolver = ResolvePdfForReader(
      repository,
      _FakeFetchAndStorePdf(({
        required String pdfId,
        required String remotePath,
        String? category,
      }) async {
        return LocalPdfSource(
          pdfId: pdfId,
          absolutePath: refetchedPath,
          fromCache: false,
        );
      }),
    );

    final source = await resolver(
      pdfId: pdfId,
      remotePath: remotePath,
    );

    expect(source.fromCache, isFalse);
    expect(source.absolutePath, refetchedPath);
  });

  test('fetch HTTP error lança PdfFetchFailedException', () async {
    final resolver = ResolvePdfForReader(
      repository,
      _FakeFetchAndStorePdf(({
        required String pdfId,
        required String remotePath,
        String? category,
      }) async {
        throw DioException.badResponse(
          statusCode: 404,
          requestOptions: RequestOptions(path: remotePath),
          response: Response(
            requestOptions: RequestOptions(path: remotePath),
            statusCode: 404,
          ),
        );
      }),
    );

    expect(
      () => resolver(pdfId: pdfId, remotePath: remotePath),
      throwsA(isA<PdfFetchFailedException>()),
    );
  });
}
