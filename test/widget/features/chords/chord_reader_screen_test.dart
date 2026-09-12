import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/audio_player/domain/entities/audio_track.dart';
import 'package:coldigui/features/audio_player/presentation/providers/audio_player_session_provider.dart';
import 'package:coldigui/features/audio_player/presentation/widgets/mini_player_bar_metrics.dart';
import 'package:coldigui/features/carousel/domain/entities/carousel_item.dart';
import 'package:coldigui/features/carousel/presentation/providers/carousel_items_provider.dart';
import 'package:coldigui/features/carousel/presentation/widgets/active_list_panel.dart';
import 'package:coldigui/features/chords/data/providers/chord_providers.dart';
import 'package:coldigui/features/chords/domain/entities/chord_reader_font_size.dart';
import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:coldigui/features/chords/presentation/pages/chord_reader_screen.dart';
import 'package:coldigui/features/chords/presentation/providers/chord_autoscroll_provider.dart';
import 'package:coldigui/features/chords/presentation/providers/chord_reader_mode_provider.dart';
import 'package:coldigui/features/chords/presentation/theme/chord_reader_theme.dart';
import 'package:coldigui/features/chords/presentation/widgets/chordpro_view.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_side_panel_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fullscreen fixo (Important 3, onda 4) — evita depender do `SystemChrome`
/// real do [ReaderFullscreenNotifier.build].
class _FullscreenFixedNotifier extends ReaderFullscreenNotifier {
  @override
  bool build() => true;
}

/// Sessão de áudio de mentira — só `currentTrack` importa aqui.
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

const _r2Key = 'assets/praises/p1/m1.chord';
const _r2KeyB = 'assets/praises/p2/m2.chord';

const _carouselItems = <CarouselItem>[
  CarouselItem(
    materialId: 'x',
    kind: MaterialKind.pdf,
    index: 0,
    key: 'x',
    numero: '1',
    nome: 'Louvor Teste',
    categoria: 'c',
    classificacao: 'Col',
  ),
];

Future<SharedPreferences> _pump(
  WidgetTester tester, {
  required bool available,
  Map<String, String>? queryParams,
  ChordProSong? songOverride,
  List<CarouselItem>? carouselItems,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final song =
      songOverride ??
      parseChordPro(
        '{title: Comigo habita}\n{key: Eb}\n\nA [Bb]noite ha[Cm]bi\n',
      );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        chordSongProvider.overrideWith(
          (ref, key) async => available ? song : null,
        ),
        if (carouselItems != null)
          carouselItemsProvider.overrideWithValue(carouselItems),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Locale fixo: o default do flutter_test e ingles, e os asserts
        // abaixo esperam as strings em portugues.
        locale: const Locale('pt'),
        home: ChordReaderScreen(
          queryParams:
              queryParams ??
              {'pdfId': encodePdfId(_r2Key), 'titulo': 'Comigo habita'},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ChordReaderScreen)));

