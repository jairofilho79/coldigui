import 'dart:async';

import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/routing/route_paths.dart';
import 'package:coldigui/features/app_shell/presentation/widgets/app_shortcuts.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_focused_index_provider.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/pdf_reader/domain/entities/carousel_reader_position.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_carousel_actions_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Alvo de foco neutro: sem ele o evento de tecla não tem por onde subir até
/// os atalhos globais.
const _stage = Focus(autofocus: true, child: SizedBox.expand());

/// Página do Navigator aninhado — dá o contexto de onde o sheet é aberto.
const _innerNavigatorPageKey = Key('inner-navigator-page');

const _track = AudioTrack(
  audioId: 'a1',
  r2Key: 'assets/praises/p1/m1.mp3',
  nome: 'Comigo habita',
  numero: '1',
  groupId: 'g1',
  categoria: 'Áudio',
  classificacao: '',
);

/// Sessão de áudio de mentira: conta os `playPause` sem instanciar o
/// `AudioPlayer` real (que a sessão de verdade cria no `build`).
class _FakeAudioSession extends AudioPlayerSessionNotifier {
  _FakeAudioSession({this.hasTrack = true});

  final bool hasTrack;
  int playPauseCalls = 0;

  @override
  AudioPlayerSessionState build() =>
      AudioPlayerSessionState(queue: hasTrack ? const [_track] : const []);

  @override
  Future<void> playPause() async => playPauseCalls++;
}

