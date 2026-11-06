import 'package:crisp_notation_core/crisp_notation_core.dart';

import 'musescore_performance_metadata.dart';

/// Formato de origem de uma partitura digital.
enum ScoreSourceFormat { mscz, mscx, mxl, musicXml }

/// Uma pauta tocável da partitura — a unidade do mixer.
///
/// Um instrumento de duas pautas (piano) vira duas [ScoreStaff] com o mesmo
/// [partName]; cada uma tem o seu canal MIDI.
class ScoreStaff {
  const ScoreStaff({
    required this.index,
    required this.partName,
    this.staffInPart = 0,
    this.staffCountInPart = 1,
    this.midiProgram,
  });

  /// Posição da pauta no sistema (0 = topo).
  final int index;

  /// Nome do instrumento/voz como gravado no arquivo (ex.: `Tenor`).
  final String partName;

  final int staffInPart;
  final int staffCountInPart;

  /// Programa General MIDI 0-based; `null` quando o arquivo não declara.
  final int? midiProgram;

  String get label =>
      staffCountInPart > 1 ? '$partName ${staffInPart + 1}' : partName;
}

/// Partitura carregada e pronta para render e playback.
///
/// [score] está sempre no tom escrito; transposição é aplicada por cima
/// (`transposeScore`), preservando ids de elementos.
class ScoreDocument {
  ScoreDocument({
    required this.score,
    required this.staves,
    required this.format,
    this.museScorePerformance,
    this.musicXmlPerformance,
  }) : assert(staves.length == score.parts.length);

  final MultiPartScore score;
  final List<ScoreStaff> staves;
  final ScoreSourceFormat format;
  final MuseScorePerformanceMetadata? museScorePerformance;
  final MusicXmlPerformanceMetadata? musicXmlPerformance;

  /// Tempo inicial (semínima/min). MuseScore e MusicXML gravam o tempo só na
  /// primeira pauta, então ela é a referência para todas.
  double get quarterBpm => score.parts.first.tempo?.quarterBpm ?? 120;

  int get measureCount => score.measureCount;

  int get chordSymbolCount =>
      score.parts.fold(0, (sum, part) => sum + part.chordSymbols.length);

  int get lyricCount =>
      score.parts.fold(0, (sum, part) => sum + part.lyrics.length);
}
