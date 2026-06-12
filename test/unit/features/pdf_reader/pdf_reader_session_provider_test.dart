import 'dart:async';

import 'package:coldigui/features/pdf_reader/data/adapters/pdfx_viewer_adapter.dart';
import 'package:coldigui/features/pdf_reader/data/providers/pdf_reader_providers.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:coldigui/features/pdf_opening/data/datasources/pdf_bytes_datasource.dart';
import 'package:coldigui/features/pdf_reader/data/utils/pdf_source_resolver.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfx/pdfx.dart';

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

  @override
  Future<PdfControllerPinch> openDocument(String filePath) async {
    created = _TrackableController();
    return created!;
  }
}

class _NoOpDio implements Dio {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const filePath = 'asset:fixtures/sample.pdf';

  test('pdfReaderSessionProvider dispose libera controller ao sair', () async {
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
    expect(adapter.controller, same(adapter.created));

    sub.close();
    await Future<void>.delayed(Duration.zero);

    expect(adapter.created!.wasDisposed, isTrue);
    expect(adapter.controller, isNull);
  });

  test('reabrir cria controller novo após dispose da sessão anterior',
      () async {
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
    firstSub.close();
    await Future<void>.delayed(Duration.zero);
    expect(adapter.created!.wasDisposed, isTrue);

    final secondSub = container.listen(
      pdfReaderSessionProvider(filePath),
      (_, __) {},
      fireImmediately: true,
    );
    final secondSession =
        await container.read(pdfReaderSessionProvider(filePath).future);
    expect(secondSession.controller, isNot(same(firstController)));
    expect(adapter.created!.wasDisposed, isFalse);

    secondSub.close();
    await Future<void>.delayed(Duration.zero);
    expect(adapter.created!.wasDisposed, isTrue);
  });
}
