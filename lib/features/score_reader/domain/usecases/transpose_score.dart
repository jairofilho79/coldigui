import 'package:crisp_notation_core/crisp_notation_core.dart';

import '../entities/score_document.dart';

const int kMaxScoreTransposeSemitones = 12;

/// Intervalo usado para transpor [semitones] (±12): a grafia mais comum para
/// cada distância; armaduras fora do círculo viram a enarmônica (o crisp
/// troca G♯ maior por A♭ maior, por exemplo).
Interval intervalForSemitones(int semitones) {
  return switch (semitones.abs() % 12) {
    0 => semitones == 0 ? Interval.perfectUnison : Interval.perfectOctave,
    1 => Interval.minorSecond,
    2 => Interval.majorSecond,
    3 => Interval.minorThird,
    4 => Interval.majorThird,
    5 => Interval.perfectFourth,
    6 => Interval.diminishedFifth,
    7 => Interval.perfectFifth,
    8 => Interval.minorSixth,
    9 => Interval.majorSixth,
    10 => Interval.minorSeventh,
    _ => Interval.majorSeventh,
  };
}

/// Transpõe todas as pautas (notas, armaduras e cifras); ids e letra ficam
/// iguais, então highlight e toque continuam valendo.
MultiPartScore transposeScore(MultiPartScore score, int semitones) {
  final clamped = semitones.clamp(
    -kMaxScoreTransposeSemitones,
    kMaxScoreTransposeSemitones,
  );
  if (clamped == 0) return score;
  final interval = intervalForSemitones(clamped);
  return MultiPartScore(
    [
      for (final part in score.parts)
        part.transposedBy(interval, descending: clamped < 0),
    ],
    brackets: score.brackets,
    barlineGroups: score.barlineGroups,
    partialParts: score.partialParts,
    crossStaffChords: score.crossStaffChords,
  );
}

extension ScoreDocumentTransposition on ScoreDocument {
  MultiPartScore transposed(int semitones) => transposeScore(score, semitones);
}
