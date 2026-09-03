import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/core/database/collections/offline_pdf_index.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/features/offline/data/datasources/offline_pdf_local_datasource.dart';
import 'package:coldigui/features/offline/data/datasources/pdf_local_store.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/data/repositories/offline_pdf_repository_impl.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/data/adapters/pdfrx_viewer_adapter.dart';
import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/data/providers/pdf_reader_providers.dart';
import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/pdf_local_open_failure.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/pdf_local_read_failed_exception.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_session_cache.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

import '../offline/offline_test_helpers.dart';
import 'pdf_reader_test_helpers.dart';

class _SessionTestAdapter extends PdfrxViewerAdapter {
  _SessionTestAdapter()
    : super(
        PdfBytesDatasource(
          _NoOpDio(),
          resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
        ),
        resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
      );

  TrackablePdfReaderViewerHandle? created;
  var openDocumentCallCount = 0;

  @override
  Future<PdfReaderViewerHandle> openDocument(String filePath) async {
    openDocumentCallCount++;
    created = createTrackableHandle();
    return created!;
  }
}

class _CorruptLocalAdapter extends PdfrxViewerAdapter {
  _CorruptLocalAdapter({Object Function()? errorBuilder})
    : _errorBuilder = errorBuilder ?? (() => Exception('corrupt pdf')),
      super(
        PdfBytesDatasource(
          _NoOpDio(),
          resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
        ),
        resolver: const PdfSourceResolver(apiBaseUrl: 'https://example.com'),
      );

  final Object Function() _errorBuilder;

  @override
  Future<PdfReaderViewerHandle> openDocument(String filePath) async {
    throw _errorBuilder();
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
      overrides: [pdfViewerAdapterProvider.overrideWithValue(adapter)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, _) {},
      fireImmediately: true,
    );

    final session = await container.read(
      pdfReaderSessionProvider(filePath).future,
    );
    expect(session.handle, same(adapter.created));

    sub.close();
    await Future<void>.delayed(Duration.zero);

