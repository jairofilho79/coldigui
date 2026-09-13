import 'dart:convert';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/mini_player_bar_metrics.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/catalog/presentation/providers/catalog_material_lookup_provider.dart';
import 'package:coldigui/features/offline/data/providers/offline_providers.dart';
import 'package:coldigui/features/offline/domain/entities/local_pdf_source.dart';
import 'package:coldigui/features/offline/domain/usecases/resolve_pdf_for_reader.dart';
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
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../unit/features/pdf_reader/pdf_reader_test_helpers.dart';

/// Sessão de áudio de mentira — só o que a barra do leitor precisa
/// (`currentTrack`) para decidir se o overlay do mini-player aparece
/// (Important 3, onda 4).
class _FakeAudioSession extends AudioPlayerSessionNotifier {
  _FakeAudioSession(this._state);

  final AudioPlayerSessionState _state;

  @override
  AudioPlayerSessionState build() => _state;
}

const _playingTrack = AudioTrack(
  audioId: 'aud-1',
  r2Key: 'assets/praises/p1/a.mp3',
  nome: 'Louvor',
  numero: '12',
  groupId: 'p1',
  categoria: 'Áudio',
  classificacao: 'Coro',
);

/// Resolver de teste (fix round 1) — sempre falha com o erro dado, sem tocar
/// rede/Isar; usado para exercitar os catches de `_redownloadCorruptedPdf`.
class _ThrowingResolvePdfForReader extends Fake implements ResolvePdfForReader {
  _ThrowingResolvePdfForReader(this._error);

  final Object _error;

  @override
  Future<LocalPdfSource> call({
    required String pdfId,
    required String remotePath,
    ProgressCallback? onProgress,
  }) async {
    throw _error;
  }
}

/// Handle de teste para C8 (última página) / Important 2 (onda 4):
/// [isViewerReady] segue [loadingState] de verdade (não fixo em `true`) —
/// começa `loading` e só fica pronto quando o teste dispara a notificação
/// (`loadingState.value = success`), simulando o `onViewerReady` real do
/// pdfrx chegar DEPOIS do primeiro frame. [animateToPage] é gravado em vez de
/// delegar ao controller de verdade (o teste não monta um `PdfViewer` real
/// anexado).
class _RestoreTrackingHandle extends TrackablePdfReaderViewerHandle {
  _RestoreTrackingHandle({
    required super.document,
    required super.documentRef,
    required super.viewerController,
  });

  final List<int> animateToPageCalls = [];

  @override
  bool get isViewerReady => loadingState.value == PdfReaderLoadingState.success;

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
  return _RestoreTrackingHandle(
    document: document,
    documentRef: PdfDocumentRefDirect(document, autoDispose: false),
    viewerController: PdfViewerController(),
  );
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

    // InvalidPdfPathException não carrega mais literal PT (E8 fix round 1):
    // cai no fallback genérico de pdfReaderErrorMessage.
    expect(find.text('Não foi possível abrir o PDF'), findsOneWidget);
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