/// Manda uma tecla com Ctrl (ou Cmd) segurado.
Future<void> _sendWithControl(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renderiza a cifra disponivel', (tester) async {
    await _pump(tester, available: true);

    expect(find.byType(ChordProView), findsOneWidget);
    expect(find.text('Comigo habita'), findsWidgets);
    expect(find.byKey(chordBarKey(0, 1)), findsOneWidget);
  });

  testWidgets('mostra indisponivel quando nao ha arquivo', (tester) async {
    await _pump(tester, available: false);

    expect(find.byType(ChordProView), findsNothing);
    expect(find.text('Cifra ainda não disponível'), findsOneWidget);
  });

  testWidgets('toggle alterna o tema do leitor', (tester) async {
    final prefs = await _pump(tester, available: true);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChordReaderScreen)),
    );
    expect(container.read(chordReaderModeProvider), ChordReaderMode.light);

    await tester.tap(find.byTooltip('Alternar tema do leitor'));
    await tester.pumpAndSettle();

    expect(container.read(chordReaderModeProvider), ChordReaderMode.dark);
    // O requisito e a persistencia, nao o estado em memoria.
    expect(prefs.getString(StorageKeys.chordReaderMode), 'dark');
  });

  group('barra de controles', () {
    testWidgets('todos os botoes tem a mesma largura e altura', (tester) async {
      await _pump(tester, available: true);

      // Os glifos tem larguras intrinsecas diferentes (text_increase e bem
      // mais largo que add). O minimo de 44pt do estilo e o que uniformiza:
      // todo glifo cabe folgado, entao todo botao ocupa a mesma caixa.
      final tooltips = [
        'Descer meio tom',
        'Subir meio tom',
        'Diminuir letra',
        'Aumentar letra',
        'Alternar tema do leitor',
      ];

      final sizes = [
        for (final t in tooltips) tester.getSize(find.byTooltip(t)),
      ];

      for (final size in sizes) {
        expect(size.width, sizes.first.width, reason: 'largura uniforme');
        expect(size.height, sizes.first.height, reason: 'altura uniforme');
      }
      // 40x36 e o que o estilo compartilhado com a barra de carousel produz:
      // minimo de 44 menos o desconto de VisualDensity.compact, com o padding
      // padrao do IconButton em volta do glifo de 24. Fixado para pegar
      // regressao — o que importa e serem todos iguais, acima.
      expect(sizes.first.width, 40);
      expect(sizes.first.height, 36);
    });

    testWidgets('botoes do mesmo grupo ficam encostados', (tester) async {
      await _pump(tester, available: true);

      double gapBetween(String a, String b) {
        final left = tester.getRect(find.byTooltip(a));
        final right = tester.getRect(find.byTooltip(b));
        return right.left - left.right;
      }

      // Dentro do grupo de corpo da letra os botoes se tocam.
      expect(gapBetween('Diminuir letra', 'Aumentar letra'), 0);

      // No grupo de transposicao o unico espaco e o slot reservado ao rotulo,
      // identico com e sem deslocamento.
      final slotEmZero = gapBetween('Descer meio tom', 'Subir meio tom');
      expect(slotEmZero, greaterThan(0));

      await tester.tap(find.byTooltip('Subir meio tom'));
      await tester.pumpAndSettle();
      expect(gapBetween('Descer meio tom', 'Subir meio tom'), slotEmZero);
    });

    testWidgets('o botao - nao se desloca ao transpor', (tester) async {
      await _pump(tester, available: true);

      final antes = tester.getRect(find.byTooltip('Descer meio tom'));
      await tester.tap(find.byTooltip('Descer meio tom'));
      await tester.pumpAndSettle();
      final depois = tester.getRect(find.byTooltip('Descer meio tom'));

      // O rotulo do deslocamento ocupa largura fixa mesmo em zero, entao
      // surgir nao empurra o botao de baixo do dedo de quem repete o toque.
      expect(depois.left, antes.left);
      expect(find.text('-1'), findsOneWidget);
    });

    testWidgets('play/pause e velocidade do autoscroll ficam na barra', (
      tester,
    ) async {
      await _pump(tester, available: true);

      expect(find.byTooltip('Iniciar rolagem automática'), findsOneWidget);

      // Um `pump()` so, nao `pumpAndSettle()`: a musica de teste e curta
      // (sem `maxScrollExtent`), entao o motor do autoscroll pararia sozinho
      // se deixassemos varios frames do Ticker rodarem aqui.
      await tester.tap(find.byTooltip('Iniciar rolagem automática'));
      await tester.pump();

      expect(find.byTooltip('Pausar rolagem automática'), findsOneWidget);

      // Tocar no rotulo de velocidade avanca de 3 para 4.
      await tester.tap(find.text('3x'));
      await tester.pump();

      expect(find.text('4x'), findsOneWidget);
    });
  });

  group('teclado', () {
    testWidgets('= sobe meio tom', (tester) async {
      await _pump(tester, available: true);
      final container = _containerOf(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pumpAndSettle();

      expect(container.read(chordReaderTransposeProvider(_r2Key)), 1);
      // O cabecalho tem que acompanhar: o musico le o tom que vai tocar.
      expect(find.text('-1'), findsNothing);
    });

    testWidgets('+ do teclado numerico sobe meio tom', (tester) async {
      await _pump(tester, available: true);
      final container = _containerOf(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
      await tester.pumpAndSettle();

      expect(container.read(chordReaderTransposeProvider(_r2Key)), 1);
    });

    testWidgets('- desce meio tom', (tester) async {
      await _pump(tester, available: true);
      final container = _containerOf(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pumpAndSettle();

      expect(container.read(chordReaderTransposeProvider(_r2Key)), -1);
      expect(find.text('-1'), findsOneWidget);
    });

    testWidgets('- do teclado numerico desce meio tom', (tester) async {
      await _pump(tester, available: true);
      final container = _containerOf(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.numpadSubtract);
      await tester.pumpAndSettle();

      expect(container.read(chordReaderTransposeProvider(_r2Key)), -1);
    });

    testWidgets('Ctrl+= nao transpoe (fica com o zoom do navegador)', (
      tester,
    ) async {
      await _pump(tester, available: true);
      final container = _containerOf(tester);

      await _sendWithControl(tester, LogicalKeyboardKey.equal);

      expect(container.read(chordReaderTransposeProvider(_r2Key)), 0);
    });

    testWidgets('Ctrl+seta para cima aumenta o corpo da letra', (tester) async {
      await _pump(tester, available: true);
      final container = _containerOf(tester);
      final antes = container.read(chordReaderFontSizeProvider);

      await _sendWithControl(tester, LogicalKeyboardKey.arrowUp);

      expect(
        container.read(chordReaderFontSizeProvider),
        ChordReaderFontSize.increase(antes),
      );
    });

    testWidgets('Ctrl+seta para baixo diminui o corpo da letra', (
      tester,
    ) async {
      await _pump(tester, available: true);
      final container = _containerOf(tester);
      final antes = container.read(chordReaderFontSizeProvider);

      await _sendWithControl(tester, LogicalKeyboardKey.arrowDown);

      expect(
        container.read(chordReaderFontSizeProvider),
        ChordReaderFontSize.decrease(antes),
      );
    });

    testWidgets('setas sem Ctrl nao mexem no corpo nem no tom', (tester) async {
      await _pump(tester, available: true);
      final container = _containerOf(tester);
      final fonte = container.read(chordReaderFontSizeProvider);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(container.read(chordReaderFontSizeProvider), fonte);
      expect(container.read(chordReaderTransposeProvider(_r2Key)), 0);
    });

    testWidgets('Ctrl+setas laterais sem pdfId nao quebram', (tester) async {
      // Sem id de rota nao ha vizinho para resolver: a troca de louvor tem que
      // sair sem excecao (e sem GoRouter na arvore deste teste).
      await _pump(
        tester,
        available: true,
        queryParams: const {'titulo': 'Comigo habita'},
      );
      final container = _containerOf(tester);

      await _sendWithControl(tester, LogicalKeyboardKey.arrowRight);
      await _sendWithControl(tester, LogicalKeyboardKey.arrowLeft);

      expect(tester.takeException(), isNull);
      expect(container.read(chordReaderTransposeProvider('')), 0);
    });

    testWidgets('S liga e desliga o autoscroll', (tester) async {
      await _pump(tester, available: true);
      final container = _containerOf(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();

      expect(container.read(chordAutoscrollProvider).running, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();

      expect(container.read(chordAutoscrollProvider).running, isFalse);
    });

    testWidgets('[ e ] regulam a velocidade do autoscroll', (tester) async {
      await _pump(tester, available: true);
      final container = _containerOf(tester);
      expect(
        container.read(chordAutoscrollProvider).speed,
        kChordAutoscrollDefaultSpeed,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      expect(
        container.read(chordAutoscrollProvider).speed,
        kChordAutoscrollDefaultSpeed + 1,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pump();
      expect(
        container.read(chordAutoscrollProvider).speed,
        kChordAutoscrollDefaultSpeed - 1,
      );
    });
  });

  group('transposicao por louvor (C10)', () {
    testWidgets(
      'trocar de louvor nao herda o tom, mas preserva o do anterior na sessao',
      (tester) async {
        await _pump(
          tester,
          available: true,
          queryParams: {'pdfId': encodePdfId(_r2Key), 'titulo': 'Louvor A'},
        );
        final container = _containerOf(tester);

        await tester.tap(find.byTooltip('Subir meio tom'));
        await tester.pumpAndSettle();
        expect(container.read(chordReaderTransposeProvider(_r2Key)), 1);

        // Troca para outro louvor sem desmontar a tela (mesma navegacao por
        // `context.replace` que o app faz).
        await _pump(
          tester,
          available: true,
          queryParams: {'pdfId': encodePdfId(_r2KeyB), 'titulo': 'Louvor B'},
        );

        // O novo louvor comeca do tom original.
        expect(container.read(chordReaderTransposeProvider(_r2KeyB)), 0);
        // O louvor anterior continua com o tom escolhido, na mesma sessao.
        expect(container.read(chordReaderTransposeProvider(_r2Key)), 1);
      },
    );
  });

  group('colunas em tela larga (C9)', () {
    final longSong = parseChordPro(
      List.generate(40, (i) => 'linha $i\n').join(),
    );

    testWidgets('largura ampla com muitas linhas usa duas colunas', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pump(tester, available: true, songOverride: longSong);

      final view = tester.widget<ChordProView>(find.byType(ChordProView));
      expect(view.columns, 2);
    });

    testWidgets('largura estreita usa uma coluna mesmo com muitas linhas', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pump(tester, available: true, songOverride: longSong);

      final view = tester.widget<ChordProView>(find.byType(ChordProView));
      expect(view.columns, 1);
    });
  });

  group('autoscroll em execucao (C9)', () {
    // Musica longa o bastante para ter maxScrollExtent > 0 numa viewport de
    // teste — sem isso o motor pararia sozinho no primeiro tick (nada para
    // rolar) e nenhum dos cenarios abaixo teria como acontecer.
    final longSong = parseChordPro(
      List.generate(80, (i) => 'linha $i\n').join(),
    );

    Future<void> pumpNarrowLongSong(
      WidgetTester tester, {
      Map<String, String>? queryParams,
    }) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        available: true,
        songOverride: longSong,
        queryParams: queryParams,
      );
    }

    double scrollOffset(WidgetTester tester) => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    testWidgets('avanca o scroll com o tempo', (tester) async {
      await pumpNarrowLongSong(tester);
      final container = _containerOf(tester);

      container.read(chordAutoscrollProvider.notifier).toggle();
      await tester.pump();
      // O primeiro tick do Ticker so marca o relogio (dt ainda desconhecido);
      // o(s) seguinte(s) e que de fato avancam o scroll.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 500));

      expect(scrollOffset(tester), greaterThan(0));

      // Nao deixar o autoscroll vazar ligado para o proximo teste.
      container.read(chordAutoscrollProvider.notifier).stop();
      await tester.pump();
    });

    testWidgets('para ao chegar no fim da rolagem', (tester) async {
      await pumpNarrowLongSong(tester);
      final container = _containerOf(tester);

      container.read(chordAutoscrollProvider.notifier).setSpeed(5);
      container.read(chordAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // Salto bem maior que qualquer maxScrollExtent possivel aqui — garante
      // que o motor ultrapassa o fim e para sozinho (medido: ~2312px para 80
      // linhas; 5 minutos a velocidade 5 (300 px/s) dao ~90000px de folga).
      await tester.pump(const Duration(minutes: 5));

      expect(container.read(chordAutoscrollProvider).running, isFalse);
    });

    testWidgets('para ao trocar de louvor', (tester) async {
      await pumpNarrowLongSong(
        tester,
        queryParams: {'pdfId': encodePdfId(_r2Key), 'titulo': 'Louvor A'},
      );
      final container = _containerOf(tester);

      container.read(chordAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // Avanco curto: a musica e longa o bastante para nao chegar no fim.
      await tester.pump(const Duration(milliseconds: 200));
      expect(container.read(chordAutoscrollProvider).running, isTrue);

      // Troca de louvor sem desmontar a tela — mesmo padrao da C10.
      await pumpNarrowLongSong(
        tester,
        queryParams: {'pdfId': encodePdfId(_r2KeyB), 'titulo': 'Louvor B'},
      );

      expect(container.read(chordAutoscrollProvider).running, isFalse);
    });

    testWidgets('rolagem manual do usuario para o autoscroll', (tester) async {
      await pumpNarrowLongSong(tester);
      final container = _containerOf(tester);

      container.read(chordAutoscrollProvider.notifier).toggle();
      await tester.pump();
      expect(container.read(chordAutoscrollProvider).running, isTrue);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pump();

      expect(container.read(chordAutoscrollProvider).running, isFalse);
    });
  });

  group('split view (C7)', () {
    testWidgets('tela larga mostra o painel com a lista ativa', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pump(tester, available: true, carouselItems: _carouselItems);

      expect(find.byType(ActiveListPanel), findsOneWidget);
      expect(find.textContaining('Louvor Teste'), findsOneWidget);
    });

    testWidgets('tela estreita esconde o painel', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pump(tester, available: true, carouselItems: _carouselItems);

      expect(find.byType(ActiveListPanel), findsNothing);
    });

    testWidgets('botão do painel alterna readerSidePanelOpenProvider', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pump(tester, available: true, carouselItems: _carouselItems);
      expect(find.byType(ActiveListPanel), findsOneWidget);

      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      await tester.tap(find.byTooltip(l10n.readerSidePanelHideTooltip));
      await tester.pumpAndSettle();

      final container = _containerOf(tester);
      expect(container.read(readerSidePanelOpenProvider), isFalse);
      expect(find.byType(ActiveListPanel), findsNothing);
      expect(find.byTooltip(l10n.readerSidePanelShowTooltip), findsOneWidget);
    });
  });

  group('respiro do mini-player em fullscreen (Important 3)', () {
    double lastPaddingBottom(WidgetTester tester) {
      final slivers = tester.widgetList<SliverPadding>(
        find.byType(SliverPadding),
      );
      final padding = slivers.last.padding as EdgeInsets;
      return padding.bottom;
    }

    testWidgets('fora do fullscreen usa o respiro padrão (24)', (tester) async {
      await _pump(tester, available: true);

      expect(lastPaddingBottom(tester), 24);
    });

    testWidgets('fullscreen sem faixa tocando mantém o respiro padrão (24)', (
      tester,
    ) async {
      await _pump(
        tester,
        available: true,
        overrides: [
          readerFullscreenProvider.overrideWith(_FullscreenFixedNotifier.new),
        ],
      );

      expect(lastPaddingBottom(tester), 24);
    });

    testWidgets('fullscreen com faixa tocando soma a altura do mini-player', (
      tester,
    ) async {
      await _pump(
        tester,
        available: true,
        overrides: [
          readerFullscreenProvider.overrideWith(_FullscreenFixedNotifier.new),
          audioPlayerSessionProvider.overrideWith(
            () => _FakeAudioSession(
              const AudioPlayerSessionState(queue: [_playingTrack]),
            ),
          ),
        ],
      );

      expect(lastPaddingBottom(tester), 24 + kMiniPlayerBarHeight);
    });
  });
}
