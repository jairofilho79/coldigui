import 'package:coldigui/features/score_reader/domain/entities/score_playback_diagnostic.dart';
import 'package:coldigui/features/score_reader/presentation/widgets/score_playback_diagnostic_notice.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'score_widget_test_support.dart';

void main() {
  const diagnostics = [
    ScorePlaybackDiagnostic(
      code: ScorePlaybackDiagnosticCode.unsupportedTremoloStrokes,
      staffIndex: 0,
      measureIndex: 1,
      value: 6,
    ),
    ScorePlaybackDiagnostic(
      code: ScorePlaybackDiagnosticCode.unsupportedArticulation,
      staffIndex: 0,
      measureIndex: 1,
      articulation: Articulation.breath,
    ),
    ScorePlaybackDiagnostic(
      code: ScorePlaybackDiagnosticCode.unsupportedTempo,
      staffIndex: 0,
      measureIndex: 1,
      signal: '72.5',
    ),
    ScorePlaybackDiagnostic(
      code: ScorePlaybackDiagnosticCode.measureOccurrenceLimitExceeded,
    ),
  ];

  for (final (locale, title) in [
    (const Locale('pt'), 'Diagnósticos da reprodução'),
    (const Locale('en'), 'Playback diagnostics'),
  ]) {
    testWidgets('localizes reasons and source locations in $locale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final document = widgetScoreDocument();

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ScorePlaybackDiagnosticNotice(
              document: document,
              diagnostics: diagnostics,
            ),
          ),
        ),
      );

      final context = tester.element(
        find.byKey(const ValueKey('score-reader-playback-diagnostics')),
      );
      final l10n = AppLocalizations.of(context)!;
      final semanticsNode = tester.getSemantics(
        find.byKey(const ValueKey('score-reader-playback-diagnostics')),
      );

      expect(find.text(title), findsOneWidget);
      expect(
        semanticsNode.label,
        contains(l10n.scoreReaderDiagnosticStaff(document.staves.first.label)),
      );
      expect(
        semanticsNode.label,
        contains(l10n.scoreReaderDiagnosticMeasure(2)),
      );
      expect(
        semanticsNode.label,
        contains(l10n.scoreReaderDiagnosticUnsupportedTremoloStrokes(6)),
      );
      expect(
        semanticsNode.label,
        contains(
          l10n.scoreReaderDiagnosticUnsupportedArticulation(
            l10n.scoreReaderDiagnosticBreathMark,
          ),
        ),
      );
      expect(
        semanticsNode.label,
        contains(l10n.scoreReaderDiagnosticUnsupportedTempo('72.5')),
      );
      expect(
        semanticsNode.label,
        contains(l10n.scoreReaderDiagnosticMeasureOccurrenceLimitExceeded),
      );
      expect(
        semanticsNode.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
      );
      semantics.dispose();
    });
  }
}