  // Important 3 (onda 4): o overlay MiniPlayerBar (44px, bottom: 0) do shell
  // aparece na mesma condição — fullscreen + faixa tocando — e cobriria a
  // metade de baixo do FAB sem esse respiro.
  Future<Positioned> pumpFullscreenFabPositioned(
    WidgetTester tester, {
    required List<Override> overrides,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _readerScope(
        prefs: prefs,
        overrides: [
          pdfReaderSessionProvider('asset:fixtures/sample.pdf').overrideWith(
            (ref) => Future.error(const InvalidPdfPathException('stub')),
          ),
          ...overrides,
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
    await tester.tap(find.byIcon(Icons.fullscreen));
    await tester.pumpAndSettle();

    return tester.widget<Positioned>(
      find.ancestor(
        of: find.byIcon(Icons.fullscreen_exit),
        matching: find.byType(Positioned),
      ),
    );
  }

  testWidgets('sem faixa tocando, fullscreen mantém o FAB em bottom 16 (I3)', (
    tester,
  ) async {
    final positioned = await pumpFullscreenFabPositioned(tester, overrides: []);

    expect(positioned.bottom, 16);
  });

  testWidgets(
    'com faixa tocando, fullscreen sobe o FAB acima do mini-player (I3)',
    (tester) async {
      final positioned = await pumpFullscreenFabPositioned(
        tester,
        overrides: [
          audioPlayerSessionProvider.overrideWith(
            () => _FakeAudioSession(
              const AudioPlayerSessionState(queue: [_playingTrack]),
            ),
          ),
        ],
      );

      expect(positioned.bottom, 16 + kMiniPlayerBarHeight);
    },
  );

  test('pdfReaderErrorMessage formata exceções offline', () {
    const offline = PdfOfflineUnavailableException(pdfId: 'x');
    const fetchFailed = PdfFetchFailedException('erro fetch');

    expect(pdfReaderErrorMessage(offline), offline.message);
    expect(pdfReaderErrorMessage(fetchFailed), 'erro fetch');
  });

  test('pdfReaderErrorMessage cai no genérico para removido/corrompido/caminho '
      'inválido/leitura falhou (D.6, E8 fix round 1)', () {
    // As quatro perderam o literal PT: quem tem `context` mostra o texto
    // do l10n (pdfExternallyDeleted/pdfLocalCorrupted/pdfLocalReadFailedMessage);
    // este fallback sem l10n só pode dizer o genérico. InvalidPdfPathException
    // nunca teve chave l10n própria — sempre caiu aqui.
    const deleted = PdfExternallyDeletedException(pdfId: 'y');
    const corrupted = PdfLocalCorruptedException(pdfId: 'z');
    const invalidPath = InvalidPdfPathException('Esquema de URL não permitido');
    const readFailed = PdfLocalReadFailedException(pdfId: 'w');

    expect(pdfReaderErrorMessage(deleted), 'Não foi possível abrir o PDF');
    expect(pdfReaderErrorMessage(corrupted), 'Não foi possível abrir o PDF');
    expect(pdfReaderErrorMessage(invalidPath), 'Não foi possível abrir o PDF');
    expect(pdfReaderErrorMessage(readFailed), 'Não foi possível abrir o PDF');
  });

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

    // Sem l10n neste MaterialApp: cai no genérico (E8 fix round 1) — a chave
    // pdfLocalReadFailedMessage é coberta com l10n no teste seguinte.
    expect(find.text('Não foi possível abrir o PDF'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Baixar novamente'), findsNothing);
  });

  testWidgets(
    'PdfReaderScreen exibe a chave l10n para PdfLocalReadFailedException '
    'quando l10n está disponível (E8 fix round 1)',
    (tester) async {
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
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: const Scaffold(
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

      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      expect(find.text(l10n.pdfLocalReadFailedMessage), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Baixar novamente'), findsNothing);
    },
  );

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

  testWidgets(
    'redownload de PDF removido externamente mantém texto e ação Baixar '
    '(fix round 1)',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      // pdfId real (Base64 do caminho relativo) — LouvorPdfPath.fromLouvor
      // decodifica via PdfPathNormalizer.getPdfRelPath e lança FormatException
      // com um id não codificado como 'pdf-1'.
      final pdfId = encodePdfId('ColAdultos/001.pdf');
      final corrupted = PdfLocalCorruptedException(pdfId: pdfId);
      final louvor = Louvor(
        nome: 'Aleluia',
        numero: '001',
        categoria: 'ColAdultos',
        classificacao: 'Partitura',
        pdf: 'ColAdultos/001.pdf',
        pdfId: pdfId,
        groupId: '001:aleluia',
        searchTitleNorm: 'aleluia',
        searchContentTokens: const [],
        searchCompactContent: '',
      );

      await tester.pumpWidget(
        _readerScope(
          prefs: prefs,
          overrides: [
            pdfReaderSessionProvider(
              '/tmp/corrupt.pdf',
            ).overrideWith((ref) => Future.error(corrupted)),
            catalogMaterialLookupProvider.overrideWithValue(
              CatalogMaterialLookup(plpcgLouvoresByPdfId: {pdfId: louvor}),
            ),
            resolvePdfForReaderProvider.overrideWithValue(
              _ThrowingResolvePdfForReader(
                PdfExternallyDeletedException(pdfId: pdfId),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: Scaffold(
              body: PdfReaderScreen(
                queryParams: {
                  'file': '/tmp/corrupt.pdf',
                  'pdfId': pdfId,
                  'titulo': 'Fixture',
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Baixar novamente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      expect(find.text(l10n.pdfExternallyDeleted), findsOneWidget);
      expect(find.text(l10n.pdfOfflineGoToSettings), findsOneWidget);
    },
  );

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

      // O viewer pdfrx só notifica pronto DEPOIS do primeiro frame — Important
      // 2 (onda 4): sem a restauração escutar essa notificação (em vez de um
      // post-frame cego agendado antes disso), a restauração nunca aconteceria.
      handle.loadingState.value = PdfReaderLoadingState.success;
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
    handle.loadingState.value = PdfReaderLoadingState.success;
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

  testWidgets(
    'sem item de menu «duas páginas» — spread é automático (onda 4.1)',
    (tester) async {
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

      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byType(PopupMenuButton<void>), findsNothing);
    },
  );
}
