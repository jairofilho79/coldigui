import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/presentation/providers/score_reader_controller.dart';
import 'package:coldigui/features/score_reader/presentation/utils/score_systems_layout.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_sheet_view.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_system_view.dart';
import 'package:crisp_notation/crisp_notation.dart' hide Interval, Key;
import 'package:flutter/material.dart' hide Interval;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'score_widget_test_support.dart';

class _ConnectedSheet extends ConsumerWidget {
  const _ConnectedSheet(this.document);
  final ScoreDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = scoreReaderControllerProvider(document);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return ScoreSheetView(
      score: state.displayed,
      staffSpace: 10,
      highlightedIds: state.activeIds,
      activeMeasure: state.activeMeasure,
      loopMeasures: state.loopStart == null
          ? null
          : (first: state.loopStart!, last: state.loopEnd ?? state.loopStart!),
      onElementTap: controller.onElementTap,
      onMeasureLongPress: (measure) async {
        await controller.seekToMeasure(measure);
        controller.cycleLoop();
      },
    );
  }
}

Finder _system(int index) => find.byWidgetPredicate(
  (widget) => widget is ScoreSystemView && widget.key == ValueKey(index),
);

Offset _elementPoint(WidgetTester tester, int index, String id) {
  final view = tester.widget<ScoreSystemView>(_system(index));
  final layout = view.system.layout;
  for (var staff = 0; staff < layout.staves.length; staff++) {
    for (final region in layout.staves[staff].regions) {
      if (region.elementId != id) continue;
      final b = region.bounds;
      return tester.getTopLeft(_system(index)) +
          Offset(
            (kScoreSystemMarginLeft + b.left + b.width / 2) * view.staffSpace,
            (kScoreSystemPadding -
                    layout.top +
                    layout.staffTop(staff) +
                    b.top +
                    b.height / 2) *
                view.staffSpace,
          );
    }
  }
  throw StateError('element not rendered: $id');
}

