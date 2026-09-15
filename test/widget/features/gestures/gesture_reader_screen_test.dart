import 'dart:io';

import 'package:coldigui/core/constants/storage_keys.dart';
import 'package:coldigui/core/providers/shared_prefs_provider.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/gestures/data/datasources/gesture_content_datasource.dart';

import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/data/repositories/gesture_figure_repository.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/pages/gesture_reader_screen.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_autoscroll_provider.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_font_size_provider.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_linear_provider.dart';
import 'package:coldigui/features/gestures/presentation/providers/gesture_reader_mode_provider.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_theme.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_card_tile.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_document_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_figure.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_focus_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/instruction_card_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/newer_schema_banner.dart';
import 'package:coldigui/features/gestures/presentation/widgets/section_label_view.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/gesture_test_png.dart';

const _r2Key = 'assets/praises/p1/m1.gestures';

String _read(String name) =>
    File('test/fixtures/gestures/$name').readAsStringSync();

GestureDocument _fixture(String name) => parseGestureDocument(_read(name));

/// O prefetch da tela não pode ir à rede no teste.
class _NoopFigureRepository implements GestureFigureRepository {
  @override
  Future<Uint8List?> get(String r2Key) async => null;

  @override
  Future<void> prefetch(Iterable<String> r2Keys) async {}
}

/// Conta quantas vezes o prefetch rodou — pin do reset em troca de louvor.
class _CountingFigureRepository implements GestureFigureRepository {
  var prefetchCalls = 0;

  @override
  Future<Uint8List?> get(String r2Key) async => null;

  @override
  Future<void> prefetch(Iterable<String> r2Keys) async {
    prefetchCalls++;
  }
}

