import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_reader/data/adapters/pdfx_viewer_adapter.dart';
import 'package:coldigui/features/pdf_reader/data/providers/pdf_reader_providers.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_session_cache.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:pdfx/pdfx.dart';

import '../offline/offline_test_helpers.dart';

class _TrackableController extends PdfControllerPinch {
  _TrackableController() : super(document: Completer<PdfDocument>().future);

  var wasDisposed = false;

  @override
  void dispose() {
    if (wasDisposed) return;
    wasDisposed = true;
    super.dispose();
  }
}

class _SessionTestAdapter extends PdfxViewerAdapter {
  _SessionTestAdapter()
      : super(
          PdfBytesDatasource(
            _NoOpDio(),
            resolver:
                const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
          ),
          resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
        );

  _TrackableController? created;
  var openDocumentCallCount = 0;

  @override
  Future<PdfControllerPinch> openDocument(String filePath) async {
    openDocumentCallCount++;
    created = _TrackableController();
    return created!;
  }
}

class _CorruptLocalAdapter extends PdfxViewerAdapter {
  _CorruptLocalAdapter()
      : super(
          PdfBytesDatasource(
            _NoOpDio(),
            resolver:
                const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
          ),
          resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
        );

  @override
  Future<PdfControllerPinch> openDocument(String filePath) async {
    return PdfControllerPinch(
      document: Future<PdfDocument>.delayed(
        Duration.zero,
        () => throw Exception('corrupt pdf'),
      ),
    );
  }
}

class _NoOpDio implements Dio {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const filePath = 'asset:fixtures/sample.pdf';

  test('sessão liberada vai para cache sem dispose imediato', () async {
    final adapter = _SessionTestAdapter();
    final container = ProviderContainer(
      overrides: [
        pdfxViewerAdapterProvider.overrideWithValue(adapter),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, __) {},
      fireImmediately: true,
    );

    final session =
        await container.read(pdfReaderSessionProvider(filePath).future);
    expect(session.controller, same(adapter.created));

    sub.close();
    await Future<void>.delayed(Duration.zero);

    expect(adapter.created!.wasDisposed, isFalse);
    expect(
      container.read(pdfSessionCacheProvider).length,
      1,
    );
  });

  test('sair do leitor limpa cache e descarta controllers', () async {
    final adapter = _SessionTestAdapter();
    final container = ProviderContainer(
      overrides: [
        pdfxViewerAdapterProvider.overrideWithValue(adapter),
      ],
    );
    addTearDown(container.dispose);

    container.read(readerRouteParamsProvider.notifier).update(
      {UrlSyncParams.file: filePath},
    );

    final sub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, __) {},
      fireImmediately: true,
    );

    await container.read(pdfReaderSessionProvider(filePath).future);
    sub.close();
    await Future<void>.delayed(Duration.zero);
    expect(adapter.created!.wasDisposed, isFalse);

    container.read(readerRouteParamsProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);

    expect(adapter.created!.wasDisposed, isTrue);
    expect(container.read(pdfSessionCacheProvider).length, 0);
  });

  test('reabrir reutiliza controller do cache LRU', () async {
    final adapter = _SessionTestAdapter();
    final container = ProviderContainer(
      overrides: [
        pdfxViewerAdapterProvider.overrideWithValue(adapter),
      ],
    );
    addTearDown(container.dispose);

    final firstSub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, __) {},
      fireImmediately: true,
    );
    final firstSession =
        await container.read(pdfReaderSessionProvider(filePath).future);
    final firstController = firstSession.controller;
    expect(firstSession.fromCache, isFalse);
    expect(adapter.openDocumentCallCount, 1);
    firstSub.close();
    await Future<void>.delayed(Duration.zero);
    expect(adapter.created!.wasDisposed, isFalse);

    final secondSub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, __) {},
      fireImmediately: true,
    );
    final secondSession =
        await container.read(pdfReaderSessionProvider(filePath).future);
    expect(secondSession.controller, same(firstController));
    expect(secondSession.fromCache, isTrue);
    expect(adapter.openDocumentCallCount, 1);
    expect(adapter.created!.wasDisposed, isFalse);

    secondSub.close();
    await Future<void>.delayed(Duration.zero);
    container.read(readerRouteParamsProvider.notifier).update(
      {UrlSyncParams.file: filePath},
    );
    container.read(readerRouteParamsProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);
    expect(adapter.created!.wasDisposed, isTrue);
  });

  test('troca entre paths mantém cache hit ao voltar', () async {
    final adapter = _SessionTestAdapter();
    final container = ProviderContainer(
      overrides: [
        pdfxViewerAdapterProvider.overrideWithValue(adapter),
      ],
    );
    addTearDown(container.dispose);

    const pathA = 'asset:fixtures/a.pdf';
    const pathB = 'asset:fixtures/b.pdf';

    final subA = container.listen(
      pdfReaderSessionProvider(pathA),
      (_, __) {},
      fireImmediately: true,
    );
    final sessionA =
        await container.read(pdfReaderSessionProvider(pathA).future);
    final controllerA = sessionA.controller;
    subA.close();
    await Future<void>.delayed(Duration.zero);

    final subB = container.listen(
      pdfReaderSessionProvider(pathB),
      (_, __) {},
      fireImmediately: true,
    );
    await container.read(pdfReaderSessionProvider(pathB).future);
    expect(adapter.openDocumentCallCount, 2);
    subB.close();
    await Future<void>.delayed(Duration.zero);

    final subA2 = container.listen(
      pdfReaderSessionProvider(pathA),
      (_, __) {},
      fireImmediately: true,
    );
    final sessionA2 =
        await container.read(pdfReaderSessionProvider(pathA).future);
    expect(sessionA2.controller, same(controllerA));
    expect(adapter.openDocumentCallCount, 2);

    subA2.close();
    await Future<void>.delayed(Duration.zero);
    container.read(readerRouteParamsProvider.notifier).update(
      {UrlSyncParams.file: pathA},
    );
    container.read(readerRouteParamsProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);
  });

  test('pdf local corrompido remove cache e lança PdfLocalCorruptedException',
      () async {
    await Isar.initializeIsarCore(download: true);
    final tempDir =
        await Directory.systemTemp.createTemp('pdf_reader_session_');
    final docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);
    final isar = await Isar.open(
      [OfflinePdfIndexSchema],
      directory: tempDir.path,
    );
    addTearDown(() async {
      await isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final repository = OfflinePdfRepositoryImpl(
      store:
          PdfLocalStore(getApplicationDocumentsDirectory: () async => docsDir),
      local: OfflinePdfLocalDatasource(isar),
    );
    const category = 'ColAdultos';
    const relPath = 'ColAdultos/001.pdf';
    final pdfId = encodePdfId(relPath);
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x00]),
      category: category,
    );

    expect(
      await repository.findPdfIdByAbsolutePath(entry.absolutePath),
      pdfId,
    );
    expect(
      const PdfSourceResolver().resolve(entry.absolutePath).kind,
      PdfSourceKind.localFile,
    );

    final adapter = _CorruptLocalAdapter();
    final container = ProviderContainer(
      overrides: [
        pdfxViewerAdapterProvider.overrideWithValue(adapter),
        offlinePdfRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(pdfReaderSessionProvider(entry.absolutePath).future),
      throwsA(isA<PdfLocalCorruptedException>()),
    );

    expect(await repository.lookup(pdfId), isNull);
  });
}
