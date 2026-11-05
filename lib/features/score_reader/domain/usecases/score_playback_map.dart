import 'package:crisp_notation_core/crisp_notation_core.dart';

/// Linha do tempo de execução de todas as pautas, no mesmo tempo musical do
/// MIDI gerado por `buildScoreMidi` (repetições expandidas, andamento da
/// pauta 0).
class ScorePlaybackMap {
  ScorePlaybackMap._(
    this.timelines,
    this.tempoMap,
    this.totalWholeNotes,
    this._elementStart,
    this._elementMeasure,
    this._elementStaff,
    this._measureStart,
    this._measureEnd,
    this._spans,
    this._longest,
  );

  factory ScorePlaybackMap.of(MultiPartScore score, {double? quarterBpm}) {
    final timelines = [for (final part in score.parts) playbackTimeline(part)];
    final chordAnchors = {
      for (final part in score.parts)
        for (final symbol in part.chordSymbols) symbol.elementId,
    };
    final elementStart = <String, Fraction>{};
    final elementMeasure = <String, int>{};
    final elementStaff = <String, int>{};
    final measureStart = <int, Fraction>{};
    final measureEnd = <int, Fraction>{};
    final spans = <_Span>[];
    var longest = Fraction.zero;
    var total = Fraction.zero;
    for (final (staff, timeline) in timelines.indexed) {
      final visitedElements = <(int, String)>{};
      for (final note in timeline) {
        elementStaff.putIfAbsent(note.elementId, () => staff);
        elementStart.putIfAbsent(note.elementId, () => note.start);
        elementMeasure.putIfAbsent(note.elementId, () => note.measureIndex);
        // A-B usa início e fim da mesma passagem, não toda a repetição.
        if (visitedElements.add((note.measureIndex, note.elementId))) {
          final start = measureStart[note.measureIndex];
          if (start == null || note.start < start) {
            measureStart[note.measureIndex] = note.start;
          }
          final end = measureEnd[note.measureIndex];
          if (end == null || note.end > end) {
            measureEnd[note.measureIndex] = note.end;
          }
        }
        if (note.end > total) total = note.end;
        // Pausa só acende quando carrega cifra: assim a cifra sobre a pausa
        // também acompanha a execução.
        if (note.isRest && !chordAnchors.contains(note.elementId)) continue;
        spans.add(_Span(note.start, note.end, note.elementId));
        if (note.duration > longest) longest = note.duration;
      }
    }
    spans.sort((a, b) => a.start.compareTo(b.start));
    return ScorePlaybackMap._(
      timelines,
      _unfoldedTempoMap(
        score.parts.first,
        timelines.first,
        quarterBpm ?? score.parts.first.tempo?.quarterBpm ?? 120,
      ),
      total,
      elementStart,
      elementMeasure,
      elementStaff,
      measureStart,
      measureEnd,
      spans,
      longest,
    );
  }

  /// Uma linha do tempo por pauta (mesma ordem de `MultiPartScore.parts`).
  final List<List<PlaybackNote>> timelines;
  final TempoMap tempoMap;
  final Fraction totalWholeNotes;
  final Map<String, Fraction> _elementStart;
  final Map<String, int> _elementMeasure;
  final Map<String, int> _elementStaff;
  final Map<int, Fraction> _measureStart;
  final Map<int, Fraction> _measureEnd;
  final List<_Span> _spans;
  final Fraction _longest;

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
    final first = timelines.first;
    var lo = 0;
    var hi = first.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (first[mid].start <= time) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    for (var i = lo - 1; i >= 0; i--) {
      final note = first[i];
      if (time < note.end) return note.measureIndex;
      if (note.start < time - _longest) break;
    }
    return null;
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

TempoMap _unfoldedTempoMap(
  Score first,
  List<PlaybackNote> timeline,
  double initialBpm,
) {
  final spans = <TempoSpan>[TempoSpan(Fraction.zero, initialBpm)];
  var current = initialBpm;
  var lastMeasure = -1;
  for (final note in timeline) {
    if (note.measureIndex == lastMeasure) continue;
    lastMeasure = note.measureIndex;
    if (note.measureIndex >= first.measures.length) continue;
    final change = first.measures[note.measureIndex].tempoChange;
    if (change == null || change.quarterBpm == current) continue;
    current = change.quarterBpm;
    if (note.start == Fraction.zero) {
      spans[0] = TempoSpan(Fraction.zero, current);
    } else {
      spans.add(TempoSpan(note.start, current));
    }
  }
  return TempoMap(spans);
}
