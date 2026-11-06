import 'package:crisp_notation_core/crisp_notation_core.dart';

import '../entities/score_document.dart';
import 'score_performance_plan.dart';

/// Linha do tempo de execução de todas as pautas, no mesmo tempo musical do
/// MIDI gerado por `buildScoreMidi` (repetições expandidas, andamento da
/// pauta 0).
class ScorePlaybackMap {
  ScorePlaybackMap._(
    this.performancePlan,
    this._elementStart,
    this._elementMeasure,
    this._elementStaff,
    this._measureStart,
    this._measureEnd,
    this._spans,
    this._longest,
    this._occurrences,
  );

  factory ScorePlaybackMap.of(MultiPartScore score, {double? quarterBpm}) =>
      ScorePlaybackMap.fromPlan(
        ScorePerformancePlan.of(score, quarterBpm: quarterBpm),
      );

  factory ScorePlaybackMap.fromDocument(ScoreDocument document) =>
      ScorePlaybackMap.fromPlan(ScorePerformancePlan.fromDocument(document));

  factory ScorePlaybackMap.fromPlan(ScorePerformancePlan plan) {
    final elementStart = <String, Fraction>{};
    final elementMeasure = <String, int>{};
    final elementStaff = <String, int>{};
    final measureStart = <int, Fraction>{};
    final measureEnd = <int, Fraction>{};
    final spans = <_Span>[];
    var longest = Fraction.zero;
    for (final event in plan.events) {
      final id = event.origin.elementId;
      if (id == null) continue;
      elementStaff.putIfAbsent(id, () => event.origin.staffIndex);
      elementStart.putIfAbsent(id, () => event.highlightStart);
      elementMeasure.putIfAbsent(id, () => event.origin.measureIndex);
      if (event.isRest && event.chordPitches == null) continue;
      final soundingEnd = event.highlightEnd;
      final soundingStart = event.highlightStart;
      spans.add(_Span(soundingStart, soundingEnd, id));
      final soundingDuration = soundingEnd - soundingStart;
      if (soundingDuration > longest) longest = soundingDuration;
    }
    for (final occurrence in plan.measureOccurrences) {
      measureStart.putIfAbsent(occurrence.measureIndex, () => occurrence.start);
      measureEnd.putIfAbsent(occurrence.measureIndex, () => occurrence.end);
    }
    spans.sort((a, b) => a.start.compareTo(b.start));
    return ScorePlaybackMap._(
      plan,
      elementStart,
      elementMeasure,
      elementStaff,
      measureStart,
      measureEnd,
      spans,
      longest,
      plan.measureOccurrences,
    );
  }

  /// Uma linha do tempo por pauta (mesma ordem de `MultiPartScore.parts`).
  List<List<PlaybackNote>> get timelines => performancePlan.timelines;

  final ScorePerformancePlan performancePlan;
  TempoMap get tempoMap => performancePlan.tempoMap;
  Fraction get totalWholeNotes => performancePlan.totalWholeNotes;
  final Map<String, Fraction> _elementStart;
  final Map<String, int> _elementMeasure;
  final Map<String, int> _elementStaff;
  final Map<int, Fraction> _measureStart;
  final Map<int, Fraction> _measureEnd;
  final List<_Span> _spans;
  final Fraction _longest;
  final List<ScorePerformanceMeasureOccurrence> _occurrences;

  Duration get duration => durationAt(totalWholeNotes);

  Duration durationAt(Fraction time) => Duration(
    microseconds: (tempoMap.secondsAt(time) * Duration.microsecondsPerSecond)
        .round(),
  );

  Fraction timeAt(Duration position) {
    final whole = tempoMap.timeAt(
      position.inMicroseconds / Duration.microsecondsPerSecond,
    );
    // 1/3840 de semibreve resolve quiálteras comuns sem erro audível.
    return Fraction((whole * 3840).floor(), 3840);
  }

  /// Ids soando em [position]: notas, e pausas que carregam cifra.
  Set<String> soundingAt(Duration position) {
    final time = timeAt(position);
    final out = <String>{};
    // Só olha para trás até a nota mais longa da peça.
    final earliest = time - _longest;
    for (var i = _firstStartAfter(_spans, time) - 1; i >= 0; i--) {
      final span = _spans[i];
      if (span.start < earliest) break;
      if (time < span.end) out.add(span.id);
    }
    return out;
  }

  /// Compasso (índice no documento) em execução em [position], ou `null`
  /// fora da música.
  int? measureAt(Duration position) {
    final time = timeAt(position);
    var lo = 0;
    var hi = _occurrences.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_occurrences[mid].start <= time) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo == 0) return null;
    final occurrence = _occurrences[lo - 1];
    return time < occurrence.end ? occurrence.measureIndex : null;
  }

  /// Início (primeira passagem) do elemento — para posicionar o cursor no
  /// toque.
  Duration? startOfElement(String elementId) {
    final start = _elementStart[elementId];
    return start == null ? null : durationAt(start);
  }

  Duration? startOfMeasure(int measureIndex) {
    final start = _measureStart[measureIndex];
    return start == null ? null : durationAt(start);
  }

  Duration? endOfMeasure(int measureIndex) {
    final end = _measureEnd[measureIndex];
    return end == null ? null : durationAt(end);
  }

  int? measureOfElement(String elementId) => _elementMeasure[elementId];

  /// Pauta (índice em `MultiPartScore.parts`) do elemento.
  int? staffOfElement(String elementId) => _elementStaff[elementId];
}

class _Span {
  const _Span(this.start, this.end, this.id);

  final Fraction start;
  final Fraction end;
  final String id;
}

int _firstStartAfter(List<_Span> spans, Fraction time) {
  var lo = 0;
  var hi = spans.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (spans[mid].start <= time) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}
