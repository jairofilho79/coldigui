import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/score_document.dart';
import '../../domain/entities/score_playback_diagnostic.dart';

class ScorePlaybackDiagnosticNotice extends StatelessWidget {
  const ScorePlaybackDiagnosticNotice({
    required this.document,
    required this.diagnostics,
    super.key,
  });

  final ScoreDocument document;
  final List<ScorePlaybackDiagnostic> diagnostics;

  @override
  Widget build(BuildContext context) {
    if (diagnostics.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final blocksPlayback = diagnostics.any((item) => item.blocksPlayback);
    final messages = [
      for (final diagnostic in diagnostics)
        _diagnosticMessage(l10n, document, diagnostic),
    ];
    final semanticsLabel = [
      l10n.scoreReaderDiagnosticsTitle,
      ...messages,
    ].join('. ');
    final foreground = blocksPlayback
        ? colors.onErrorContainer
        : colors.onSurface;

    return Semantics(
      key: const ValueKey('score-reader-playback-diagnostics'),
      container: true,
      liveRegion: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: blocksPlayback
              ? colors.errorContainer
              : colors.surfaceContainerHigh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    blocksPlayback
                        ? Icons.warning_amber_outlined
                        : Icons.info_outline,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.scoreReaderDiagnosticsTitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final message in messages)
                        Padding(
                          padding: const EdgeInsets.only(left: 26, top: 4),
                          child: Text(
                            message,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: foreground),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _diagnosticMessage(
  AppLocalizations l10n,
  ScoreDocument document,
  ScorePlaybackDiagnostic diagnostic,
) {
  final reason = switch (diagnostic.code) {
    ScorePlaybackDiagnosticCode.unsupportedArticulation =>
      l10n.scoreReaderDiagnosticUnsupportedArticulation(
        switch (diagnostic.articulation) {
          Articulation.breath => l10n.scoreReaderDiagnosticBreathMark,
          Articulation.upBow ||
          Articulation.downBow => l10n.scoreReaderDiagnosticBowingMark,
          _ => l10n.scoreReaderDiagnosticOtherArticulation,
        },
      ),
    ScorePlaybackDiagnosticCode.unsupportedTremoloStrokes =>
      diagnostic.value == null
          ? l10n.scoreReaderDiagnosticInvalidTremoloStrokes
          : l10n.scoreReaderDiagnosticUnsupportedTremoloStrokes(
              diagnostic.value!,
            ),
    ScorePlaybackDiagnosticCode.unsupportedTremoloType =>
      l10n.scoreReaderDiagnosticUnsupportedTremoloType(
        _diagnosticValue(diagnostic.signal),
      ),
    ScorePlaybackDiagnosticCode.unsupportedOrnament =>
      l10n.scoreReaderDiagnosticUnsupportedOrnament(
        _diagnosticValue(diagnostic.signal),
      ),
    ScorePlaybackDiagnosticCode.unrecognizedDynamic =>
      l10n.scoreReaderDiagnosticUnrecognizedDynamic(
        _diagnosticValue(diagnostic.signal),
      ),
    ScorePlaybackDiagnosticCode.invalidTempo =>
      l10n.scoreReaderDiagnosticInvalidTempo(
        _diagnosticValue(diagnostic.signal),
      ),
    ScorePlaybackDiagnosticCode.unsupportedTempo =>
      l10n.scoreReaderDiagnosticUnsupportedTempo(
        _diagnosticValue(diagnostic.signal),
      ),
    ScorePlaybackDiagnosticCode.incompleteHairpin =>
      l10n.scoreReaderDiagnosticIncompleteHairpin,
    ScorePlaybackDiagnosticCode.incompletePedal =>
      l10n.scoreReaderDiagnosticIncompletePedal,
    ScorePlaybackDiagnosticCode.invalidNavigation =>
      l10n.scoreReaderDiagnosticInvalidNavigation,
    ScorePlaybackDiagnosticCode.conflictingNavigation =>
      l10n.scoreReaderDiagnosticConflictingNavigation,
    ScorePlaybackDiagnosticCode.unresolvedNavigation =>
      l10n.scoreReaderDiagnosticUnresolvedNavigation,
    ScorePlaybackDiagnosticCode.cyclicNavigation =>
      l10n.scoreReaderDiagnosticCyclicNavigation,
    ScorePlaybackDiagnosticCode.measureOccurrenceLimitExceeded =>
      l10n.scoreReaderDiagnosticMeasureOccurrenceLimitExceeded,
    ScorePlaybackDiagnosticCode.audioUnavailable =>
      l10n.scoreReaderDiagnosticAudioUnavailable,
    ScorePlaybackDiagnosticCode.soundFontUnavailable =>
      l10n.scoreReaderDiagnosticSoundFontUnavailable,
    ScorePlaybackDiagnosticCode.staffInstrumentUnavailable =>
      l10n.scoreReaderDiagnosticStaffInstrumentUnavailable,
    ScorePlaybackDiagnosticCode.chordInstrumentUnavailable =>
      l10n.scoreReaderDiagnosticChordInstrumentUnavailable,
  };
  final location = <String>[
    if (diagnostic.staffIndex case final index?
        when index >= 0 && index < document.staves.length)
      l10n.scoreReaderDiagnosticStaff(document.staves[index].label),
    if (diagnostic.measureIndex case final measure? when measure >= 0)
      l10n.scoreReaderDiagnosticMeasure(measure + 1),
  ];
  return location.isEmpty ? reason : '${location.join(' · ')}: $reason';
}

String _diagnosticValue(String? value) {
  final text = value?.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  if (text == null || text.isEmpty) return '—';
  return text.length <= 60 ? text : '${text.substring(0, 60)}…';
}
