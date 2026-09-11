import 'dart:io';

import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/flat_gesture_card.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/domain/utils/flatten_gesture_cards.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_figure.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_focus_view.dart';
import 'package:coldigui/features/pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/gesture_test_png.dart';

String _read(String name) => File('test/fixtures/gestures/$name').readAsStringSync();

Future<Future<int?>> _open(WidgetTester tester, String fixture, int initialIndex) async {
  final cards = flattenGestureCards(parseGestureDocument(_read(fixture)));
  final dict = parseGestureDictionary(_read('dictionary.json'));
  late Future<int?> result;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gestureFigureProvider.overrideWith((ref, k) async => gestureTestPng())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  result = showGestureFocus(context, cards: cards, dictionary: dict, initialIndex: initialIndex, fontSize: 18);
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return result;
}

/// Como [_open], mas com uma lista de cartões montada à mão (sem fixture).
Future<Future<int?>> _openCards(WidgetTester tester, List<FlatGestureCard> cards, int initialIndex) async {
  final dict = parseGestureDictionary(_read('dictionary.json'));
  late Future<int?> result;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gestureFigureProvider.overrideWith((ref, k) async => gestureTestPng())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pt'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  result = showGestureFocus(context, cards: cards, dictionary: dict, initialIndex: initialIndex, fontSize: 18);
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('abre no cartão tocado, com figura grande e próximo gatilho no rodapé', (tester) async {
    await _open(tester, '182_quero_viver.json', 3);

    expect(find.byKey(gestureFocusPageKey(3)), findsOneWidget);
    expect(find.textContaining('comer da árvore da vida.'), findsOneWidget);
    // Próximo cartão (índice 4) começa em "Com".
    expect(find.byKey(gestureFocusNextKey), findsOneWidget);
    expect(find.descendant(of: find.byKey(gestureFocusNextKey), matching: find.text('Com')), findsOneWidget);
    final figure = tester.getSize(find.byType(GestureFigure));
    final screen = tester.getSize(find.byType(GestureFocusView));
    expect(figure.width, greaterThanOrEqualTo(screen.width * 0.6));
    // Dentro do coro: chip CORO.
    expect(find.text('CORO'), findsOneWidget);
  });

  testWidgets('→ avança, ← volta; último mostra "fim"', (tester) async {
    await _open(tester, '182_quero_viver.json', 12);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.byKey(gestureFocusPageKey(13)), findsOneWidget);
    expect(find.text('fim'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(gestureFocusPageKey(12)), findsOneWidget);
  });

  testWidgets('toque na metade direita avança', (tester) async {
    await _open(tester, '182_quero_viver.json', 0);
    final size = tester.getSize(find.byType(GestureFocusView));
    await tester.tapAt(Offset(size.width * 0.9, size.height * 0.5));
    await tester.pumpAndSettle();
    expect(find.byKey(gestureFocusPageKey(1)), findsOneWidget);
  });

  testWidgets('Esc fecha devolvendo o índice atual', (tester) async {
    final result = await _open(tester, '182_quero_viver.json', 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await result, 6);
    expect(find.byType(GestureFocusView), findsNothing);
  });

  testWidgets('F alterna a tela cheia', (tester) async {
    await _open(tester, '182_quero_viver.json', 0);
    final container = ProviderScope.containerOf(tester.element(find.byType(GestureFocusView)));
    expect(container.read(readerFullscreenProvider), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(container.read(readerFullscreenProvider), isTrue);
  });

  testWidgets('chips de contexto aninhados: 3x e ligação', (tester) async {
    await _open(tester, 'sintetico_final_link.json', 1);
    expect(find.text('3x'), findsOneWidget);
    expect(find.text('ligação'), findsOneWidget);
  });

  testWidgets('cartão com linha de continuação não estraga o rodapé do anterior', (tester) async {
    // Cartão 4 (índice 4) tem duas linhas de letra; a primeira já tem
    // trigger ("Vou"), então o rodapé do cartão 3 continua mostrando ela.
    await _open(tester, '181_jerusalem.json', 3);
    expect(find.descendant(of: find.byKey(gestureFocusNextKey), matching: find.text('Vou')), findsOneWidget);
  });

  testWidgets('próximo cartão de continuação (trigger vazio) cai pro texto da linha', (tester) async {
    final cards = [
      const FlatGestureCard(
        index: 0,
        card: GestureCard(gestureId: 'aaaaaaaaaaaa', lyrics: [LyricLine(trigger: 'Louvor', text: 'ao Senhor')]),
        contexts: [],
      ),
      const FlatGestureCard(
        index: 1,
        card: GestureCard(gestureId: 'bbbbbbbbbbbb', lyrics: [LyricLine(trigger: '', text: 'só leitura')]),
        contexts: [],
      ),
    ];

    await _openCards(tester, cards, 0);

    expect(find.descendant(of: find.byKey(gestureFocusNextKey), matching: find.text('só leitura')), findsOneWidget);
  });
}
