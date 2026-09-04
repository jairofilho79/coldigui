import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/core/utils/url_sync_params.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_louvores_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/widgets/pdf_reader_page_key_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpHandler(
    WidgetTester tester, {
    required int currentPage,
    required int pagesCount,
    required bool enabled,
    required bool pageTurnInProgress,
    required List<int> navigatedPages,
  }) async {
    // Sem `pdfId` na rota o handler não tem louvor vizinho para onde ir, então
    // as teclas de carousel viram no-op — é o que estes casos medem.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PdfReaderPageKeyHandler(
              currentPage: currentPage,
              pagesCount: pagesCount,
              enabled: enabled,
              pageTurnInProgress: pageTurnInProgress,
              onNavigateToPage: (page) async {
                navigatedPages.add(page);
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('ArrowRight navega para próxima página', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(navigated, [3]);
  });

  testWidgets('ArrowUp navega para página anterior', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 3,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(navigated, [2]);
  });

  testWidgets('ArrowLeft na primeira página não navega', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 1,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(navigated, isEmpty);
  });

  testWidgets('ArrowUp na primeira página não navega', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 1,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(navigated, isEmpty);
  });

  testWidgets('Espaço navega para próxima página', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(navigated, [3]);
  });

  testWidgets('Shift+Espaço navega para página anterior', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 3,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(navigated, [2]);
  });

  testWidgets('PageDown navega para próxima página', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();

    expect(navigated, [3]);
  });

  testWidgets('Home e End vão aos extremos do documento', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 3,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();

    expect(navigated, [1, 5]);
  });

  testWidgets('sem pdfId, ArrowRight na última página não faz nada', (
    tester,
  ) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 5,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(navigated, isEmpty);
  });

  testWidgets('ArrowRight na última página pula para o próximo louvor (B5)', (
    tester,
  ) async {
    final readerActions = _FakeReaderCarouselActions();
    final navigated = <int>[];
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          carouselLouvoresProvider.overrideWith(
            () => _FakeCarouselNotifier(const [
              CarouselItem(
                pdfId: 'pdf-1',
                sortOrder: 0,
                numero: '001',
                nome: 'Um',
                categoria: 'Partitura',
                classificacao: 'ColAdultos',
              ),
              CarouselItem(
                pdfId: 'pdf-2',
                sortOrder: 1,
                numero: '002',
                nome: 'Dois',
                categoria: 'Partitura',
                classificacao: 'ColAdultos',
              ),
            ]),
          ),
          readerCarouselActionsProvider.overrideWith(() => readerActions),
          readerRouteParamsProvider.overrideWith(
            () => _FakeReaderRouteParams(const {UrlSyncParams.pdfId: 'pdf-1'}),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PdfReaderPageKeyHandler(
              currentPage: 5,
              pagesCount: 5,
              enabled: true,
              pageTurnInProgress: false,
              onNavigateToPage: (page) async => navigated.add(page),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(navigated, isEmpty, reason: 'não há próxima página para virar');
    expect(
      readerActions.navigatedPdfIds,
      ['pdf-2'],
      reason: 'o pedal na última página avança de louvor',
    );
  });

  testWidgets('Ctrl+Espaço não vira página (fica para o play/pause)', (
    tester,
  ) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(navigated, isEmpty);
  });

  testWidgets('ignora teclas quando pageTurnInProgress', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: true,
      pageTurnInProgress: true,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(navigated, isEmpty);
  });

  testWidgets('ignora teclas quando enabled é false', (tester) async {
    final navigated = <int>[];
    await pumpHandler(
      tester,
      currentPage: 2,
      pagesCount: 5,
      enabled: false,
      pageTurnInProgress: false,
      navigatedPages: navigated,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(navigated, isEmpty);
  });
}

/// Ações do carousel do leitor sem rota real — grava o destino pedido.
class _FakeReaderCarouselActions extends ReaderCarouselActionsNotifier {
  final navigatedPdfIds = <String>[];

  @override
  void build() {}

  @override
  Future<String?> navigateToPdfId({required String targetPdfId}) async {
    navigatedPdfIds.add(targetPdfId);
    return '${RoutePaths.reader}?pdfId=$targetPdfId';
  }
}

class _FakeReaderRouteParams extends ReaderRouteParamsNotifier {
  _FakeReaderRouteParams(this.initial);

  final Map<String, String> initial;

  @override
  Map<String, String> build() => initial;
}

class _FakeCarouselNotifier extends CarouselLouvoresNotifier {
  _FakeCarouselNotifier(this.initial);

  final List<CarouselItem> initial;

  @override
  List<CarouselItem> build() => initial;
}