Offset _measurePoint(WidgetTester tester, int index) {
  final view = tester.widget<ScoreSystemView>(_system(index));
  final region = view.system.layout.staves.first.measureRegions.first;
  return tester.getTopLeft(_system(index)) +
      Offset(
        (kScoreSystemMarginLeft + (region.startX + region.endX) / 2) *
            view.staffSpace,
        tester.getSize(_system(index)).height / 2,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadWidgetScoreFont);
  late ScoreDocument document;
  setUp(() => document = widgetScoreDocument());

  testWidgets('tap in a later system previews, seeks and highlights its ID', (
    tester,
  ) async {
    final engine = WidgetScoreEngine();
    final container = await pumpScoreWidget(
      tester,
      engine: engine,
      size: const Size(320, 900),
      child: _ConnectedSheet(document),
    );
    final second = tester.widget<ScoreSystemView>(_system(1));
    expect(second.system.firstMeasure, greaterThan(0));
    final controller = container.read(
      scoreReaderControllerProvider(document).notifier,
    );
    final note = controller.playbackMap.timelines.first.firstWhere(
      (note) => !note.isRest && note.measureIndex == second.system.firstMeasure,
    );
    await tester.tapAt(_elementPoint(tester, 1, note.elementId));
    await tester.pumpAndSettle();
    final state = container.read(scoreReaderControllerProvider(document));
    expect(state.activeIds, {note.elementId});
    expect(state.activeMeasure, second.system.firstMeasure);
    expect(engine.pos, controller.playbackMap.startOfElement(note.elementId));
    expect(engine.previews, [
      for (final pitch in pitchesForElements(document.score.parts.first, [
        note.elementId,
      ]))
        (pitch, document.staves.first.midiProgram ?? 0),
    ]);
    expect(tester.widget<ScoreSystemView>(_system(1)).highlightedIds, {
      note.elementId,
    });
    expect(tester.widget<ScoreSystemView>(_system(0)).highlightedIds, isEmpty);

    await engine.play();
    await tester.pump();
    engine.previews.clear();
    await tester.tapAt(_elementPoint(tester, 1, note.elementId));
    await tester.pumpAndSettle();
    expect(
      engine.previews,
      isEmpty,
      reason: 'playing taps seek without preview',
    );
    expect(engine.pos, state.position);
  });

  testWidgets('long press uses document measures in systems after the first', (
    tester,
  ) async {
    final engine = WidgetScoreEngine();
    final container = await pumpScoreWidget(
      tester,
      engine: engine,
      size: const Size(320, 900),
      child: _ConnectedSheet(document),
    );
    final second = tester.widget<ScoreSystemView>(_system(1)).system;
    final third = tester.widget<ScoreSystemView>(_system(2)).system;
    expect(second.firstMeasure, greaterThan(0));
    // Confirm crisp's actual contract instead of assuming local indices.
    expect(second.layout.staves.first.measureRegions.first.index, 0);
    await tester.longPressAt(_measurePoint(tester, 1));
    await tester.pumpAndSettle();
    var state = container.read(scoreReaderControllerProvider(document));
    expect(state.activeMeasure, second.firstMeasure);
    expect(state.loopStart, second.firstMeasure);
    await tester.longPressAt(_measurePoint(tester, 2));
    await tester.pumpAndSettle();
    state = container.read(scoreReaderControllerProvider(document));
    expect(state.loopEnd, third.firstMeasure);
    final map = container
        .read(scoreReaderControllerProvider(document).notifier)
        .playbackMap;
    expect(engine.loop, (
      start: map.startOfMeasure(second.firstMeasure)!,
      end: map.endOfMeasure(third.firstMeasure)!,
    ));
  });

  testWidgets('loop shading paints the document range in the second system', (
    tester,
  ) async {
    final layout = ScoreSystemsLayout.of(document.score, widthSpaces: 32);
    expect(layout.systems.length, greaterThanOrEqualTo(2));
    final system = layout.systems[1];
    final measure = system.layout.staves.first.measureRegions.first;
    await pumpScoreWidget(
      tester,
      engine: WidgetScoreEngine(),
      size: const Size(320, 900),
      child: ScoreSheetView(
        score: document.score,
        staffSpace: 10,
        loopMeasures: (first: system.firstMeasure, last: system.firstMeasure),
      ),
    );
    final top =
        (kScoreSystemPadding - system.layout.top) * 10 +
        system.layout.staffTop(0) * 10;
    final paint = find.descendant(
      of: _system(1),
      matching: find.byType(CustomPaint),
    );
    expect(
      paint,
      paints..rect(
        rect: Rect.fromLTRB(
          kScoreSystemMarginLeft * 10 + measure.startX * 10,
          top - 10,
          kScoreSystemMarginLeft * 10 + measure.endX * 10,
          top + 50,
        ),
        color: CrispNotationTheme.standard.highlightColor.withValues(
          alpha: .12,
        ),
      ),
    );
  });

  testWidgets(
    'continuous follow pauses on drag then resumes without a new note',
    (tester) async {
      var active = 0;
      late StateSetter update;
      await pumpScoreWidget(
        tester,
        engine: WidgetScoreEngine(),
        size: const Size(320, 210),
        child: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return ScoreSheetView(
              score: document.score,
              staffSpace: 10,
              activeMeasure: active,
              follow: true,
            );
          },
        ),
      );
      final list = find.byType(ListView);
      final scroll = tester.widget<ListView>(list).controller!;
      final layout = ScoreSystemsLayout.of(document.score, widthSpaces: 32);
      expect(layout.systems.length, greaterThanOrEqualTo(3));
      update(() => active = layout.systems.last.firstMeasure);
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));

      await tester.drag(list, const Offset(0, 1000));
      await tester.pumpAndSettle();
      final manual = scroll.offset;
      update(
        () => active = layout.systems[layout.systems.length - 2].firstMeasure,
      );
      await tester.pumpAndSettle();
      expect(
        scroll.offset,
        manual,
        reason: 'manual interaction suspends follow',
      );
      await tester.pump(kScoreFollowResumeDelay);
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(manual));
    },
  );

  testWidgets('pages follow the active system and allow manual page turns', (
    tester,
  ) async {
    var active = 0;
    late StateSetter update;
    await pumpScoreWidget(
      tester,
      engine: WidgetScoreEngine(),
      size: const Size(320, 210),
      child: StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return ScoreSheetView(
            score: document.score,
            staffSpace: 10,
            mode: ScoreViewMode.pages,
            activeMeasure: active,
            follow: true,
          );
        },
      ),
    );
    final layout = ScoreSystemsLayout.of(document.score, widthSpaces: 32);
    final pages = tester.widget<PageView>(find.byType(PageView)).controller!;
    update(() => active = layout.systems.last.firstMeasure);
    await tester.pumpAndSettle();
    expect(pages.page, greaterThan(0));
    await tester.drag(find.byType(PageView), const Offset(640, 0));
    await tester.pumpAndSettle();
    final manualPage = pages.page;
    update(() => active = layout.systems.last.lastMeasure);
    await tester.pumpAndSettle();
    expect(pages.page, manualPage);
    await tester.pump(kScoreFollowResumeDelay);
    await tester.pumpAndSettle();
    expect(pages.page, greaterThan(manualPage!));
  });

  testWidgets(
    'pinch relayouts notation while external zoom and scroll still work',
    (tester) async {
      var zoom = 10.0;
      late StateSetter update;
      await pumpScoreWidget(
        tester,
        engine: WidgetScoreEngine(),
        size: const Size(320, 210),
        child: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return ScoreSheetView(
              score: document.score,
              staffSpace: zoom,
              onStaffSpaceChanged: (value) => setState(() => zoom = value),
            );
          },
        ),
      );
      final first = await tester.startGesture(
        const Offset(100, 100),
        pointer: 1,
      );
      final second = await tester.startGesture(
        const Offset(220, 100),
        pointer: 2,
      );
      await first.moveTo(const Offset(75, 100));
      await second.moveTo(const Offset(245, 100));
      await tester.pump();
      await first.moveTo(const Offset(60, 100));
      await second.moveTo(const Offset(260, 100));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      final pinched = tester.widget<ScoreSystemView>(_system(0)).staffSpace;
      expect(pinched, greaterThan(10));
      expect(pinched, lessThanOrEqualTo(16));
      update(() => zoom *= 1.25);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ScoreSystemView>(_system(0)).staffSpace,
        greaterThan(pinched),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