    expect(adapter.created!.wasDisposed, isFalse);
    expect(container.read(pdfSessionCacheProvider).length, 1);
  });

  test('sair do leitor limpa cache e descarta handles', () async {
    final adapter = _SessionTestAdapter();
    final container = ProviderContainer(
      overrides: [pdfViewerAdapterProvider.overrideWithValue(adapter)],
    );
    addTearDown(container.dispose);

    container.read(readerRouteParamsProvider.notifier).update({
      UrlSyncParams.file: filePath,
    });

    final sub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, _) {},
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

  test('reabrir reutiliza handle do cache LRU', () async {
    final adapter = _SessionTestAdapter();
    final container = ProviderContainer(
      overrides: [pdfViewerAdapterProvider.overrideWithValue(adapter)],
    );
    addTearDown(container.dispose);

    final firstSub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, _) {},
      fireImmediately: true,
    );
    final firstSession = await container.read(
      pdfReaderSessionProvider(filePath).future,
    );
    final firstHandle = firstSession.handle;
    expect(firstSession.fromCache, isFalse);
    expect(adapter.openDocumentCallCount, 1);
    firstSub.close();
    await Future<void>.delayed(Duration.zero);
    expect(adapter.created!.wasDisposed, isFalse);

    final secondSub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, _) {},
      fireImmediately: true,
    );
    final secondSession = await container.read(
      pdfReaderSessionProvider(filePath).future,
    );
    expect(secondSession.handle, same(firstHandle));
    expect(secondSession.fromCache, isTrue);
    expect(adapter.openDocumentCallCount, 1);
    expect(adapter.created!.wasDisposed, isFalse);

    secondSub.close();
    await Future<void>.delayed(Duration.zero);
    container.read(readerRouteParamsProvider.notifier).update({
      UrlSyncParams.file: filePath,
    });
    container.read(readerRouteParamsProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);
    expect(adapter.created!.wasDisposed, isTrue);
  });

  test('troca entre paths mantém cache hit ao voltar', () async {
    final adapter = _SessionTestAdapter();
    final container = ProviderContainer(
      overrides: [pdfViewerAdapterProvider.overrideWithValue(adapter)],
    );
    addTearDown(container.dispose);

    const pathA = 'asset:fixtures/a.pdf';
    const pathB = 'asset:fixtures/b.pdf';

    final subA = container.listen(
      pdfReaderSessionProvider(pathA),
      (_, _) {},
      fireImmediately: true,
    );
    final sessionA = await container.read(
      pdfReaderSessionProvider(pathA).future,
    );
    final handleA = sessionA.handle;
    subA.close();
    await Future<void>.delayed(Duration.zero);

    final subB = container.listen(
      pdfReaderSessionProvider(pathB),
      (_, _) {},
      fireImmediately: true,
    );
    await container.read(pdfReaderSessionProvider(pathB).future);
    expect(adapter.openDocumentCallCount, 2);
    subB.close();
    await Future<void>.delayed(Duration.zero);

    final subA2 = container.listen(
      pdfReaderSessionProvider(pathA),
      (_, _) {},
      fireImmediately: true,
    );
    final sessionA2 = await container.read(
      pdfReaderSessionProvider(pathA).future,
    );
    expect(sessionA2.handle, same(handleA));
    expect(adapter.openDocumentCallCount, 2);

    subA2.close();
    await Future<void>.delayed(Duration.zero);
    container.read(readerRouteParamsProvider.notifier).update({
      UrlSyncParams.file: pathA,
    });
    container.read(readerRouteParamsProvider.notifier).clear();
    await Future<void>.delayed(Duration.zero);
  });

  /// Prepara um `OfflinePdfRepositoryImpl` real (Isar) com um PDF indexado
  /// em `bytes` — usado pelos testes de classificação de falha (B3) abaixo.
  Future<
    ({
      OfflinePdfRepositoryImpl repository,
      String pdfId,
      String absolutePath,
      Isar isar,
      Directory tempDir,
    })
  >
  setUpIndexedLocalPdf(Uint8List bytes) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'pdf_reader_session_',
    );
    final docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);
    final isar = Isar.open(
      schemas: [OfflinePdfIndexSchema],
      directory: tempDir.path,
    );

    final repository = OfflinePdfRepositoryImpl(
      store: pdfStoragePortFor(
        PdfLocalStore(getApplicationDocumentsDirectory: () async => docsDir),
      ),
      local: OfflinePdfLocalDatasource(isar),
    );
    const category = 'ColAdultos';
    const relPath = 'ColAdultos/001.pdf';
    final pdfId = encodePdfId(relPath);
    final entry = await repository.upsert(
      pdfId: pdfId,
      bytes: bytes,
      category: category,
    );

    expect(
      const PdfSourceResolver().resolve(entry.absolutePath).kind,
      PdfSourceKind.localFile,
    );

    return (
      repository: repository,
      pdfId: pdfId,
      absolutePath: entry.absolutePath,
      isar: isar,
      tempDir: tempDir,
    );
  }

  test(
    'pdfrx sinaliza erro de formato (bytes válidos) -> remove e lança '
    'PdfLocalCorruptedException (B3 evidência b)',
    () async {
      final fixture = await setUpIndexedLocalPdf(
        Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x00]),
      );
      addTearDown(() async {
        fixture.isar.close(deleteFromDisk: true);
        if (fixture.tempDir.existsSync()) {
          await fixture.tempDir.delete(recursive: true);
        }
      });

      // Bytes lidos e com magic `%PDF` válido, mas o pdfrx recusa o formato.
      final adapter = _CorruptLocalAdapter(
        errorBuilder: () => const PdfLocalOpenFailure(
          cause: 'FPDF_ERR_FORMAT: bad header',
          hasValidMagicBytes: true,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          pdfViewerAdapterProvider.overrideWithValue(adapter),
          offlinePdfRepositoryProvider.overrideWithValue(fixture.repository),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        pdfReaderSessionProvider(fixture.absolutePath),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await expectLater(
        container.read(
          pdfReaderSessionProvider(fixture.absolutePath).future,
        ),
        throwsA(isA<PdfLocalCorruptedException>()),
      );

      expect(await fixture.repository.lookup(fixture.pdfId), isNull);
    },
  );

  test(
    'bytes lidos sem magic %PDF -> remove e lança '
    'PdfLocalCorruptedException (B3 evidência a)',
    () async {
      // HTML de erro salvo no lugar do PDF — cenário real de corrupção.
      final fixture = await setUpIndexedLocalPdf(
        Uint8List.fromList('<html>erro</html>'.codeUnits),
      );
      addTearDown(() async {
        fixture.isar.close(deleteFromDisk: true);
        if (fixture.tempDir.existsSync()) {
          await fixture.tempDir.delete(recursive: true);
        }
      });

      // Bytes lidos com sucesso pelo adapter e SEM o magic `%PDF` — única
      // evidência (a) aceita para remover o PDF offline.
      final adapter = _CorruptLocalAdapter(
        errorBuilder: () => PdfLocalOpenFailure(
          cause: StateError('PDF sem páginas'),
          hasValidMagicBytes: false,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          pdfViewerAdapterProvider.overrideWithValue(adapter),
          offlinePdfRepositoryProvider.overrideWithValue(fixture.repository),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        pdfReaderSessionProvider(fixture.absolutePath),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await expectLater(
        container.read(
          pdfReaderSessionProvider(fixture.absolutePath).future,
        ),
        throwsA(isA<PdfLocalCorruptedException>()),
      );

      expect(await fixture.repository.lookup(fixture.pdfId), isNull);
    },
  );

  test(
    'erro genérico com bytes válidos -> preserva o PDF e lança '
    'PdfLocalReadFailedException (B3 — não apagar por erro genérico)',
    () async {
      final fixture = await setUpIndexedLocalPdf(
        Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x00]),
      );
      addTearDown(() async {
        fixture.isar.close(deleteFromDisk: true);
        if (fixture.tempDir.existsSync()) {
          await fixture.tempDir.delete(recursive: true);
        }
      });

      final adapter = _CorruptLocalAdapter(
        errorBuilder: () => const PdfLocalOpenFailure(
          cause: 'corrupt pdf',
          hasValidMagicBytes: true,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          pdfViewerAdapterProvider.overrideWithValue(adapter),
          offlinePdfRepositoryProvider.overrideWithValue(fixture.repository),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        pdfReaderSessionProvider(fixture.absolutePath),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await expectLater(
        container.read(
          pdfReaderSessionProvider(fixture.absolutePath).future,
        ),
        throwsA(isA<PdfLocalReadFailedException>()),
      );

      expect(await fixture.repository.lookup(fixture.pdfId), isNotNull);
      expect(await File(fixture.absolutePath).exists(), isTrue);
    },
  );

  test(
    'arquivo removido externamente (bytes não encontrados) -> preserva '
    'índice e lança PdfLocalReadFailedException',
    () async {
      final fixture = await setUpIndexedLocalPdf(
        Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x00]),
      );
      addTearDown(() async {
        fixture.isar.close(deleteFromDisk: true);
        if (fixture.tempDir.existsSync()) {
          await fixture.tempDir.delete(recursive: true);
        }
      });
      // Simula exclusão externa do arquivo (fora do controle do app).
      await File(fixture.absolutePath).delete();

      final adapter = _CorruptLocalAdapter(
        errorBuilder: () => Exception('Timeout ao ler arquivo'),
      );
      final container = ProviderContainer(
        overrides: [
          pdfViewerAdapterProvider.overrideWithValue(adapter),
          offlinePdfRepositoryProvider.overrideWithValue(fixture.repository),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        pdfReaderSessionProvider(fixture.absolutePath),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await expectLater(
        container.read(
          pdfReaderSessionProvider(fixture.absolutePath).future,
        ),
        throwsA(isA<PdfLocalReadFailedException>()),
      );

      // `lookup` valida a presença física do arquivo (ausente de propósito
      // neste teste); o que importa aqui é que o índice NÃO foi removido —
      // ou seja, B3 não tratou a ausência do arquivo como corrupção.
      expect(
        await fixture.repository.findPdfIdByAbsolutePath(
          fixture.absolutePath,
        ),
        fixture.pdfId,
      );
    },
  );

  test(
    'arquivo existe mas não pode ser lido (permissão/storage) -> preserva '
    'arquivo e índice e lança PdfLocalReadFailedException (B3 R1)',
    () async {
      final fixture = await setUpIndexedLocalPdf(
        Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x00]),
      );
      addTearDown(() async {
        // Devolve a permissão antes de limpar o diretório temporário.
        Process.runSync('chmod', ['600', fixture.absolutePath]);
        fixture.isar.close(deleteFromDisk: true);
        if (fixture.tempDir.existsSync()) {
          await fixture.tempDir.delete(recursive: true);
        }
      });

      // Arquivo presente no disco, porém ilegível (permissão negada / erro de
      // storage / scoped storage). NÃO é evidência de corrupção.
      final chmod = Process.runSync('chmod', ['000', fixture.absolutePath]);
      expect(chmod.exitCode, 0, reason: 'chmod 000 falhou: ${chmod.stderr}');
      expect(File(fixture.absolutePath).existsSync(), isTrue);

      final adapter = _CorruptLocalAdapter(
        errorBuilder: () =>
            const FileSystemException('Permission denied', 'open'),
      );
      final container = ProviderContainer(
        overrides: [
          pdfViewerAdapterProvider.overrideWithValue(adapter),
          offlinePdfRepositoryProvider.overrideWithValue(fixture.repository),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        pdfReaderSessionProvider(fixture.absolutePath),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await expectLater(
        container.read(pdfReaderSessionProvider(fixture.absolutePath).future),
        throwsA(isA<PdfLocalReadFailedException>()),
      );

      expect(
        await fixture.repository.findPdfIdByAbsolutePath(
          fixture.absolutePath,
        ),
        fixture.pdfId,
      );
      expect(File(fixture.absolutePath).existsSync(), isTrue);
    },
    skip: Platform.isWindows ? 'chmod indisponível no Windows' : null,
  );
}
