@TestOn('browser')
library;

import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_batch_item.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/data/adapters/pdfrx_viewer_adapter.dart';
import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/data/providers/pdf_reader_viewer_providers.dart';
import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/pdf_local_open_failure.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/pdf_local_read_failed_exception.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositório offline em memória — o Isar não roda em `--platform chrome`.
class _InMemoryOfflinePdfRepository implements OfflinePdfRepository {
  _InMemoryOfflinePdfRepository({
    required this.pdfId,
    required this.absolutePath,
  });

  final String pdfId;
  final String absolutePath;

  final removedPdfIds = <String>[];
  var isIndexed = true;

  @override
  Future<String?> findPdfIdByAbsolutePath(String path) async =>
      isIndexed && path == absolutePath ? pdfId : null;

  @override
  Future<void> remove(String id) async {
    removedPdfIds.add(id);
    if (id == pdfId) isIndexed = false;
  }

  @override
  Future<OfflinePdfEntry?> findIndexEntry(String id) async => null;

  @override
  Future<void> upsertBatch(List<OfflinePdfBatchItem> items) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoOpDio implements Dio {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Adapter que falha ao abrir — o erro é o que a classificação B3 avalia.
class _FailingLocalAdapter extends PdfrxViewerAdapter {
  _FailingLocalAdapter(this._errorBuilder)
    : super(
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

void main() {
  const absolutePath = '/documents/ColAdultos/001.pdf';
  const pdfId = 'ColAdultos__001';

  ({ProviderContainer container, _InMemoryOfflinePdfRepository repository})
  buildContainer(Object Function() errorBuilder) {
    final repository = _InMemoryOfflinePdfRepository(
      pdfId: pdfId,
      absolutePath: absolutePath,
    );
    final container = ProviderContainer(
      overrides: [
        pdfViewerAdapterProvider.overrideWithValue(
          _FailingLocalAdapter(errorBuilder),
        ),
        offlinePdfRepositoryProvider.overrideWithValue(repository),
      ],
    );
    return (container: container, repository: repository);
  }

  group('B3 na web — erro ao abrir PDF local', () {
    test('o path local continua sendo localFile na web', () {
      expect(
        const PdfSourceResolver(
          apiBaseUrl: 'https://example.com',
        ).resolve(absolutePath).kind,
        PdfSourceKind.localFile,
      );
    });

    test('erro genérico preserva a entrada do índice offline', () async {
      final fixture = buildContainer(() => Exception('falha inesperada'));
      addTearDown(fixture.container.dispose);

      final sub = fixture.container.listen(
        pdfReaderSessionProvider(absolutePath),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await expectLater(
        fixture.container.read(pdfReaderSessionProvider(absolutePath).future),
        throwsA(isA<PdfLocalReadFailedException>()),
      );

      expect(fixture.repository.removedPdfIds, isEmpty);
      expect(fixture.repository.isIndexed, isTrue);
      expect(
        await fixture.repository.findPdfIdByAbsolutePath(absolutePath),
        pdfId,
      );
    });

    test('falha de leitura dos bytes preserva a entrada do índice', () async {
      final fixture = buildContainer(
        () => StateError('Não foi possível ler os bytes'),
      );
      addTearDown(fixture.container.dispose);

      final sub = fixture.container.listen(
        pdfReaderSessionProvider(absolutePath),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await expectLater(
        fixture.container.read(pdfReaderSessionProvider(absolutePath).future),
        throwsA(isA<PdfLocalReadFailedException>()),
      );

      expect(fixture.repository.removedPdfIds, isEmpty);
    });

    test('bytes lidos sem magic %PDF removem o PDF também na web '
        '(mesmo comportamento do nativo)', () async {
      final fixture = buildContainer(
        () => const PdfLocalOpenFailure(
          cause: 'documento inválido',
          hasValidMagicBytes: false,
        ),
      );
      addTearDown(fixture.container.dispose);

      final sub = fixture.container.listen(
        pdfReaderSessionProvider(absolutePath),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await expectLater(
        fixture.container.read(pdfReaderSessionProvider(absolutePath).future),
        throwsA(isA<PdfLocalCorruptedException>()),
      );

      expect(fixture.repository.removedPdfIds, [pdfId]);
    });
  });
}
