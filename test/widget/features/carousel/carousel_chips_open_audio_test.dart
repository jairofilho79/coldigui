// test/widget/features/carousel/carousel_chips_open_audio_test.dart
//
// «Abrir» numa entrada de áudio focada na barra tem que tocar a faixa (fila
// híbrida) em vez de tentar abrir o leitor de PDF (spec 2026-09-12, §3.2).
//
// Harness: mesmo padrão do teste de PDF em `carousel_chips_test.dart`
// ("toque no chip abre leitor com pdf focado") — `Scaffold(body:
// CarouselChips())` com rotas irmãs simples, mais leve que o shell inteiro e
// já provado para exercitar `context.push` a partir da barra. `_FakeAudioSession`
// e as fixtures `track`/`audioEntry` vêm de
// `test/widget/features/app_shell/shell_scaffold_test.dart`.
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/carousel_chips.dart';
import 'package:coldigui/features/catalog/domain/entities/louvor.dart';
import 'package:coldigui/features/coldigom/data/providers/coldigom_providers.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:coldigui/features/playlists/domain/entities/playlist_entry.dart';
import 'package:coldigui/features/playlists/presentation/providers/active_playlist_editor.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/coldigom_catalog_test_helpers.dart';
import '../../../support/fakes/fake_active_editor.dart';

/// Sessão de mentira: grava a fila e o índice recebidos por [playQueue] —
/// é isso que prova que «Abrir» tocou a faixa (e não só tentou navegar).
class _FakeAudioSession extends AudioPlayerSessionNotifier {
  _FakeAudioSession(this._state);

  final AudioPlayerSessionState _state;

  List<AudioTrack>? playedQueue;
  int? playedStartIndex;

  @override
  AudioPlayerSessionState build() => _state;

  int playPauseCalls = 0;

  @override
  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    playedQueue = tracks;
    playedStartIndex = startIndex;
  }

  @override
  Future<void> playPause() async => playPauseCalls++;
}

/// Resolve a rota do leitor sem baixar PDF — registra o que foi pedido.
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