Future<ProviderContainer> _pumpShortcuts(
  WidgetTester tester, {
  required String path,
  Widget child = _stage,
  List<Override> overrides = const [],
}) async {
  final router = GoRouter(
    initialLocation: path,
    routes: [
      for (final route in {path, RoutePaths.home})
        GoRoute(
          path: route,
          builder: (_, _) => Scaffold(
            body: AppShortcuts(path: route, child: child),
          ),
        ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(tester.element(find.byType(AppShortcuts)));
}

void main() {
  testWidgets('F no leitor liga a tela cheia', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.reader);
    expect(container.read(readerFullscreenProvider), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();

    expect(container.read(readerFullscreenProvider), isTrue);
  });

  testWidgets('F no leitor de cifras também liga a tela cheia', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.chords);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();

    expect(container.read(readerFullscreenProvider), isTrue);
  });

  testWidgets('F fora do leitor não mexe na tela cheia', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.home);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();

    expect(container.read(readerFullscreenProvider), isFalse);
  });

  testWidgets('Esc sai da tela cheia', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.reader);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(container.read(readerFullscreenProvider), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(container.read(readerFullscreenProvider), isFalse);
  });

  testWidgets('Esc não rouba o fechamento de um modal aberto (B10)', (
    tester,
  ) async {
    final container = await _pumpShortcuts(
      tester,
      path: RoutePaths.reader,
      child: Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Focus(
            autofocus: true,
            child: SizedBox.expand(key: _innerNavigatorPageKey),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(container.read(readerFullscreenProvider), isTrue);

    // O sheet sobe no Navigator aninhado do shell (o padrão do app: nenhum
    // `showModalBottomSheet` pede `useRootNavigator`), ou seja **dentro** da
    // subárvore do AppShortcuts — é por isso que a tecla chega até aqui.
    final innerContext = tester.element(find.byKey(_innerNavigatorPageKey));
    unawaited(
      showModalBottomSheet<void>(
        context: innerContext,
        builder: (_) => const SizedBox(height: 120),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
      container.read(readerFullscreenProvider),
      isTrue,
      reason: 'o Esc é do modal em cima, não da tela cheia embaixo',
    );
  });

  testWidgets('/ pede foco na busca', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.home);
    final before = container.read(searchFocusRequestProvider);

    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pumpAndSettle();

    expect(container.read(searchFocusRequestProvider), before + 1);
  });

  testWidgets('Ctrl+K pede foco na busca a partir do leitor', (tester) async {
    final container = await _pumpShortcuts(tester, path: RoutePaths.reader);
    final before = container.read(searchFocusRequestProvider);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(container.read(searchFocusRequestProvider), before + 1);
  });

  testWidgets('tecla seca não dispara com o foco num campo de texto', (
    tester,
  ) async {
    final container = await _pumpShortcuts(
      tester,
      path: RoutePaths.reader,
      child: const TextField(autofocus: true),
    );

    // `/` e `F` são caracteres válidos numa busca — o atalho tem que calar.
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();

    expect(container.read(searchFocusRequestProvider), 0);
    expect(container.read(readerFullscreenProvider), isFalse);
  });

  group('Espaço', () {
    testWidgets('sem controle focado dá play/pause', (tester) async {
      final session = _FakeAudioSession();
      await _pumpShortcuts(
        tester,
        path: RoutePaths.home,
        overrides: [audioPlayerSessionProvider.overrideWith(() => session)],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(session.playPauseCalls, 1);
    });

    testWidgets('sem faixa na sessão não chama o player', (tester) async {
      final session = _FakeAudioSession(hasTrack: false);
      await _pumpShortcuts(
        tester,
        path: RoutePaths.home,
        overrides: [audioPlayerSessionProvider.overrideWith(() => session)],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(session.playPauseCalls, 0);
    });

    testWidgets('com botão focado aciona o botão, não o play/pause', (
      tester,
    ) async {
      final session = _FakeAudioSession();
      var pressed = 0;
      await _pumpShortcuts(
        tester,
        path: RoutePaths.home,
        overrides: [audioPlayerSessionProvider.overrideWith(() => session)],
        child: Center(
          child: ElevatedButton(
            autofocus: true,
            onPressed: () => pressed++,
            child: const Text('Abrir'),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      // Espaço é a tecla de "ativar" do Flutter: com foco num botão ela é do
      // botão, não do player.
      expect(pressed, 1, reason: 'o botão focado tem que ser acionado');
      expect(session.playPauseCalls, 0, reason: 'play/pause não pode roubar');
    });

    testWidgets('com InkWell focado aciona o InkWell, não o play/pause', (
      tester,
    ) async {
      final session = _FakeAudioSession();
      var tapped = 0;
      await _pumpShortcuts(
        tester,
        path: RoutePaths.home,
        overrides: [audioPlayerSessionProvider.overrideWith(() => session)],
        child: Center(
          child: Material(
            child: InkWell(
              autofocus: true,
              onTap: () => tapped++,
              child: const SizedBox(width: 80, height: 40),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(tapped, 1);
      expect(session.playPauseCalls, 0);
    });

    testWidgets('com o foco dentro de uma lista rolável não dá play/pause', (
      tester,
    ) async {
      final session = _FakeAudioSession();
      await _pumpShortcuts(
        tester,
        path: RoutePaths.home,
        overrides: [audioPlayerSessionProvider.overrideWith(() => session)],
        child: ListView(
          children: [
            const Focus(autofocus: true, child: SizedBox(height: 60)),
            for (var i = 0; i < 40; i++)
              SizedBox(height: 60, child: Text('$i')),
          ],
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      // Espaço é o page-down natural de quem está lendo uma lista longa.
      expect(session.playPauseCalls, 0);
    });

    testWidgets('num campo de texto continua inerte', (tester) async {
      final session = _FakeAudioSession();
      await _pumpShortcuts(
        tester,
        path: RoutePaths.home,
        overrides: [audioPlayerSessionProvider.overrideWith(() => session)],
        child: const TextField(autofocus: true),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(session.playPauseCalls, 0);
    });
  });

  group('navigateReaderCarouselByKeyboard — N/P por chave', () {
    CarouselItem item(String materialId, int index, {String? key}) {
      return CarouselItem(
        materialId: materialId,
        kind: MaterialKind.pdf,
        index: index,
        key: key ?? materialId,
        numero: '1',
        nome: 'Louvor',
        categoria: 'Partitura',
        classificacao: 'Col',
      );
    }

    /// Face com o mesmo louvor repetido: `a`, `b`, `a#1`.
    Future<(WidgetRef, _RecordingReaderActions)> pump(
      WidgetTester tester,
      String focusedKey,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final actions = _RecordingReaderActions();
      late WidgetRef captured;

      final router = GoRouter(
        initialLocation: RoutePaths.reader,
        routes: [
          GoRoute(
            path: RoutePaths.reader,
            builder: (_, _) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  captured = ref;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            carouselItemsProvider.overrideWithValue([
              item('a', 0),
              item('b', 1),
              item('a', 2, key: 'a#1'),
            ]),
            readerCarouselActionsProvider.overrideWith(() => actions),
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

      captured.read(carouselFocusedIndexProvider.notifier).focusKey(focusedKey);
      await tester.pumpAndSettle();
      return (captured, actions);
    }

    testWidgets('P sai da segunda ocorrência para o vizinho de verdade', (
      tester,
    ) async {
      final (ref, actions) = await pump(tester, 'a#1');

      final moved = await navigateReaderCarouselByKeyboard(
        ref: ref,
        context: tester.element(find.byType(SizedBox)),
        currentPdfId: 'a',
        direction: CarouselReaderDirection.previous,
      );
      await tester.pumpAndSettle();

      expect(moved, isTrue);
      expect(actions.navigated, ['b']);
      expect(ref.read(carouselFocusedKeyProvider), 'b');
    });

    testWidgets('N na última ocorrência não tem para onde ir', (tester) async {
      final (ref, actions) = await pump(tester, 'a#1');

      final moved = await navigateReaderCarouselByKeyboard(
        ref: ref,
        context: tester.element(find.byType(SizedBox)),
        currentPdfId: 'a',
        direction: CarouselReaderDirection.next,
      );
      await tester.pumpAndSettle();

      expect(moved, isFalse);
      expect(actions.navigated, isEmpty);
      expect(ref.read(carouselFocusedKeyProvider), 'a#1');
    });
  });
}

/// Ações do leitor sem resolve real — grava o `materialId` pedido.
class _RecordingReaderActions extends ReaderCarouselActionsNotifier {
  final navigated = <String>[];

  @override
  void build() {}

  @override
  Future<String?> navigateToPdfId({required String targetPdfId}) async {
    navigated.add(targetPdfId);
    return '${RoutePaths.reader}?pdfId=$targetPdfId';
  }
}
