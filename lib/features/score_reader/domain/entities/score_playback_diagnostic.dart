import 'package:crisp_notation_core/crisp_notation_core.dart';

enum ScorePlaybackDiagnosticCode {
  unsupportedArticulation,
  unsupportedTremoloStrokes,
  unsupportedTremoloType,
  unsupportedOrnament,
  unrecognizedDynamic,
  invalidTempo,
  unsupportedTempo,
  incompleteHairpin,
  incompletePedal,
  invalidNavigation,
  conflictingNavigation,
  unresolvedNavigation,
  cyclicNavigation,
  measureOccurrenceLimitExceeded,
  audioUnavailable,
  soundFontUnavailable,
  staffInstrumentUnavailable,
  chordInstrumentUnavailable,
}

class ScorePlaybackDiagnostic {
  const ScorePlaybackDiagnostic({
    required this.code,
    this.staffIndex,
    this.measureIndex,
    this.articulation,
    this.value,
    this.signal,
  });

  final ScorePlaybackDiagnosticCode code;
  final int? staffIndex;
  final int? measureIndex;
  final Articulation? articulation;
  final int? value;
  final String? signal;

  bool get blocksPlayback => switch (code) {
    ScorePlaybackDiagnosticCode.invalidNavigation ||
    ScorePlaybackDiagnosticCode.conflictingNavigation ||
    ScorePlaybackDiagnosticCode.unresolvedNavigation ||
    ScorePlaybackDiagnosticCode.cyclicNavigation ||
    ScorePlaybackDiagnosticCode.measureOccurrenceLimitExceeded ||
    ScorePlaybackDiagnosticCode.audioUnavailable => true,
    _ => false,
  };
}