void main() {
  const track = AudioTrack(
    audioId: 'aud-1',
    r2Key: 'assets/praises/p1/a.mp3',
    nome: 'Louvor',
    numero: '12',
    groupId: 'p1',
    categoria: 'Áudio',
    classificacao: 'Coro',
  );
  const audioEntry = PlaylistEntry(id: 'aud-1', kind: MaterialKind.audio);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('«Abrir» numa entrada de áudio toca a faixa e abre /audio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = _FakeAudioSession(const AudioPlayerSessionState());
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (_, _) => const Scaffold(body: CarouselChips()),
        ),
        GoRoute(
          path: RoutePaths.audio,
          builder: (_, state) =>
              Scaffold(body: Text(state.uri.queryParameters['audioId'] ?? '')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activePlaylistEditorProvider.overrideWith(
            () => FakeActiveEditor([audioEntry]),
          ),
          audioPlayerSessionProvider.overrideWith(() => session),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Cache de faixas: sem isso `catalogMaterialLookupProvider` não resolve
    // `item.materialId` ('aud-1') numa `AudioTrack` e `_openAudio` cairia no
    // caminho de erro (snackbar) em vez de tocar.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CarouselChips)),
    );
    container.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
      track,
    ]);
    await tester.pump();

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(session.playedQueue, isNotNull);
    expect(
      session.playedQueue![session.playedStartIndex ?? 0].audioId,
      track.audioId,
    );
    // Rota /audio empurrada (spec §3.2: abrir áudio navega + toca) — a rota
    // de mentira devolve o `audioId` da query, que é `track.audioId`.
    expect(find.text(track.audioId), findsOneWidget);
  });

  testWidgets(
    'no leitor, o chip de áudio do sheet «Lista» toca no player em vez de '
    'trocar a leitura',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const pdfEntry = PlaylistEntry(id: 'pdf1', kind: MaterialKind.pdf);

      final session = _FakeAudioSession(const AudioPlayerSessionState());
      // Rotas: `leitor` e `home` como irmãs simples (mesmo padrão de
      // `carousel_chips_test.dart` — 'modo leitor não oferece mais tocar
      // áudio (botão removido...)' — para pôr a barra em modo leitor sem o
      // shell inteiro), mais `audio` para conferir o push do player.
      final router = GoRouter(
        initialLocation: RoutePaths.home,
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (_, _) => const Scaffold(body: CarouselChips()),
          ),
          GoRoute(
            path: RoutePaths.reader,
            // Precisa ser o `CarouselChips` de verdade (não um placeholder):
            // é a rota que coloca a própria barra em modo leitor.
            builder: (_, _) => const Scaffold(body: CarouselChips()),
          ),
          GoRoute(
            path: RoutePaths.audio,
            builder: (_, state) => Scaffold(
              body: Text(state.uri.queryParameters['audioId'] ?? ''),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activePlaylistEditorProvider.overrideWith(
              () => FakeActiveEditor([pdfEntry, audioEntry]),
            ),
            audioPlayerSessionProvider.overrideWith(() => session),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A barra 2 do `CarouselChips` decide o modo (leitor x shell) pela
      // rota — igual ao app real, o pdf abre com `context.push`, mas aqui
      // basta simular a rota já aberta.
      router.go('${RoutePaths.reader}?pdfId=pdf1&titulo=PDF%20aberto');
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CarouselChips)),
      );
      container.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
        track,
      ]);
      await tester.pump();

      await tester.tap(find.text('Lista'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining(track.nome));
      await tester.pumpAndSettle();

      expect(session.playedQueue, isNotNull);
      expect(
        session.playedQueue![session.playedStartIndex ?? 0].audioId,
        track.audioId,
      );
      // Foi para o player (empurrou `/audio`) — não tentou trocar o PDF
      // aberto no leitor (`_replaceReaderWithCarouselItem` desvia áudio para
      // `_openAudio` antes de chegar no caminho de troca de leitura).
      expect(find.text(track.audioId), findsOneWidget);
    },
  );

  group('entrada de áudio que já é a faixa da sessão', () {
    const pdfEntry = PlaylistEntry(id: 'pdf1', kind: MaterialKind.pdf);
    final louvor = Louvor.fromManifest(
      nome: 'Louvor',
      numero: '12',
      categoria: 'Partitura',
      classificacao: 'Coro',
      pdf: 'pdf1.pdf',
      pdfId: 'pdf1',
      groupId: track.groupId,
    );

    /// Sessão já carregada com [track] — é o que o app tem depois de abrir o
    /// áudio (e o que o chip/«Abrir» da barra reencontra focado).
    _FakeAudioSession loadedSession({required bool playing}) =>
        _FakeAudioSession(
          AudioPlayerSessionState(queue: const [track], playing: playing),
        );

    Future<void> pumpBar(
      WidgetTester tester, {
      required String initialLocation,
      required _FakeAudioSession session,
      required _FakeReaderCarouselActions readerActions,
    }) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Widget screen(String label) => Scaffold(
        body: Column(children: [const CarouselChips(), Text('tela=$label')]),
      );

      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(path: RoutePaths.home, builder: (_, _) => screen('home')),
          GoRoute(path: RoutePaths.audio, builder: (_, _) => screen('audio')),
          GoRoute(
            path: RoutePaths.reader,
            builder: (_, state) => Scaffold(
              body: Text('leitor=${state.uri.queryParameters['pdfId']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            coldigomLouvoresOverride([louvor]),
            activePlaylistEditorProvider.overrideWith(
              () => FakeActiveEditor([pdfEntry, audioEntry]),
            ),
            audioPlayerSessionProvider.overrideWith(() => session),
            readerCarouselActionsProvider.overrideWith(() => readerActions),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CarouselChips)),
      );
      container.read(coldigomAudioTracksCacheProvider.notifier).mergeTracks([
        track,
      ]);
      // Abrir o áudio foca a entrada dele — é esse o chip que o usuário vê.
      final audioItem = container
          .read(carouselItemsProvider)
          .firstWhere((item) => item.isAudio);
      container
          .read(carouselFocusedIndexProvider.notifier)
          .focusKey(audioItem.key);
      await tester.pumpAndSettle();
    }

    for (final (label, tap) in [
      ('«Abrir»', (WidgetTester t) => t.tap(find.text('Abrir'))),
      ('o chip', (WidgetTester t) => t.tap(find.textContaining(track.nome))),
    ]) {
      testWidgets('em /audio, $label abre a leitura do louvor sem recarregar '
          'a faixa', (tester) async {
        final session = loadedSession(playing: true);
        final readerActions = _FakeReaderCarouselActions();
        await pumpBar(
          tester,
          initialLocation: '${RoutePaths.audio}?audioId=${track.audioId}',
          session: session,
          readerActions: readerActions,
        );

        await tap(tester);
        await tester.pumpAndSettle();

        // Recarregar a mesma faixa zerava duração/estado de play no player
        // (streams `distinct` do just_audio não reemitem o mesmo valor).
        expect(session.playedQueue, isNull);
        expect(session.playPauseCalls, 0);
        expect(readerActions.navigatedPdfIds, ['pdf1']);
        expect(find.text('leitor=pdf1'), findsOneWidget);
      });
    }

    testWidgets('fora de /audio, «Abrir» vai ao player sem reiniciar a faixa '
        'que já toca', (tester) async {
      final session = loadedSession(playing: true);
      await pumpBar(
        tester,
        initialLocation: RoutePaths.home,
        session: session,
        readerActions: _FakeReaderCarouselActions(),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(session.playedQueue, isNull);
      expect(session.playPauseCalls, 0);
      expect(find.text('tela=audio'), findsOneWidget);
    });

    testWidgets('fora de /audio, «Abrir» na faixa pausada retoma de onde '
        'parou', (tester) async {
      final session = loadedSession(playing: false);
      await pumpBar(
        tester,
        initialLocation: RoutePaths.home,
        session: session,
        readerActions: _FakeReaderCarouselActions(),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(session.playedQueue, isNull);
      expect(session.playPauseCalls, 1);
      expect(find.text('tela=audio'), findsOneWidget);
    });
  });
}
