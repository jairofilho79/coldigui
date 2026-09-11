import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/widgets/active_list_panel.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/carousel_reader_position.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/pdf_local_read_failed_exception.dart';
import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/presentation/pages/pdf_reader_screen.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_side_panel_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../unit/features/pdf_reader/pdf_reader_test_helpers.dart';

/// Handle de teste para C8 (última página): [isViewerReady] fixo em `true`
/// (o teste não monta um `PdfViewer` real anexado) e [animateToPage]
/// gravado em vez de delegar ao controller de verdade.
class _RestoreTrackingHandle extends TrackablePdfReaderViewerHandle {
  _RestoreTrackingHandle({
    required super.document,
    required super.documentRef,
    required super.viewerController,
  });

  final List<int> animateToPageCalls = [];

  @override
  bool get isViewerReady => true;

  @override
  Future<void> animateToPage({
    required int pageNumber,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.easeInOut,
  }) async {
    animateToPageCalls.add(pageNumber);
  }
}

_RestoreTrackingHandle _createRestoreTrackingHandle({int pageCount = 5}) {
  final document = FakePdfDocument(pageCount: pageCount);
  final handle = _RestoreTrackingHandle(
    document: document,
    documentRef: PdfDocumentRefDirect(document, autoDispose: false),
    viewerController: PdfViewerController(),
  );
  handle.loadingState.value = PdfReaderLoadingState.success;
  return handle;
}

const _carouselItems = <CarouselItem>[
  CarouselItem(
    materialId: 'x',
    kind: MaterialKind.pdf,
    index: 0,
    key: 'x',
    numero: '1',
    nome: 'Louvor',
    categoria: 'c',
    classificacao: 'Col',
  ),
];

class _FixedOfflineCacheStatusNotifier extends OfflineCacheStatusNotifier {
  @override
  OfflineCacheStatus build() => OfflineCacheStatus.empty;
}

