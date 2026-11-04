import 'dart:io';

import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/presentation/providers/score_reader_controller.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_mixer_sheet.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'score_widget_test_support.dart';

Finder _program(int staff) =>
    find.byKey(ValueKey('score-reader-program-$staff'));

Future<void> _selectProgram(WidgetTester tester, int staff, int program) async {
  await tester.ensureVisible(_program(staff));
  await tester.tap(_program(staff));
  await tester.pumpAndSettle();
  final option = find.text('GM${(program + 1).toString().padLeft(3, '0')}');
  await tester.scrollUntilVisible(
    option,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(option);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('GM accessibility target excludes the volume row', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpScoreWidget(
        tester,
        engine: WidgetScoreEngine(),
        child: ScoreMixerSheet(document: widgetScoreDocument()),
      );
      final field = find.ancestor(
        of: _program(0),
        matching: find.byType(InputDecorator),
      );
      expect(
        tester.getSemantics(_program(0)).rect.height,
        lessThanOrEqualTo(tester.getSize(field).height),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'GM selector defaults, updates a staff and survives seek/font reload',
    (tester) async {
      final document = parseScoreDocument(
        File('test/fixtures/scores/499.mscz').readAsBytesSync(),
      );
      final engine = WidgetScoreEngine();
      final container = await pumpScoreWidget(
        tester,
        engine: engine,
        size: const Size(320, 900),
        child: ScoreMixerSheet(document: document),
      );
      final provider = scoreReaderControllerProvider(document);
      final controller = container.read(provider.notifier);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ScoreMixerSheet)),
      )!;
      final initial = tester.widget<DropdownButton<int>>(_program(1));
      expect(initial.value, document.staves[1].midiProgram ?? 0);
      expect(
        initial.items!.map((item) => item.value),
        List.generate(128, (i) => i),
      );
      expect(find.text(l10n.scoreReaderInstrument), findsWidgets);
      expect(find.text(l10n.scoreReaderBasicInstruments), findsOneWidget);
      controller
        ..setStaffVolume(1, .4)
        ..toggleStaffMute(1)
        ..toggleStaffSolo(0)
        ..setSpeed(.75)
        ..setTranspose(2)
        ..setLoop(0, 2);
      await tester.pumpAndSettle();
      await _selectProgram(tester, 1, 40);
      expect(tester.widget<DropdownButton<int>>(_program(1)).value, 40);
      expect(container.read(provider).mix[1].program, 40);
      expect(
        container.read(provider).mix.first.program,
        document.staves.first.midiProgram ?? 0,
      );
      expect(
        engine.loads.last.midi,
        buildScoreMidi(document, programOverrides: {1: 40}),
      );
      expect(container.read(provider).mix[1].volume, .4);
      expect(container.read(provider).mix[1].muted, isTrue);
      expect(container.read(provider).mix.first.solo, isTrue);
      expect(engine.currentSpeed, .75);
      expect(engine.currentTranspose, 2);
      expect(engine.loop, isNotNull);
      expect(find.text(l10n.scoreReaderBasicInstruments), findsOneWidget);

      await controller.seekToMeasure(2);
      await controller.downloadFullSoundFont();
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<int>>(_program(1)).value, 40);
      expect(find.text(l10n.scoreReaderBasicInstruments), findsNothing);
      expect(
        engine.loads.last.midi,
        buildScoreMidi(document, programOverrides: {1: 40}),
      );
      final note = controller.playbackMap.timelines[1].firstWhere(
        (note) => !note.isRest,
      );
      await controller.onElementTap(note.elementId);
      expect(engine.previews.last.$2, 40);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed selector load keeps its original value, reports and retries',
    (tester) async {
      final document = widgetScoreDocument();
      final engine = WidgetScoreEngine();
      final container = await pumpScoreWidget(
        tester,
        engine: engine,
        size: const Size(320, 900),
        child: ScoreMixerSheet(document: document),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ScoreMixerSheet)),
      )!;
      engine.loadError = StateError('failed GM reload');
      await _selectProgram(tester, 0, 127);
      expect(tester.widget<DropdownButton<int>>(_program(0)).value, 0);
      expect(find.text(l10n.scoreReaderInstrumentFailed), findsOneWidget);
      expect(find.text(l10n.scoreReaderBasicInstruments), findsOneWidget);
      engine.loadError = null;
      await _selectProgram(tester, 0, 127);
      expect(tester.widget<DropdownButton<int>>(_program(0)).value, 127);
      expect(find.text(l10n.scoreReaderInstrumentFailed), findsNothing);
      expect(
        container
            .read(scoreReaderControllerProvider(document))
            .mix
            .first
            .program,
        127,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
