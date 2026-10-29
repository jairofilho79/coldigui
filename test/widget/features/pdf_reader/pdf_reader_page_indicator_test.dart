import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/go_to_page_dialog.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_page_indicator.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../unit/features/pdf_reader/pdf_reader_test_helpers.dart';

/// Handle que grava chamadas a [animateToPage] sem depender de um
/// [PdfViewerController] de verdade anexado a um `PdfViewer` (o teste não
/// renderiza o pdfrx real — só o indicador).
class _RecordingHandle extends TrackablePdfReaderViewerHandle {
  _RecordingHandle({
    required super.document,
    required super.documentRef,
    required super.viewerController,
  });

  final List<int> animateToPageCalls = [];

  @override
  Future<void> animateToPage({
    required int pageNumber,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
  }) async {
    animateToPageCalls.add(pageNumber);
  }
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  testWidgets('PdfReaderPageIndicator acompanha pageListenable do handle', (
    tester,
  ) async {
    final handle = createTrackableHandle(pageCount: 5);
    handle.loadingState.value = PdfReaderLoadingState.success;
    handle.pageListenable.value = 3;

    final container = ProviderContainer(
      overrides: [
        pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
          (ref) async => PdfReaderSession(
            handle: handle,
            filePath: 'asset:fixtures/sample.pdf',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: PdfReaderPageIndicator(filePath: 'asset:fixtures/sample.pdf'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3/5'), findsOneWidget);

    handle.pageListenable.value = 4;
    await tester.pump();

    expect(find.text('4/5'), findsOneWidget);
  });

  Future<_RecordingHandle> pumpIndicatorWithRecordingHandle(
    WidgetTester tester, {
    int pageCount = 5,
    int currentPage = 3,
  }) async {
    final document = FakePdfDocument(pageCount: pageCount);
    final handle = _RecordingHandle(
      document: document,
      documentRef: PdfDocumentRefDirect(document, autoDispose: false),
      viewerController: PdfViewerController(),
    );
    handle.loadingState.value = PdfReaderLoadingState.success;
    handle.pageListenable.value = currentPage;

    final container = ProviderContainer(
      overrides: [
        pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
          (ref) async => PdfReaderSession(
            handle: handle,
            filePath: 'asset:fixtures/sample.pdf',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: Scaffold(
            body: PdfReaderPageIndicator(filePath: 'asset:fixtures/sample.pdf'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return handle;
  }

  testWidgets('toque no indicador abre o diálogo com o total de páginas', (
    tester,
  ) async {
    await pumpIndicatorWithRecordingHandle(
      tester,
      pageCount: 5,
      currentPage: 3,
    );

    await tester.tap(find.text('3/5'));
    await tester.pumpAndSettle();

    expect(find.byType(GoToPageDialog), findsOneWidget);
    expect(find.text(l10n.readerGoToPageTitle), findsOneWidget);
  });

  testWidgets('número inválido no diálogo desabilita o OK', (tester) async {
    await pumpIndicatorWithRecordingHandle(
      tester,
      pageCount: 5,
      currentPage: 3,
    );

    await tester.tap(find.text('3/5'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.readerGoToPageConfirm),
    );
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets('número válido e OK navega via handle.animateToPage', (
    tester,
  ) async {
    final handle = await pumpIndicatorWithRecordingHandle(
      tester,
      pageCount: 5,
      currentPage: 3,
    );

    await tester.tap(find.text('3/5'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();

    await tester.tap(
      find.widgetWithText(FilledButton, l10n.readerGoToPageConfirm),
    );
    await tester.pumpAndSettle();

    expect(handle.animateToPageCalls, [2]);
  });
}