/// [document] `null` = 404; `Future.error` = falha de rede.
Future<SharedPreferences> _pump(
  WidgetTester tester, {
  required Future<GestureDocument?> Function() document,
  Map<String, String>? queryParams,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final prefs0 = await SharedPreferences.getInstance();
  final dict = parseGestureDictionary(_read('dictionary.json'));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs0),
        gestureDocumentProvider.overrideWith((ref, key) => document()),
        gestureDictionaryProvider.overrideWith((ref) async => dict),
        gestureFigureProvider.overrideWith((ref, k) async => gestureTestPng()),
        gestureFigureRepositoryProvider.overrideWithValue(
          _NoopFigureRepository(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: GestureReaderScreen(
          queryParams:
              queryParams ??
              {'pdfId': encodePdfId(_r2Key), 'titulo': 'Quero viver'},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return prefs0;
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GestureReaderScreen)));

Future<void> _sendWithControl(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  testWidgets('renderiza o documento e publica os params da rota', (
    tester,
  ) async {
    await _pump(
      tester,
      document: () async => parseGestureDocument(_read('182_quero_viver.json')),
    );

    expect(find.byType(GestureDocumentView), findsOneWidget);
    expect(find.text('182 - QUERO VIVER PRA SEMPRE COM JESUS'), findsOneWidget);
    expect(find.byType(GestureCardTile), findsWidgets);
    expect(
      _containerOf(tester).read(readerRouteParamsProvider)['pdfId'],
      encodePdfId(_r2Key),
    );
  });

  testWidgets('404 mostra "ainda não tem gestos"', (tester) async {
    await _pump(tester, document: () async => null);
    expect(find.text('Este louvor ainda não tem gestos'), findsOneWidget);
    expect(find.byType(GestureDocumentView), findsNothing);
  });

  testWidgets('falha de rede mostra indisponível com retry que reinvalida', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      document: () {
        calls++;
        return calls == 1
            ? Future.error(const GestureFetchFailedException(_r2Key, 'rede'))
            : Future.value(parseGestureDocument(_read('182_quero_viver.json')));
      },
    );
    expect(find.text('Gestos indisponíveis · tentar de novo'), findsOneWidget);

    await tester.tap(find.byKey(gestureReaderRetryKey));
    await tester.pump();
    await tester.pump();
    expect(find.byType(GestureDocumentView), findsOneWidget);
  });

  testWidgets('retry também reinvalida o dicionário sem sinal', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final dict = parseGestureDictionary(_read('dictionary.json'));
    var dictCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          gestureDocumentProvider.overrideWith(
            (ref, key) async =>
                throw const GestureFetchFailedException(_r2Key, 'rede'),
          ),
          gestureDictionaryProvider.overrideWith((ref) async {
            dictCalls++;
            return dict;
          }),
          gestureFigureProvider.overrideWith(
            (ref, k) async => gestureTestPng(),
          ),
          gestureFigureRepositoryProvider.overrideWithValue(
            _NoopFigureRepository(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pt'),
          home: GestureReaderScreen(
            queryParams: {
              'pdfId': encodePdfId(_r2Key),
              'titulo': 'Quero viver',
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Gestos indisponíveis · tentar de novo'), findsOneWidget);
    final callsBeforeRetry = dictCalls;

    await tester.tap(find.byKey(gestureReaderRetryKey));
    await tester.pump();
    await tester.pump();

    expect(
      dictCalls,
      greaterThan(callsBeforeRetry),
      reason: 'o retry manual também dá outra chance ao dicionário sem sinal',
    );
  });

  testWidgets('schema v2 mostra o banner acima do papel', (tester) async {
    await _pump(
      tester,
      document: () async => parseGestureDocument(_read('schema_v2.json')),
    );
    expect(find.byType(NewerSchemaBanner), findsOneWidget);
    expect(find.byType(GestureDocumentView), findsOneWidget);
  });

  testWidgets('A+/A- mudam a fonte e persistem; Ctrl+↑/↓ também', (
    tester,
  ) async {
    final prefs = await _pump(
      tester,
      document: () async => parseGestureDocument(_read('182_quero_viver.json')),
    );
    final container = _containerOf(tester);
    expect(container.read(gestureReaderFontSizeProvider), 18);

    await tester.tap(find.byTooltip('Aumentar letra dos gestos'));
    await tester.pump();
    expect(container.read(gestureReaderFontSizeProvider), 20);
    expect(prefs.getDouble(StorageKeys.gestureReaderFontSize), 20);
    expect(
      tester.getSize(find.byType(GestureFigure).first).width,
      closeTo(96 * 20 / 18, 0.1),
    );

    await _sendWithControl(tester, LogicalKeyboardKey.arrowDown);
    await _sendWithControl(tester, LogicalKeyboardKey.arrowDown);
    expect(container.read(gestureReaderFontSizeProvider), 16);

    await tester.tap(find.byTooltip('Diminuir letra dos gestos'));
    await tester.pump();
    expect(container.read(gestureReaderFontSizeProvider), 14);
    // `find.byTooltip` casa com o `RawTooltip` interno, não com o `IconButton`
    // que o envolve — busca pelo predicado para pegar o widget certo.
    final decreaseButton = find.byWidgetPredicate(
      (widget) =>
          widget is IconButton && widget.tooltip == 'Diminuir letra dos gestos',
    );
    expect(tester.widget<IconButton>(decreaseButton).onPressed, isNull);
  });

  testWidgets(
    'troca de louvor via replace republica os params e refaz o prefetch',
    (tester) async {
      // Espelha o `context.replace()` do carousel: mesma key de página, só o
      // widget muda — o go_router não recria o State, chama `didUpdateWidget`.
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final dict = parseGestureDictionary(_read('dictionary.json'));
      final figureRepo = _CountingFigureRepository();

      final overrides = [
        sharedPreferencesProvider.overrideWithValue(prefs),
        gestureDocumentProvider.overrideWith(
          (ref, key) async =>
              parseGestureDocument(_read('182_quero_viver.json')),
        ),
        gestureDictionaryProvider.overrideWith((ref) async => dict),
        gestureFigureProvider.overrideWith((ref, k) async => gestureTestPng()),
        gestureFigureRepositoryProvider.overrideWithValue(figureRepo),
      ];

      const firstKey = 'assets/praises/p1/m1.gestures';
      const secondKey = 'assets/praises/p1/m2.gestures';

      Widget buildApp(Map<String, String> queryParams) {
        return ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: GestureReaderScreen(queryParams: queryParams),
          ),
        );
      }

      await tester.pumpWidget(
        buildApp({'pdfId': encodePdfId(firstKey), 'titulo': 'Quero viver'}),
      );
      await tester.pump();
      await tester.pump();

      expect(
        _containerOf(tester).read(readerRouteParamsProvider)['pdfId'],
        encodePdfId(firstKey),
      );
      expect(figureRepo.prefetchCalls, 1);

      // Mesma árvore de overrides/ProviderScope — só o `queryParams` do
      // GestureReaderScreen muda, exatamente como o `replace` do carousel.
      await tester.pumpWidget(
        buildApp({'pdfId': encodePdfId(secondKey), 'titulo': 'Outro louvor'}),
      );
      await tester.pump();
      await tester.pump();

      expect(
        _containerOf(tester).read(readerRouteParamsProvider)['pdfId'],
        encodePdfId(secondKey),
      );
      expect(figureRepo.prefetchCalls, 2);
    },
  );

  testWidgets('pdfId inválido não quebra: mostra "ainda não tem gestos"', (
    tester,
  ) async {
    await _pump(
      tester,
      document: () async => null,
      queryParams: {'pdfId': '###'},
    );
    expect(find.text('Este louvor ainda não tem gestos'), findsOneWidget);
  });

  testWidgets(
    'toque num cartão abre o foco; fechar rola a página até o cartão',
    (tester) async {
      await _pump(
        tester,
        document: () async =>
            parseGestureDocument(_read('182_quero_viver.json')),
      );
      await tester.tap(find.byKey(gestureCardKey(2)));
      await tester.pumpAndSettle();
      expect(find.byType(GestureFocusView), findsOneWidget);
      expect(find.byKey(gestureFocusPageKey(2)), findsOneWidget);

      for (var i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(GestureFocusView), findsNothing);
      expect(find.byKey(gestureCardKey(12)), findsOneWidget);
      // A `Column` do documento constrói todos os cartões de uma vez, então
      // "existe" sozinho não prova que a rolagem aconteceu — confere que o
      // cartão devolvido pelo foco está de fato visível na viewport.
      final cardRect = tester.getRect(find.byKey(gestureCardKey(12)));
      final viewportHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(cardRect.top, inInclusiveRange(0.0, viewportHeight));
    },
  );

  testWidgets('tema: começa claro; o botão troca o papel e persiste', (
    tester,
  ) async {
    final prefs = await _pump(
      tester,
      document: () async => _fixture('182_quero_viver.json'),
    );
    final container = _containerOf(tester);
    Color paper() => tester
        .widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(GestureDocumentView),
                matching: find.byType(ColoredBox),
              )
              .first,
        )
        .color;

    expect(paper(), GestureReaderMode.light.palette.paper);
    await tester.tap(find.byKey(gestureReaderThemeKey));
    await tester.pump();
    expect(container.read(gestureReaderModeProvider), GestureReaderMode.dark);
    expect(paper(), GestureReaderMode.dark.palette.paper);
    expect(prefs.getString(StorageKeys.gestureReaderMode), 'dark');
  });

  testWidgets(
    'linear por padrão: 182 mostra o coro 3 vezes e nenhuma instrução',
    (tester) async {
      await _pump(
        tester,
        document: () async => _fixture('182_quero_viver.json'),
      );
      expect(find.byType(SectionLabelView), findsNWidgets(3));
      expect(find.byType(InstructionCardView), findsNothing);
      expect(find.byType(GestureCardTile), findsNWidgets(24));
    },
  );

  testWidgets(
    'estruturado: botão desliga o linear, some o rótulo e volta a instrução',
    (tester) async {
      final prefs = await _pump(
        tester,
        document: () async => _fixture('182_quero_viver.json'),
      );
      await tester.tap(find.byKey(gestureReaderLinearKey));
      await tester.pumpAndSettle();
      expect(_containerOf(tester).read(gestureReaderLinearProvider), isFalse);
      expect(prefs.getBool(StorageKeys.gestureReaderLinear), isFalse);
      expect(find.byType(SectionLabelView), findsNothing);
      expect(find.byType(InstructionCardView), findsNWidgets(2));
      expect(find.byType(GestureCardTile), findsNWidgets(14));
    },
  );

  testWidgets('foco em linear abre no cartão expandido (índice 20 existe)', (
    tester,
  ) async {
    await _pump(tester, document: () async => _fixture('182_quero_viver.json'));
    await tester.scrollUntilVisible(find.byKey(gestureCardKey(20)), 200);
    await tester.tap(find.byKey(gestureCardKey(20)));
    await tester.pumpAndSettle();
    expect(find.byKey(gestureFocusPageKey(20)), findsOneWidget);
    await tester.tap(find.byKey(gestureFocusCloseKey));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'barra: play alterna o provider; velocidade cicla 3→4→5→1 e persiste',
    (tester) async {
      final prefs = await _pump(
        tester,
        document: () async => _fixture('182_quero_viver.json'),
      );
      final container = _containerOf(tester);
      expect(find.byTooltip('Iniciar rolagem automática'), findsOneWidget);
      await tester.tap(find.byKey(gestureReaderAutoscrollKey));
      await tester.pump();
      expect(container.read(gestureAutoscrollProvider).running, isTrue);
      expect(find.byTooltip('Pausar rolagem automática'), findsOneWidget);
      await tester.tap(find.byKey(gestureReaderAutoscrollKey));
      await tester.pump();
      expect(container.read(gestureAutoscrollProvider).running, isFalse);

      expect(find.text('3x'), findsOneWidget);
      await tester.tap(find.byKey(gestureReaderSpeedKey));
      await tester.pump();
      expect(find.text('4x'), findsOneWidget);
      // Um `pump` entre os dois toques: o botão fecha sobre o campo `autoscroll`
      // do build anterior, então sem rebuild os dois toques leriam a mesma
      // velocidade — como no `_ChordReaderToolbar` que este widget espelha.
      await tester.tap(find.byKey(gestureReaderSpeedKey));
      await tester.pump();
      await tester.tap(find.byKey(gestureReaderSpeedKey));
      await tester.pump();
      expect(find.text('1x'), findsOneWidget);
      expect(prefs.getInt(StorageKeys.gestureAutoscrollSpeed), 1);
    },
  );

  group('autoscroll em execução', () {
    Future<void> pumpShort(
      WidgetTester tester, {
      Map<String, String>? queryParams,
    }) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        document: () async => _fixture('182_quero_viver.json'),
        queryParams: queryParams,
      );
    }

    double offset(WidgetTester tester) => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    Future<void> stopAndSettle(WidgetTester tester) async {
      _containerOf(tester).read(gestureAutoscrollProvider.notifier).stop();
      await tester.pump();
    }

    testWidgets('avança com o tempo a 10 px/s por nível', (tester) async {
      await pumpShort(tester);
      final container = _containerOf(tester);
      container.read(gestureAutoscrollProvider.notifier).setSpeed(2);
      container.read(gestureAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 16),
      ); // 1º tick só marca o relógio
      await tester.pump(const Duration(seconds: 1));
      expect(offset(tester), closeTo(20, 2));
      await stopAndSettle(tester);
    });

    testWidgets('para ao chegar no fim', (tester) async {
      await pumpShort(tester);
      final container = _containerOf(tester);
      container.read(gestureAutoscrollProvider.notifier).setSpeed(5);
      container.read(gestureAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(minutes: 5));
      expect(container.read(gestureAutoscrollProvider).running, isFalse);
    });

    testWidgets(
      'rolagem manual pausa; 1 s depois do fim do gesto retoma da posição nova',
      (tester) async {
        await pumpShort(tester);
        final container = _containerOf(tester);
        container.read(gestureAutoscrollProvider.notifier).toggle();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 500));
        final before = offset(tester);
        expect(before, greaterThan(0));

        await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
        await tester.pump();
        final afterDrag = offset(tester);
        expect(afterDrag, greaterThan(before + 100));
        // Continua "ligado" — o botão não volta a play.
        expect(container.read(gestureAutoscrollProvider).running, isTrue);

        // Dentro do 1 s: parado onde o dedo deixou.
        await tester.pump(const Duration(milliseconds: 500));
        expect(offset(tester), afterDrag);

        // Passado o 1 s: volta a andar, a partir dali.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 500));
        expect(offset(tester), greaterThan(afterDrag));
        // Um tick de ~600 ms + um de 500 ms a 30 px/s ≈ 33 px: partiu dali,
        // não de onde "estaria" sem a pausa.
        expect(offset(tester), lessThan(afterDrag + 60));
        await stopAndSettle(tester);
      },
    );

    testWidgets('novo gesto antes de 1 s rearma a espera', (tester) async {
      await pumpShort(tester);
      final container = _containerOf(tester);
      container.read(gestureAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pump();
      final afterSecond = offset(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(offset(tester), afterSecond); // 700 ms < 1 s desde o 2º gesto
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(offset(tester), greaterThan(afterSecond));
      await stopAndSettle(tester);
    });

    testWidgets('abrir o foco para o autoscroll', (tester) async {
      await pumpShort(tester);
      final container = _containerOf(tester);
      container.read(gestureAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(container.read(gestureAutoscrollProvider).running, isTrue);

      await tester.tap(find.byKey(gestureCardKey(2)));
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 200),
      ); // 150 ms da transição do overlay
      final offsetAtOpen = offset(tester);
      expect(find.byType(GestureFocusView), findsOneWidget);
      expect(container.read(gestureAutoscrollProvider).running, isFalse);

      // A página escondida atrás do foco não pode se mexer — se o motor
      // ainda estivesse rolando, esta espera pegaria o `jumpTo` no ato.
      await tester.pump(const Duration(milliseconds: 500));
      expect(offset(tester), offsetAtOpen);

      await tester.tap(find.byKey(gestureFocusCloseKey));
      await tester.pumpAndSettle();
    });

    testWidgets('trocar de louvor para o autoscroll', (tester) async {
      // Como no teste de prefetch: `_pump` remonta o `ProviderScope` a cada
      // chamada, e o `autoDispose` zeraria o `running` sozinho — o que
      // provaria pouco. Aqui só o `GestureReaderScreen` é remontado, dentro
      // do mesmo `ProviderScope`, espelhando o `context.replace()` do
      // carousel.
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final dict = parseGestureDictionary(_read('dictionary.json'));

      final overrides = [
        sharedPreferencesProvider.overrideWithValue(prefs),
        gestureDocumentProvider.overrideWith(
          (ref, key) async => _fixture('182_quero_viver.json'),
        ),
        gestureDictionaryProvider.overrideWith((ref) async => dict),
        gestureFigureProvider.overrideWith((ref, k) async => gestureTestPng()),
        gestureFigureRepositoryProvider.overrideWithValue(
          _NoopFigureRepository(),
        ),
      ];

      Widget buildApp(Map<String, String> queryParams) {
        return ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('pt'),
            home: GestureReaderScreen(queryParams: queryParams),
          ),
        );
      }

      await tester.pumpWidget(
        buildApp({'pdfId': encodePdfId(_r2Key), 'titulo': 'A'}),
      );
      await tester.pump();
      await tester.pump();

      final container = _containerOf(tester);
      container.read(gestureAutoscrollProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 200));
      expect(container.read(gestureAutoscrollProvider).running, isTrue);

      await tester.pumpWidget(
        buildApp({
          'pdfId': encodePdfId('assets/praises/p1/m2.gestures'),
          'titulo': 'B',
        }),
      );
      await tester.pump();
      await tester.pump();
      expect(container.read(gestureAutoscrollProvider).running, isFalse);
    });

    testWidgets('S liga/desliga; [ e ] regulam a velocidade', (tester) async {
      await pumpShort(tester);
      final container = _containerOf(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(container.read(gestureAutoscrollProvider).running, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();
      expect(container.read(gestureAutoscrollProvider).running, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
      await tester.pump();
      expect(container.read(gestureAutoscrollProvider).speed, 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.pump();
      expect(container.read(gestureAutoscrollProvider).speed, 2);
    });
  });
}
