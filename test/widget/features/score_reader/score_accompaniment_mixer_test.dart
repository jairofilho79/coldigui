import 'dart:io';

import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/score_reader/data/providers/score_providers.dart';
import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/demo/score_reader_demo_fixture.dart';
import 'package:coldigui/features/score_reader/presentation/pages/score_reader_screen.dart';
import 'package:coldigui/features/score_reader/presentation/providers/score_reader_controller.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_mixer_sheet.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart' hide Interval;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'score_widget_test_support.dart';

ScoreDocument _documentWithStaves(int count) {
  final source = parseScoreDocument(
    File('test/fixtures/scores/chord_playback.musicxml').readAsBytesSync(),
  );
  final part = source.score.parts.single;
  return ScoreDocument(
    score: MultiPartScore([
      for (var index = 0; index < count; index++) part.copyWith(),
    ]),
    staves: [
      for (var index = 0; index < count; index++)
        ScoreStaff(index: index, partName: 'Staff $index'),
    ],
    format: source.format,
  );
}

void main() {
  setUpAll(loadWidgetScoreFont);

  testWidgets(
    'capacity warning is accessible and staff selection is explicit',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final document = _documentWithStaves(16);
        final engine = WidgetScoreEngine();
        final container = await pumpScoreWidget(
          tester,
          engine: engine,
          size: const Size(800, 900),
          child: ScoreMixerSheet(document: document),
        );
        final provider = scoreReaderControllerProvider(document);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ScoreMixerSheet)),
        )!;
        final warning = find.byKey(
          const ValueKey('score-reader-capacity-warning'),
        );

        expect(
          tester.getSemantics(warning).label,
          contains(l10n.scoreReaderStaffCapacityWarning),
        );
        expect(
          tester.getSemantics(warning).label,
          contains(l10n.scoreReaderStaffCapacityLimit(15)),
        );
        expect(
          container.read(provider).selectedStaffIndices,
          Set<int>.from(List.generate(16, (index) => index)),
        );
        expect(
          container.read(provider).audio,
          ScoreAudioStatus.selectionRequired,
        );
        expect(engine.loads, isEmpty);

        final firstStaff = find.byKey(
          const ValueKey('score-reader-play-staff-0'),
        );
        await tester.ensureVisible(firstStaff);
        await tester.tap(firstStaff);
        await tester.pumpAndSettle();
        expect(container.read(provider).selectedStaffIndices, hasLength(15));
        expect(container.read(provider).audio, ScoreAudioStatus.ready);
        expect(container.read(provider).displayed.parts, hasLength(16));

        final accompaniment = find.byKey(
          const ValueKey('score-reader-chord-enabled'),
        );
        await tester.scrollUntilVisible(
          accompaniment,
          -600,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(accompaniment);
        await tester.pumpAndSettle();
        await tester.tap(accompaniment);
        await tester.pumpAndSettle();
        expect(container.read(provider).chordAccompanimentEnabled, isTrue);
        expect(
          container.read(provider).audio,
          ScoreAudioStatus.selectionRequired,
        );
        expect(
          tester.getSemantics(warning).label,
          contains(l10n.scoreReaderStaffCapacityLimit(14)),
        );

        final secondStaff = find.byKey(
          const ValueKey('score-reader-play-staff-1'),
        );
        await tester.scrollUntilVisible(
          secondStaff,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(secondStaff);
        await tester.pumpAndSettle();
        expect(container.read(provider).selectedStaffIndices, hasLength(14));
        expect(container.read(provider).audio, ScoreAudioStatus.ready);
        expect(container.read(provider).displayed.parts, hasLength(16));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('chord controls are independently labeled in English', (
    tester,
  ) async {
    final document = _documentWithStaves(2);
    final container = await pumpScoreWidget(
      tester,
      engine: WidgetScoreEngine(),
      child: ScoreMixerSheet(document: document),
      locale: const Locale('en'),
    );
    final provider = scoreReaderControllerProvider(document);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ScoreMixerSheet)),
    )!;

    expect(find.text(l10n.scoreReaderChordAccompaniment), findsOneWidget);
    expect(find.text(l10n.scoreReaderChordSource), findsOneWidget);
    expect(find.byTooltip(l10n.scoreReaderChordMute), findsOneWidget);
    expect(find.byTooltip(l10n.scoreReaderChordSolo), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const ValueKey('score-reader-chord-program')),
          )
          .items,
      hasLength(128),
    );

    await tester.tap(find.byKey(const ValueKey('score-reader-chord-mute')));
    await tester.tap(find.byKey(const ValueKey('score-reader-chord-solo')));
    await tester.pumpAndSettle();
    expect(container.read(provider).chordMix.muted, isTrue);
    expect(container.read(provider).chordMix.solo, isTrue);
    expect(container.read(provider).mix.first.muted, isFalse);
    expect(container.read(provider).mix.first.solo, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reader warning opens staff selection without hiding the score', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final document = _documentWithStaves(16);
    final engine = WidgetScoreEngine();

    await pumpScoreWidget(
      tester,
      engine: engine,
      size: const Size(800, 900),
      settle: false,
      child: ProviderScope(
        overrides: [
          scoreDocumentProvider(scoreReaderDemoKey)
              .overrideWith((ref) async => document),
        ],
        child: ScoreReaderScreen(
          queryParams: {'pdfId': encodePdfId(scoreReaderDemoKey)},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    try {
      final screen = find.byType(ScoreReaderScreen);
      final l10n = AppLocalizations.of(tester.element(screen))!;
      final warning = find.byKey(
        const ValueKey('score-reader-capacity-notice'),
      );
      expect(
        tester.getSemantics(warning).label,
        contains(l10n.scoreReaderStaffCapacityWarning),
      );
      expect(find.text(l10n.scoreReaderChooseStaves), findsOneWidget);

      final container = ProviderScope.containerOf(tester.element(screen));
      final state = container.read(scoreReaderControllerProvider(document));
      expect(state.displayed.parts, hasLength(16));
      await tester.tap(find.text(l10n.scoreReaderChooseStaves));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ScoreMixerSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey('score-reader-play-staff-0')),
        findsOneWidget,
      );
      expect(
        container.read(scoreReaderControllerProvider(document)).displayed.parts,
        hasLength(16),
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
