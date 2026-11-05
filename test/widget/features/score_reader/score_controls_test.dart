import 'dart:io';

import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/presentation/providers/score_reader_controller.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_mixer_sheet.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_sheet_view.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_transport_bar.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'score_widget_test_support.dart';

class _Controls extends StatefulWidget {
  const _Controls(this.document);
  final ScoreDocument document;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  var showTempo = false;
  var mode = ScoreViewMode.continuous;
  var zoomIn = 0;
  var zoomOut = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ScoreTransportBar(
        document: widget.document,
        mode: mode,
        onModeChanged: (value) => setState(() => mode = value),
        onZoomIn: () => zoomIn++,
        onZoomOut: () => zoomOut++,
        showTempo: showTempo,
        onToggleTempo: () => setState(() => showTempo = !showTempo),
      ),
      if (showTempo) ScoreTempoBar(document: widget.document),
      ScoreProgressBar(document: widget.document),
    ],
  );
}

Finder _slider(Type parent) =>
    find.descendant(of: find.byType(parent), matching: find.byType(Slider));

Future<void> _tapSlider(
  WidgetTester tester,
  Finder slider,
  double fraction,
) async {
  final rect = tester.getRect(slider);
  // Stay inside the actual track, excluding the thumb's horizontal inset.
  await tester.tapAt(
    Offset(rect.left + 24 + (rect.width - 48) * fraction, rect.center.dy),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('BPM slider and reset update the controller and engine', (
    tester,
  ) async {
    final document = widgetScoreDocument();
    final engine = WidgetScoreEngine();
    final container = await pumpScoreWidget(
      tester,
      engine: engine,
      child: _Controls(document),
      size: const Size(1440, 900),
    );
    final provider = scoreReaderControllerProvider(document);
    await tester.tap(find.byKey(scoreReaderTempoKey));
    await tester.pumpAndSettle();
    expect(find.byType(ScoreTempoBar), findsOneWidget);
    await _tapSlider(tester, _slider(ScoreTempoBar), .75);
    final state = container.read(provider);
    expect(state.speed, greaterThan(1));
    expect(state.bpm, closeTo(document.quarterBpm * state.speed, .01));
    expect(engine.currentSpeed, state.speed);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ScoreTempoBar)),
    )!;
    expect(
      find.descendant(
        of: find.byType(ScoreTransportBar),
        matching: find.text(l10n.scoreReaderBpm(state.bpm.round())),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip(l10n.scoreReaderTempoReset));
    await tester.pumpAndSettle();
    expect(container.read(provider).speed, 1);
    expect(engine.currentSpeed, 1);
    await tester.tap(find.byKey(scoreReaderTempoKey));
    await tester.pumpAndSettle();
    expect(find.byType(ScoreTempoBar), findsNothing);
  });

  testWidgets('transpose buttons enforce bounds and reset to the written key', (
    tester,
  ) async {
    final document = widgetScoreDocument();
    final engine = WidgetScoreEngine();
    final container = await pumpScoreWidget(
      tester,
      engine: engine,
      child: _Controls(document),
      size: const Size(1440, 900),
    );
    final provider = scoreReaderControllerProvider(document);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ScoreTransportBar)),
    )!;
    for (var i = 0; i < kScoreMaxTranspose; i++) {
      await tester.tap(find.byKey(scoreReaderTransposeUpKey));
      await tester.pump();
    }
    expect(container.read(provider).transpose, kScoreMaxTranspose);
    expect(engine.currentTranspose, kScoreMaxTranspose);
    expect(
      tester
          .widget<IconButton>(find.byKey(scoreReaderTransposeUpKey))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip(l10n.scoreReaderTransposeReset));
    await tester.pumpAndSettle();
    expect(container.read(provider).transpose, 0);
    expect(container.read(provider).displayed, same(document.score));
    expect(engine.currentTranspose, 0);
    for (var i = 0; i < kScoreMaxTranspose; i++) {
      await tester.tap(find.byKey(scoreReaderTransposeDownKey));
      await tester.pump();
    }
    expect(container.read(provider).transpose, -kScoreMaxTranspose);
    expect(engine.currentTranspose, -kScoreMaxTranspose);
    expect(
      tester
          .widget<IconButton>(find.byKey(scoreReaderTransposeDownKey))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'loop A/B/clear, play, pause and stop reach the real controller',
    (tester) async {
      final document = widgetScoreDocument();
      final engine = WidgetScoreEngine();
      final container = await pumpScoreWidget(
        tester,
        engine: engine,
        child: _Controls(document),
        size: const Size(1440, 900),
      );
      final provider = scoreReaderControllerProvider(document);
      final controller = container.read(provider.notifier);
      final map = controller.playbackMap;
      engine.positionsCtl.add(map.startOfMeasure(1)!);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(scoreReaderLoopKey));
      await tester.pumpAndSettle();
      expect(container.read(provider).loopStart, 1);
      expect(container.read(provider).loopEnd, isNull);
      expect(engine.loop, isNull);
      engine.positionsCtl.add(map.startOfMeasure(2)!);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(scoreReaderLoopKey));
      await tester.pumpAndSettle();
      expect(container.read(provider).loopEnd, 2);
      expect(engine.loop, (
        start: map.startOfMeasure(1)!,
        end: map.endOfMeasure(2)!,
      ));
      expect(
        tester.widget<IconButton>(find.byKey(scoreReaderLoopKey)).isSelected,
        isTrue,
      );
      await tester.tap(find.byKey(scoreReaderPlayKey));
      await tester.pumpAndSettle();
      expect(engine.playing, isTrue);
      expect(container.read(provider).playing, isTrue);
      expect(engine.pos, map.startOfMeasure(1));
      await tester.tap(find.byKey(scoreReaderPlayKey));
      await tester.pumpAndSettle();
      expect(engine.playing, isFalse);
      expect(container.read(provider).playing, isFalse);
      await tester.tap(find.byKey(scoreReaderStopKey));
      await tester.pumpAndSettle();
      expect(container.read(provider).position, map.startOfMeasure(1));
      expect(container.read(provider).activeIds, isEmpty);
      await tester.tap(find.byKey(scoreReaderLoopKey));
      await tester.pumpAndSettle();
      expect(container.read(provider).isLoopActive, isFalse);
      expect(container.read(provider).loopStart, isNull);
      expect(engine.loop, isNull);
      await tester.tap(find.byKey(scoreReaderStopKey));
      await tester.pumpAndSettle();
      expect(engine.pos, Duration.zero);
    },
  );

  testWidgets('progress seeks and zoom/mode callbacks remain available', (
    tester,
  ) async {
    final document = widgetScoreDocument();
    final engine = WidgetScoreEngine();
    final container = await pumpScoreWidget(
      tester,
      engine: engine,
      child: _Controls(document),
      size: const Size(1440, 900),
    );
    final provider = scoreReaderControllerProvider(document);
    await _tapSlider(tester, _slider(ScoreProgressBar), .55);
    final state = container.read(provider);
    expect(state.position.inMilliseconds, greaterThan(0));
    expect(
      state.position.inMilliseconds,
      lessThan(state.duration.inMilliseconds),
    );
    expect(engine.pos, state.position);
    expect(state.activeIds, isNotEmpty);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ScoreTransportBar)),
    )!;
    await tester.tap(find.byTooltip(l10n.scoreReaderZoomIn));
    await tester.tap(find.byTooltip(l10n.scoreReaderZoomOut));
    final controls = tester.state<_ControlsState>(find.byType(_Controls));
    expect(controls.zoomIn, 1);
    expect(controls.zoomOut, 1);
    await tester.tap(find.byKey(scoreReaderModeKey));
    await tester.pumpAndSettle();
    expect(controls.mode, ScoreViewMode.pages);
    await tester.tap(find.byKey(scoreReaderModeKey));
    await tester.pumpAndSettle();
    expect(controls.mode, ScoreViewMode.continuous);
  });

  testWidgets('mixer volume/mute/solo target the selected staff at 320px', (
    tester,
  ) async {
    final document = parseScoreDocument(
      File('test/fixtures/scores/499.mscz').readAsBytesSync(),
    );
    expect(document.staves.length, greaterThanOrEqualTo(2));
    final engine = WidgetScoreEngine();
    final container = await pumpScoreWidget(
      tester,
      engine: engine,
      child: _Controls(document),
      size: const Size(320, 900),
    );
    final provider = scoreReaderControllerProvider(document);
    final mixerButton = find.byKey(scoreReaderMixerKey);
    await tester.ensureVisible(mixerButton);
    await tester.tap(mixerButton);
    await tester.pumpAndSettle();
    expect(find.byType(ScoreMixerSheet), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ScoreMixerSheet)),
    )!;
    await _tapSlider(tester, _slider(ScoreMixerSheet).at(1), .2);
    final volume = container.read(provider).mix[1].volume;
    expect(volume, inExclusiveRange(0, 1));
    expect(engine.volumes[midiChannelForStaff(1)], volume);
    expect(container.read(provider).mix.first.volume, 1);

    await tester.tap(find.byTooltip(l10n.scoreReaderMute).at(1));
    await tester.pumpAndSettle();
    expect(container.read(provider).mix[1].muted, isTrue);
    expect(engine.mutedTracks, {1});
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip(l10n.scoreReaderMute).at(1),
              matching: find.byType(IconButton),
            ),
          )
          .isSelected,
      isTrue,
    );
    await tester.tap(find.byTooltip(l10n.scoreReaderSolo).at(1));
    await tester.pumpAndSettle();
    expect(container.read(provider).mix[1].solo, isTrue);
    expect(engine.soloTracks, {1});
    expect(container.read(provider).mix.first.solo, isFalse);
    await tester.tap(find.byTooltip(l10n.scoreReaderMute).at(1));
    await tester.tap(find.byTooltip(l10n.scoreReaderSolo).at(1));
    await tester.pumpAndSettle();
    expect(container.read(provider).mix[1].muted, isFalse);
    expect(container.read(provider).mix[1].solo, isFalse);
    expect(engine.mutedTracks, isEmpty);
    expect(engine.soloTracks, isEmpty);
    expect(container.read(provider).mix[1].volume, volume);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(ScoreMixerSheet))).pop();
    await tester.pumpAndSettle();
    await tester.tap(mixerButton);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(_slider(ScoreMixerSheet).at(1)).value, volume);
  });
}
