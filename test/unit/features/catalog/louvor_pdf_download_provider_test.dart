import 'dart:async';
import 'dart:typed_data';

import 'package:coldigui/features/catalog/presentation/providers/louvor_pdf_download_provider.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/data/datasources/favorite_pdf_ids_resolver.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/fetch_and_store_pdf.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _source = LocalPdfSource(
  pdfId: 'pdf-1',
  absolutePath: '/tmp/test.pdf',
  fromCache: false,
);

class _ControllableResolvePdf extends ResolvePdfForReader {
  _ControllableResolvePdf(this._handler)
    : super(_UnusedRepository(), _UnusedFetchAndStorePdf());

  final Future<LocalPdfSource> Function({
    required String pdfId,
    required String remotePath,
    ProgressCallback? onProgress,
  })
  _handler;

  int callCount = 0;

  @override
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    ProgressCallback? onProgress,
  }) {
    callCount++;
    return _handler(
      pdfId: pdfId,
      remotePath: remotePath,
      onProgress: onProgress,
    );
  }
}

class _UnusedPdfBytesDatasource extends PdfBytesDatasource {
  _UnusedPdfBytesDatasource() : super(Dio());

  @override
  Future<Uint8List> fetchBytes(
    String filePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) {
    throw StateError('não deve chamar fetchBytes');
  }
}

class _UnusedFetchAndStorePdf extends FetchAndStorePdf {
  _UnusedFetchAndStorePdf()
    : super(
        _UnusedPdfBytesDatasource(),
        _UnusedRepository(),
        favoritePdfIdsResolver: FavoritePdfIdsResolver.testing(),
      );
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
  Future<(OfflinePdfEntry? entry, bool hasIndexEntry)> lookupWithIndexState(
    String pdfId,
  ) => throw UnimplementedError();

  @override
  Future<Set<String>> lookupBatch(Set<String> pdfIds) =>
      throw UnimplementedError();

  @override
  Future<void> remove(String pdfId) => throw UnimplementedError();

  @override
  Future<void> remapPdfId({
    required String fromPdfId,
    required String toPdfId,
  }) => throw UnimplementedError();

  @override
  Future<String?> findPdfIdByAbsolutePath(String absolutePath) async => null;

  @override
  Future<OfflinePdfEntry> upsert({
    required String pdfId,
    required Uint8List bytes,
    required String category,
    bool isPersistent = false,
  }) => throw UnimplementedError();

  @override
  Future<void> indexExtractedBatch(List<ExtractedPdfItem> items) =>
      throw UnimplementedError();

  @override
  Future<void> upsertBatch(List<OfflinePdfBatchItem> items) =>
      throw UnimplementedError();

  @override
  Future<int> removeIndexEntries(Set<String> pdfIds) =>
      throw UnimplementedError();

  @override
  Future<void> clearAll() => throw UnimplementedError();

  @override
  Future<int> totalCachedBytes() async => 0;

  @override
  Future<int> evictOldestPdfs({
    required int targetBytes,
    Set<String> excludePdfIds = const {},
  }) async => 0;

  @override
  Future<void> flushPendingTouchLastAccessed() async {}
}

void main() {
  test('reutiliza download em andamento para o mesmo pdfId', () async {
    final gate = Completer<void>();
    final resolve = _ControllableResolvePdf(({
      required pdfId,
      required remotePath,
      onProgress,
    }) async {
      await gate.future;
      return _source;
    });

    final container = ProviderContainer(
      overrides: [resolvePdfForReaderProvider.overrideWithValue(resolve)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(louvorPdfDownloadProvider.notifier);
    final first = notifier.resolveLouvorPdf(
      pdfId: 'pdf-1',
      remotePath: '/assets/test.pdf',
    );
    final second = notifier.resolveLouvorPdf(
      pdfId: 'pdf-1',
      remotePath: '/assets/test.pdf',
    );

    expect(resolve.callCount, 1);
    expect(container.read(louvorPdfDownloadProvider)['pdf-1']?.isLoading, true);

    gate.complete();
    await expectLater(first, completion(equals(_source)));
    await expectLater(second, completion(equals(_source)));
    expect(container.read(louvorPdfDownloadProvider), isEmpty);
  });

  test('atualiza progresso e exibe label após 500ms', () async {
    final resolve = _ControllableResolvePdf(({
      required pdfId,
      required remotePath,
      onProgress,
    }) async {
      onProgress?.call(45, 100);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      onProgress?.call(100, 100);
      return _source;
    });

    final container = ProviderContainer(
      overrides: [resolvePdfForReaderProvider.overrideWithValue(resolve)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(louvorPdfDownloadProvider.notifier);
    final future = notifier.resolveLouvorPdf(
      pdfId: 'pdf-1',
      remotePath: '/assets/test.pdf',
    );

    await Future<void>.delayed(const Duration(milliseconds: 550));
    final mid = container.read(louvorPdfDownloadProvider)['pdf-1'];
    expect(mid?.isLoading, isTrue);
    expect(mid?.showProgressLabel, isTrue);
    expect(mid?.progressFraction, closeTo(0.45, 0.001));

    await future;
    expect(container.read(louvorPdfDownloadProvider), isEmpty);
  });

  test('limpa estado após conclusão', () async {
    final resolve = _ControllableResolvePdf(({
      required pdfId,
      required remotePath,
      onProgress,
    }) async {
      return _source;
    });

    final container = ProviderContainer(
      overrides: [resolvePdfForReaderProvider.overrideWithValue(resolve)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(louvorPdfDownloadProvider.notifier);
    await notifier.resolveLouvorPdf(
      pdfId: 'pdf-1',
      remotePath: '/assets/test.pdf',
    );

    expect(container.read(louvorPdfDownloadProvider), isEmpty);
  });
}
