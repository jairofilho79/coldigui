import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_theme.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_card_tile.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_figure.dart';
import 'package:coldigui/features/gestures/presentation/widgets/lyric_line_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/gesture_test_png.dart';

final _palette = GestureReaderMode.light.palette;

const _entry = GestureEntry(
  id: 'c687580e7682', name: 'x', description: '', exampleTriggers: [],
  image: 'assets/cia/gestures/c687580e7682.png', gif: null,
  status: GestureStatus.active, replacedBy: null, updatedAt: null,
);

const _card = GestureCard(
  gestureId: 'c687580e7682',
  lyrics: [
    LyricLine(trigger: 'Vou', text: 'para lá,'),
    LyricLine(trigger: '', text: 'com Jesus vou morar.'),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  double fontSize = 18,
  int index = 3,
  ValueChanged<int>? onTap,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gestureFigureProvider.overrideWith((ref, key) async => gestureTestPng()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: GestureCardTile(
              index: index,
              card: _card,
              entry: _entry,
              fontSize: fontSize,
              palette: _palette,
              onTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('figura à esquerda, uma LyricLineText por linha, centralizados na vertical', (tester) async {
    await _pump(tester);
    expect(find.byType(LyricLineText), findsNWidgets(2));
    final figure = tester.getRect(find.byType(GestureFigure));
    final lyric = tester.getRect(find.byType(LyricLineText).first);
    expect(figure.left, lessThan(lyric.left));
    // Duas linhas de 18 (≈ 47 dp) são mais baixas que a figura (96): a coluna
    // de letra tem que ficar no meio da figura, não colada no topo.
    final column = tester.getRect(
      find.descendant(of: find.byType(GestureCardTile), matching: find.byType(Column)).first,
    );
    expect(column.height, lessThan(figure.height));
    expect(column.center.dy, closeTo(figure.center.dy, 0.5));
  });

  testWidgets('zebra: índice ímpar pinta a faixa, par fica transparente', (tester) async {
    await _pump(tester); // index 3
    final odd = tester.widget<Material>(find.byKey(gestureCardStripeKey(3)));
    expect(odd.color, _palette.stripe);
    expect(tester.getSize(find.byKey(gestureCardStripeKey(3))).width, 400);

    await _pump(tester, index: 2);
    final even = tester.widget<Material>(find.byKey(gestureCardStripeKey(2)));
    expect(even.color, Colors.transparent);
  });

  testWidgets('lado da figura escala com a fonte: 96 em 18, 149 em 28', (tester) async {
    await _pump(tester);
    expect(tester.getSize(find.byType(GestureFigure)).width, 96);
    await _pump(tester, fontSize: 28);
    expect(tester.getSize(find.byType(GestureFigure)).width, closeTo(149.3, 0.1));
  });

  testWidgets('toque chama onTap com o índice', (tester) async {
    int? tapped;
    await _pump(tester, onTap: (i) => tapped = i);
    await tester.tap(find.byKey(gestureCardKey(3)));
    expect(tapped, 3);
  });
}
