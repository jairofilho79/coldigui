import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/score_reader/data/providers/score_providers.dart';
import 'package:coldigui/features/score_reader/demo/score_reader_demo_fixture.dart';
import 'package:coldigui/features/score_reader/presentation/pages/score_reader_screen.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_sheet_view.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_system_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'score_widget_test_support.dart';

Future<void> _open(WidgetTester tester) async {
  await pumpScoreWidget(
    tester,
    engine: WidgetScoreEngine(),
    size: const Size(1024, 700),
    child: ProviderScope(
      overrides: [
        scoreDocumentProvider(scoreReaderDemoKey)
            .overrideWith((ref) async => widgetScoreDocument()),
      ],
      child: ScoreReaderScreen(
        queryParams: {'pdfId': encodePdfId(scoreReaderDemoKey)},
      ),
    ),
  );
}

Future<void> _pinch(WidgetTester tester, double halfSpan) async {
  final center = tester.getCenter(find.byType(ScoreSheetView));
  final first = await tester.startGesture(
    center - const Offset(40, 0),
    pointer: 1,
  );
  final second = await tester.startGesture(
    center + const Offset(40, 0),
    pointer: 2,
  );
  await first.moveTo(center - const Offset(70, 0));
  await second.moveTo(center + const Offset(70, 0));
  await tester.pump();
  await first.moveTo(center - Offset(halfSpan, 0));
  await second.moveTo(center + Offset(halfSpan, 0));
  await tester.pump();
  await first.up();
  await second.up();
  await tester.pumpAndSettle();
}

Finder _zoom(IconData icon) =>
    find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton));

void _expectZoom(WidgetTester tester, double expected) {
  expect(
    tester.widget<ScoreSheetView>(find.byType(ScoreSheetView)).staffSpace,
    closeTo(expected, .001),
  );
  expect(
    tester
        .widgetList<ScoreSystemView>(find.byType(ScoreSystemView))
        .first
        .staffSpace,
    closeTo(expected, .001),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadWidgetScoreFont);

  testWidgets(
    'pinch to maximum updates screen and +/- continue at the effective zoom',
    (tester) async {
      await _open(tester);
      await _pinch(tester, 300);
      _expectZoom(tester, 16);
      expect(tester.widget<IconButton>(_zoom(Icons.zoom_in)).onPressed, isNull);
      expect(
        tester.widget<IconButton>(_zoom(Icons.zoom_out)).onPressed,
        isNotNull,
      );
      await tester.tap(_zoom(Icons.zoom_out));
      await tester.pumpAndSettle();
      _expectZoom(tester, 16 / 1.25);
      expect(
        tester.widget<IconButton>(_zoom(Icons.zoom_in)).onPressed,
        isNotNull,
      );
      await tester.tap(_zoom(Icons.zoom_in));
      await tester.pumpAndSettle();
      _expectZoom(tester, 16);
      expect(tester.widget<IconButton>(_zoom(Icons.zoom_in)).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pinch to minimum updates screen and enables only zoom-in', (
    tester,
  ) async {
    await _open(tester);
    await _pinch(tester, 5);
    _expectZoom(tester, 4);
    expect(tester.widget<IconButton>(_zoom(Icons.zoom_out)).onPressed, isNull);
    expect(
      tester.widget<IconButton>(_zoom(Icons.zoom_in)).onPressed,
      isNotNull,
    );
    await tester.tap(_zoom(Icons.zoom_in));
    await tester.pumpAndSettle();
    _expectZoom(tester, 5);
    expect(
      tester.widget<IconButton>(_zoom(Icons.zoom_out)).onPressed,
      isNotNull,
    );
    await tester.tap(_zoom(Icons.zoom_out));
    await tester.pumpAndSettle();
    _expectZoom(tester, 4);
    expect(tester.widget<IconButton>(_zoom(Icons.zoom_out)).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
