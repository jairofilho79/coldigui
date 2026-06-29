import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/offline/presentation/providers/offline_cache_status_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/carousel_reader_position.dart';
import 'package:coldigui/features/offline/domain/exceptions/pdf_resolve_exceptions.dart';
import 'package:coldigui/features/pdf_reader/domain/exceptions/invalid_pdf_path_exception.dart';
import 'package:coldigui/features/pdf_reader/data/models/pdf_reader_viewer_handle.dart';
import 'package:coldigui/features/pdf_reader/presentation/pages/pdf_reader_screen.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/pdf_reader_document_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_position_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../unit/features/pdf_reader/pdf_reader_test_helpers.dart';

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  @override
  List<CarouselItem> build() => const [];
}

class _FakeCarouselNotifierWithItems extends CarouselLouvoresNotifier {
  @override
  List<CarouselItem> build() => const [
    CarouselItem(
      pdfId: 'x',
      sortOrder: 0,
      numero: '1',
      nome: 'Louvor',
      categoria: 'c',
      classificacao: 'Col',
    ),
  ];
}

class _FixedOfflineCacheStatusNotifier extends OfflineCacheStatusNotifier {
  @override
  OfflineCacheStatus build() => OfflineCacheStatus.empty;
}

ProviderScope _readerScope({
  required SharedPreferences prefs,
  required Widget child,
  List<Override> overrides = const [],
  CarouselLouvoresNotifier? carouselNotifier,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      offlineCacheStatusProvider.overrideWith(
        _FixedOfflineCacheStatusNotifier.new,
      ),
      carouselLouvoresProvider.overrideWith(
        () => carouselNotifier ?? _FakeCarouselNotifier(),
      ),
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
    const deleted = PdfExternallyDeletedException(pdfId: 'y');
    const corrupted = PdfLocalCorruptedException(pdfId: 'z');
    const fetchFailed = PdfFetchFailedException('erro fetch');

    expect(pdfReaderErrorMessage(offline), offline.message);
    expect(pdfReaderErrorMessage(deleted), deleted.message);
    expect(pdfReaderErrorMessage(corrupted), corrupted.message);
    expect(pdfReaderErrorMessage(fetchFailed), 'erro fetch');
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
        child: const MaterialApp(
          home: Scaffold(
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

    expect(find.text(corrupted.message), findsOneWidget);
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
              previousPdfId: 'A',
              nextPdfId: 'C',
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
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  testWidgets('PdfReaderScreen oculta título quando carousel tem itens', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        carouselNotifier: _FakeCarouselNotifierWithItems(),
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
}