ProviderScope _readerScope({
  required SharedPreferences prefs,
  required Widget child,
  List<Override> overrides = const [],
  List<CarouselItem> carouselItems = const [],
}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      offlineCacheStatusProvider.overrideWith(
        _FixedOfflineCacheStatusNotifier.new,
      ),
      carouselItemsProvider.overrideWithValue(carouselItems),
      ...overrides,
    ],
    child: child,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PdfReaderScreen exibe erro quando file ausente', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        child: const MaterialApp(
          home: Scaffold(body: PdfReaderScreen(queryParams: {})),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Parâmetro file ausente na URL'), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsNothing);
  });

  testWidgets('PdfReaderScreen exibe erro de path inválido', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        child: const MaterialApp(
          home: Scaffold(
            body: PdfReaderScreen(
              queryParams: {'file': 'file:///etc/passwd', 'titulo': 'Teste'},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Esquema de URL não permitido'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('PdfReaderScreen exibe botão de fullscreen', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        overrides: [
          pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
            (ref) => Future.error(const InvalidPdfPathException('stub')),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': 'asset:fixtures/sample.pdf',
                'titulo': 'Fixture',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  testWidgets('toggle fullscreen exibe FAB de saída e oculta toolbar', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        overrides: [
          pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
            (ref) => Future.error(const InvalidPdfPathException('stub')),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': 'asset:fixtures/sample.pdf',
                'titulo': 'Fixture',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(find.byIcon(Icons.share), findsNothing);
  });

  test('pdfReaderErrorMessage formata InvalidPdfPathException', () {
    const error = InvalidPdfPathException('teste');
    expect(pdfReaderErrorMessage(error), 'teste');
  });

  test('pdfReaderErrorMessage formata exceções offline', () {
    const offline = PdfOfflineUnavailableException(pdfId: 'x');
    const fetchFailed = PdfFetchFailedException('erro fetch');
    const readFailed = PdfLocalReadFailedException(pdfId: 'w');

    expect(pdfReaderErrorMessage(offline), offline.message);
    expect(pdfReaderErrorMessage(fetchFailed), 'erro fetch');
    expect(pdfReaderErrorMessage(readFailed), readFailed.message);
  });

  test(
    'pdfReaderErrorMessage cai no genérico para removido/corrompido (D.6)',
    () {
      // As duas perderam o literal PT: quem tem `context` mostra o texto do
      // l10n; este fallback sem l10n só pode dizer o genérico.
      const deleted = PdfExternallyDeletedException(pdfId: 'y');
      const corrupted = PdfLocalCorruptedException(pdfId: 'z');

      expect(pdfReaderErrorMessage(deleted), 'Não foi possível abrir o PDF');
      expect(pdfReaderErrorMessage(corrupted), 'Não foi possível abrir o PDF');
    },
  );

  testWidgets('PdfReaderScreen exibe fallback genérico com retry para '
      'PdfLocalReadFailedException (B3 — não apaga PDF por erro genérico)', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    const readFailed = PdfLocalReadFailedException(pdfId: 'pdf-2');

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        overrides: [
          pdfReaderSessionProvider(
            '/tmp/read-failed.pdf',
          ).overrideWith((ref) => Future.error(readFailed)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': '/tmp/read-failed.pdf',
                'pdfId': 'pdf-2',
                'titulo': 'Fixture',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(readFailed.message), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Baixar novamente'), findsNothing);
  });

  testWidgets('PdfReaderScreen exibe Baixar novamente para PDF corrompido', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    const corrupted = PdfLocalCorruptedException(pdfId: 'pdf-1');

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        overrides: [
          pdfReaderSessionProvider(
            '/tmp/corrupt.pdf',
          ).overrideWith((ref) => Future.error(corrupted)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': '/tmp/corrupt.pdf',
                'pdfId': 'pdf-1',
                'titulo': 'Fixture',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    expect(find.text(l10n.pdfLocalCorrupted), findsOneWidget);
    expect(find.text('Baixar novamente'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('PdfReaderScreen exibe botão share com sessão carregada', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        overrides: [
          pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith((
            ref,
          ) async {
            final handle = createTrackableHandle();
            handle.loadingState.value = PdfReaderLoadingState.success;
            ref.onDispose(handle.dispose);
            return PdfReaderSession(
              handle: handle,
              filePath: 'asset:fixtures/sample.pdf',
            );
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': 'asset:fixtures/sample.pdf',
                'titulo': 'Fixture',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byIcon(Icons.share).evaluate().isNotEmpty) break;
    }

    expect(find.byIcon(Icons.share), findsOneWidget);
    expect(find.byIcon(Icons.download), findsNothing);
  });

  testWidgets('PdfReaderScreen não duplica barra carousel (fica no shell)', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        overrides: [
          readerCarouselPositionProvider('B').overrideWith(
            (ref) => const CarouselReaderPosition(
              currentIndex: 2,
              total: 3,
              currentKey: 'B',
              previousMaterialId: 'A',
              nextMaterialId: 'C',
              previousKey: 'A',
              nextKey: 'C',
            ),
          ),
          pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
            (ref) => Future.error(const InvalidPdfPathException('stub')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': 'asset:fixtures/sample.pdf',
                'pdfId': 'B',
                'titulo': 'Fixture',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.view_list), findsNothing);
    expect(find.byIcon(Icons.layers_outlined), findsNothing);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  testWidgets('PdfReaderScreen oculta título quando carousel tem itens', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        carouselItems: _carouselItems,
        overrides: [
          pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
            (ref) => Future.error(const InvalidPdfPathException('stub')),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': 'asset:fixtures/sample.pdf',
                'titulo': 'Fixture',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Fixture'), findsNothing);
  });

  testWidgets('reabrir leitor após sair não reutiliza sessão anterior', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    Widget buildReader() => _readerScope(
      prefs: prefs,
      child: const MaterialApp(
        home: Scaffold(
          body: PdfReaderScreen(
            queryParams: {
              'file': 'asset:fixtures/sample.pdf',
              'titulo': 'Fixture',
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildReader());
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(buildReader());
    await tester.pump();

    expect(find.byType(PdfReaderScreen), findsOneWidget);
  });

  testWidgets(
    'restaura a última página lembrada quando a rota não traz page (C8)',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.pdfLastPages: jsonEncode([
          {'id': 'pdf-x', 'p': 3},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final handle = _createRestoreTrackingHandle();

      await tester.pumpWidget(
        _readerScope(
          prefs: prefs,
          overrides: [
            pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
              (ref) async => PdfReaderSession(
                handle: handle,
                filePath: 'asset:fixtures/sample.pdf',
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PdfReaderScreen(
                queryParams: {
                  'file': 'asset:fixtures/sample.pdf',
                  'pdfId': 'pdf-x',
                  'titulo': 'Fixture',
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (handle.animateToPageCalls.isNotEmpty) break;
      }

      expect(handle.animateToPageCalls, [3]);
    },
  );

  testWidgets('não restaura a última página quando a rota já traz page (C8)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.pdfLastPages: jsonEncode([
        {'id': 'pdf-x', 'p': 3},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final handle = _createRestoreTrackingHandle();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        overrides: [
          pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
            (ref) async => PdfReaderSession(
              handle: handle,
              filePath: 'asset:fixtures/sample.pdf',
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': 'asset:fixtures/sample.pdf',
                'pdfId': 'pdf-x',
                'titulo': 'Fixture',
                'page': '1',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(handle.animateToPageCalls, isEmpty);
  });

  testWidgets('botão de ajuste chama toggleFitMode (C8)', (tester) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        overrides: [
          pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
            (ref) => Future.error(const InvalidPdfPathException('stub')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': 'asset:fixtures/sample.pdf',
                'titulo': 'Fixture',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    expect(find.byTooltip(l10n.readerFitModeTooltip), findsOneWidget);
    expect(find.byIcon(Icons.fit_screen_outlined), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.readerFitModeTooltip));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.fit_screen), findsOneWidget);
  });

  testWidgets('tela larga mostra o painel com a lista ativa (C7)', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        carouselItems: _carouselItems,
        overrides: [
          pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
            (ref) => Future.error(const InvalidPdfPathException('stub')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': 'asset:fixtures/sample.pdf',
                'titulo': 'Fixture',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ActiveListPanel), findsOneWidget);
    expect(find.textContaining('Louvor'), findsOneWidget);
  });

  testWidgets('botão do painel alterna readerSidePanelOpenProvider (C7)', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        carouselItems: _carouselItems,
        overrides: [
          pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
            (ref) => Future.error(const InvalidPdfPathException('stub')),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: const Scaffold(
            body: PdfReaderScreen(
              queryParams: {
                'file': 'asset:fixtures/sample.pdf',
                'titulo': 'Fixture',
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(ActiveListPanel), findsOneWidget);

    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    await tester.tap(find.byTooltip(l10n.readerSidePanelHideTooltip));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PdfReaderScreen)),
    );
    expect(container.read(readerSidePanelOpenProvider), isFalse);
    expect(find.byType(ActiveListPanel), findsNothing);
    expect(find.byTooltip(l10n.readerSidePanelShowTooltip), findsOneWidget);
  });
}
