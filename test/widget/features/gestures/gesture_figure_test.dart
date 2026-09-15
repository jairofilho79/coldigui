import 'package:coldigui/features/gestures/data/providers/gesture_providers.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_theme.dart';
import 'package:coldigui/features/gestures/presentation/widgets/gesture_figure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/gesture_test_png.dart';

final _palette = GestureReaderMode.light.palette;

const _entry = GestureEntry(
  id: 'c687580e7682',
  name: 'Mão ao peito',
  description: '',
  exampleTriggers: [],
  image: 'assets/cia/gestures/c687580e7682.png',
  gif: 'assets/cia/gestures/c687580e7682.gif',
  status: GestureStatus.active,
  replacedBy: null,
  updatedAt: null,
);

Future<void> _pump(
  WidgetTester tester, {
  required GestureEntry? entry,
  required Future<List<int>?> Function(String key) figure,
  bool preferGif = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gestureFigureProvider.overrideWith((ref, key) async {
          final bytes = await figure(key);
          return bytes == null ? null : gestureTestPng();
        }),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: GestureFigure(
            entry: entry,
            gestureId: 'c687580e7682',
            side: 96,
            preferGif: preferGif,
            palette: _palette,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('sem entrada → placeholder com o id', (tester) async {
    await _pump(tester, entry: null, figure: (_) async => null);
    expect(find.byKey(gesturePlaceholderKey('c687580e7682')), findsOneWidget);
    expect(find.text('c687580e7682'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('com bytes → Image.memory num quadrado de 96', (tester) async {
    final asked = <String>[];
    await _pump(tester, entry: _entry, figure: (k) async { asked.add(k); return [1]; });
    expect(find.byType(Image), findsOneWidget);
    expect(asked, [_entry.image]);
    final size = tester.getSize(find.byType(GestureFigure));
    expect(size.width, 96);
    expect(size.height, 96);
  });

  testWidgets('download falhou (null) → placeholder', (tester) async {
    await _pump(tester, entry: _entry, figure: (_) async => null);
    expect(find.byKey(gesturePlaceholderKey('c687580e7682')), findsOneWidget);
  });

  testWidgets('preferGif pede o GIF quando existe', (tester) async {
    final asked = <String>[];
    await _pump(tester, entry: _entry, figure: (k) async { asked.add(k); return [1]; }, preferGif: true);
    expect(asked, [_entry.gif]);
  });

  testWidgets('figura fica num quadro branco arredondado com borda da paleta', (tester) async {
    await _pump(tester, entry: _entry, figure: (_) async => [1]);
    final box = tester.widget<Container>(find.byKey(gestureFigureFrameKey));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, _palette.figureBg);
    expect(decoration.border, Border.all(color: _palette.figureBorder));
    expect(decoration.borderRadius, BorderRadius.circular(8));
    expect(tester.getSize(find.byType(GestureFigure)).width, 96);
  });
}
