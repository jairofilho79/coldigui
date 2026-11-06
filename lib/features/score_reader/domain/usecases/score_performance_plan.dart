import 'dart:math' show max, min;

import 'package:crisp_notation_core/crisp_notation_core.dart';

import '../entities/musescore_performance_metadata.dart';
import '../entities/score_document.dart';
import '../entities/score_playback_diagnostic.dart';

const int _scorePlanTicksPerQuarter = 480;
const int _maximumPlaybackMeasureOccurrences = 10000;

enum ScorePerformanceRouteKind { staff, accompaniment }

class ScorePerformanceRoute {
  const ScorePerformanceRoute({
    required this.kind,
    required this.trackIndex,
    required this.midiChannel,
    this.staffIndex,
  });

  final ScorePerformanceRouteKind kind;
  final int trackIndex;
  final int midiChannel;
  final int? staffIndex;
}

class ScorePerformanceOrigin {
  const ScorePerformanceOrigin({
    required this.staffIndex,
    required this.measureIndex,
    required this.voice,
    this.elementId,
  });

  final int staffIndex;
  final int measureIndex;
  final int voice;
  final String? elementId;
}

class ScorePerformancePitchDuration {
  const ScorePerformancePitchDuration({
    required this.pitch,
    required this.duration,
    required this.attack,
    this.startOffset = Fraction.zero,
    this.sourceDriven = true,
  });

  final Pitch pitch;
  final Fraction duration;
  final bool attack;
  final Fraction startOffset;
  final bool sourceDriven;
}

class ScorePerformanceEvent {
  const ScorePerformanceEvent({
    required this.origin,
    required this.start,
    required this.duration,
    required this.isRest,
    required this.route,
    Fraction? sourceStart,
    Fraction? sourceDuration,
    this.velocity,
    this.sustainedDynamicVelocity,
    this.dynamicTargetVelocity,
    this.explicitVelocity,
    this.pitches = const [],
    this.articulations = const {},
    this.arpeggio,
    this.tremoloStrokes,
    this.tieToNext = false,
    this.showAccidental,
    this.ornament,
    this.ornamentAccidentalAlter,
    this.ornamentUpperPitches = const [],
    this.ornamentLowerPitches = const [],
    this.graceNotes = const [],
    this.graceStyle = GraceStyle.acciaccatura,
    this.graceTiesToMain = const {},
    this.graceParameters = const [],
    this.gracePitchAlterOverrides = const [],
    this.pitchDurations = const [],
    this.chordPitches,
  }) : sourceStart = sourceStart ?? start,
       sourceDuration = sourceDuration ?? duration;

  final ScorePerformanceOrigin origin;
  final Fraction start;
  final Fraction duration;
  final Fraction sourceStart;
  final Fraction sourceDuration;
  final bool isRest;
  final ScorePerformanceRoute? route;
  final int? velocity;
  final int? sustainedDynamicVelocity;
  final int? dynamicTargetVelocity;
  final int? explicitVelocity;
  final List<Pitch> pitches;
  final Set<Articulation> articulations;
  final Arpeggio? arpeggio;
  final int? tremoloStrokes;
  final bool tieToNext;
  final bool? showAccidental;
  final Ornament? ornament;
  final int? ornamentAccidentalAlter;
  final List<Pitch> ornamentUpperPitches;
  final List<Pitch> ornamentLowerPitches;
  final List<Pitch> graceNotes;
  final GraceStyle graceStyle;
  final Set<int> graceTiesToMain;
  final List<MusicXmlGraceMetadata> graceParameters;
  final List<int?> gracePitchAlterOverrides;
  final List<ScorePerformancePitchDuration> pitchDurations;
  final List<Pitch>? chordPitches;

  Fraction get end => start + duration;

  Fraction get highlightEnd {
    var result = end;
    for (final pitchDuration in pitchDurations) {
      final pitchEnd =
          start + pitchDuration.startOffset + pitchDuration.duration;
      if (pitchEnd > result) result = pitchEnd;
    }
    return result;
  }

  Fraction get highlightStart {
    var result = start;
    for (final pitchDuration in pitchDurations) {
      final pitchStart = start + pitchDuration.startOffset;
      if (pitchStart < result) result = pitchStart;
    }
    return result;
  }
}

class ScorePerformanceExpressionCurve {
  const ScorePerformanceExpressionCurve({
    required this.route,
    required this.start,
    required this.end,
    required this.startValue,
    required this.endValue,
  });

  final ScorePerformanceRoute route;
  final Fraction start;
  final Fraction end;
  final int startValue;
  final int endValue;
}

class ScorePerformanceMeasureOccurrence {
  const ScorePerformanceMeasureOccurrence({
    required this.occurrenceIndex,
    required this.measureIndex,
    required this.start,
    required this.end,
  });

  final int occurrenceIndex;
  final int measureIndex;
  final Fraction start;
  final Fraction end;
}

class ScorePerformanceTempoChange {
  const ScorePerformanceTempoChange({
    required this.origin,
    required this.start,
    required this.quarterBpm,
  });

  final ScorePerformanceOrigin origin;
  final Fraction start;
  final double quarterBpm;
}

class ScorePerformanceControlChange {
  const ScorePerformanceControlChange({
    required this.origin,
    required this.start,
    required this.route,
    required this.controller,
    required this.value,
  });

  final ScorePerformanceOrigin origin;
  final Fraction start;
  final ScorePerformanceRoute route;
  final int controller;
  final int value;
}

class ScorePerformanceCapacityException implements Exception {
  const ScorePerformanceCapacityException(
    this.staffCount, {
    required this.maximumStaffCount,
  });

  final int staffCount;
  final int maximumStaffCount;

  @override
  String toString() =>
      'ScorePerformanceCapacityException: $staffCount pautas excedem a '
      'capacidade; selecione ate $maximumStaffCount.';
}

enum ScorePerformanceNavigationIssueCode {
  unresolvedDestination,
  conflictingNavigation,
  invalidNavigation,
  cyclicNavigation,
  measureOccurrenceLimitExceeded,
}

class ScorePerformanceNavigationIssue {
  const ScorePerformanceNavigationIssue({
    required this.code,
    required this.message,
    this.staffIndex,
    this.measureIndex,
  });

  final ScorePerformanceNavigationIssueCode code;
  final String message;
  final int? staffIndex;
  final int? measureIndex;

  @override
  String toString() => '${code.name}: $message';
}

class ScorePerformanceNavigationException implements Exception {
  const ScorePerformanceNavigationException(this.issues);

  final List<ScorePerformanceNavigationIssue> issues;

  @override
  String toString() =>
      'ScorePerformanceNavigationException: ${issues.join('; ')}';
}

class _FermataExtension {
  const _FermataExtension(this.start, this.duration);

  final Fraction start;
  final Fraction duration;
}

class _FermataTiming {
  const _FermataTiming(this.extensions);

  final List<_FermataExtension> extensions;

  Fraction timeAt(Fraction sourceTime) {
    var extension = Fraction.zero;
    for (final fermata in extensions) {
      if (fermata.start >= sourceTime) break;
      extension += fermata.duration;
    }
    return sourceTime + extension;
  }
}

class _GraceMakeTimeExtension {
  const _GraceMakeTimeExtension(this.start, this.duration);

  final Fraction start;
  final Fraction duration;
}

class _GraceMakeTimeTiming {
  const _GraceMakeTimeTiming(this.extensions);

  final List<_GraceMakeTimeExtension> extensions;

  Fraction timeAt(Fraction sourceTime) => _timeAt(sourceTime, inclusive: true);

  Fraction timeBefore(Fraction sourceTime) =>
      _timeAt(sourceTime, inclusive: false);

  Fraction _timeAt(Fraction sourceTime, {required bool inclusive}) {
    var extension = Fraction.zero;
    for (final makeTime in extensions) {
      if (inclusive
          ? makeTime.start > sourceTime
          : makeTime.start >= sourceTime) {
        break;
      }
      extension += makeTime.duration;
    }
    return sourceTime + extension;
  }
}

class ScorePerformancePlan {
  factory ScorePerformancePlan.unavailable(ScoreDocument document) {
    final bpm = document.quarterBpm;
    return ScorePerformancePlan._(
      score: document.score,
      timelines: [for (final _ in document.score.parts) const []],
      linearizedScores: document.score.parts,
      events: const [],
      expressionCurves: const [],
      controlChanges: const [],
      routes: const [],
      staffRoutes: const {},
      chordRoute: null,
      measureOccurrences: const [],
      tempoChanges: [
        ScorePerformanceTempoChange(
          origin: const ScorePerformanceOrigin(
            staffIndex: 0,
            measureIndex: 0,
            voice: 0,
          ),
          start: Fraction.zero,
          quarterBpm: bpm,
        ),
      ],
      tempoMap: TempoMap([TempoSpan(Fraction.zero, bpm)]),
      totalWholeNotes: Fraction.zero,
      quarterBpm: bpm,
      includeChordSymbols: false,
      selectedStaffIndices: const {},
      fermataTiming: const _FermataTiming([]),
      graceMakeTimeTiming: const _GraceMakeTimeTiming([]),
      diagnostics: const [],
    );
  }

  factory ScorePerformancePlan.of(
    MultiPartScore score, {
    double? quarterBpm,
    bool includeChordSymbols = false,
    Set<int>? selectedStaffIndices,
  }) => ScorePerformancePlan._build(
    score,
    quarterBpm: quarterBpm,
    includeChordSymbols: includeChordSymbols,
    selectedStaffIndices: selectedStaffIndices,
  );

  factory ScorePerformancePlan.fromDocument(
    ScoreDocument document, {
    double? quarterBpm,
    bool includeChordSymbols = false,
    Set<int>? selectedStaffIndices,
  }) => ScorePerformancePlan._build(
    document.score,
    quarterBpm: quarterBpm ?? document.quarterBpm,
    includeChordSymbols: includeChordSymbols,
    selectedStaffIndices: selectedStaffIndices,
    museScorePerformance: document.museScorePerformance,
    musicXmlPerformance: document.musicXmlPerformance,
    musicXmlPartStaffIndices: _musicXmlPartStaffIndices(document),
  );

  factory ScorePerformancePlan._build(
    MultiPartScore score, {
    double? quarterBpm,
    bool includeChordSymbols = false,
    Set<int>? selectedStaffIndices,
    MuseScorePerformanceMetadata? museScorePerformance,
    MusicXmlPerformanceMetadata? musicXmlPerformance,
    List<List<int>>? musicXmlPartStaffIndices,
  }) {
    final selected = selectedStaffIndices == null
        ? {for (var i = 0; i < score.parts.length; i++) i}
        : {...selectedStaffIndices};
    for (final index in selected) {
      RangeError.checkValidIndex(index, score.parts, 'selectedStaffIndices');
    }

    final hasChordSymbols = score.parts.any(
      (part) => part.chordSymbols.isNotEmpty,
    );
    final maximumStaffCount = includeChordSymbols && hasChordSymbols ? 14 : 15;
    if (selected.length > maximumStaffCount) {
      throw ScorePerformanceCapacityException(
        selected.length,
        maximumStaffCount: maximumStaffCount,
      );
    }
    final selectedStaffOrder = selected.toList()..sort();
    final staffRoutes = <int, ScorePerformanceRoute>{};
    final routes = <ScorePerformanceRoute>[];
    for (final (trackIndex, staffIndex) in selectedStaffOrder.indexed) {
      final route = ScorePerformanceRoute(
        kind: ScorePerformanceRouteKind.staff,
        staffIndex: staffIndex,
        trackIndex: trackIndex,
        midiChannel: scoreMidiChannelForStaff(
          includeChordSymbols && hasChordSymbols ? trackIndex : staffIndex,
        ),
      );
      staffRoutes[staffIndex] = route;
      routes.add(route);
    }

    final chordRoute = includeChordSymbols && hasChordSymbols
        ? ScorePerformanceRoute(
            kind: ScorePerformanceRouteKind.accompaniment,
            trackIndex: routes.length,
            midiChannel: 15,
          )
        : null;
    if (chordRoute != null) routes.add(chordRoute);

    final primaryScore = score.parts.first;
    final measureOrder = _performanceMeasureOrder(
      primaryScore,
      museScorePerformance: museScorePerformance,
      musicXmlPerformance: musicXmlPerformance,
    );
    final durations = _measureDurations(primaryScore);
    final occurrences = <ScorePerformanceMeasureOccurrence>[];
    var occurrenceStart = Fraction.zero;
    for (final (occurrenceIndex, measureIndex) in measureOrder.indexed) {
      if (measureIndex < 0 || measureIndex >= durations.length) continue;
      final end = occurrenceStart + durations[measureIndex];
      occurrences.add(
        ScorePerformanceMeasureOccurrence(
          occurrenceIndex: occurrenceIndex,
          measureIndex: measureIndex,
          start: occurrenceStart,
          end: end,
        ),
      );
      occurrenceStart = end;
    }
    final linearizedScores = [
      for (final part in score.parts)
        _linearizedScore(part, primaryScore, occurrences),
    ];
    final sourceTimelines = [
      for (final linearizedScore in linearizedScores)
        [
          for (final note in playbackTimeline(
            linearizedScore,
            expandRepeats: false,
            voiceChordSymbols: includeChordSymbols,
          ))
            if (note.measureIndex < occurrences.length)
              PlaybackNote(
                elementId: note.elementId,
                start: note.start,
                duration: note.duration,
                isRest: note.isRest,
                voice: note.voice,
                measureIndex: occurrences[note.measureIndex].measureIndex,
                chordPitches: note.chordPitches,
              ),
        ],
    ];
    final events = <ScorePerformanceEvent>[];
    for (final (staffIndex, linearizedScore) in linearizedScores.indexed) {
      events.addAll(
        _performanceStaffEvents(
          linearizedScore,
          staffIndex,
          staffRoutes[staffIndex],
          occurrences,
          musicXmlPerformance: musicXmlPerformance,
          musicXmlPartStaffIndices: musicXmlPartStaffIndices,
        ),
      );
      if (includeChordSymbols && chordRoute != null) {
        for (final note in sourceTimelines[staffIndex]) {
          if (note.chordPitches == null) continue;
          events.add(
            ScorePerformanceEvent(
              origin: ScorePerformanceOrigin(
                staffIndex: staffIndex,
                measureIndex: note.measureIndex,
                voice: note.voice,
                elementId: note.elementId,
              ),
              start: note.start,
              duration: note.duration,
              isRest: note.isRest,
              route: chordRoute,
              chordPitches: note.chordPitches,
            ),
          );
        }
      }
    }
    events.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      final byStaff = a.origin.staffIndex.compareTo(b.origin.staffIndex);
      return byStaff != 0 ? byStaff : a.origin.voice.compareTo(b.origin.voice);
    });
    final graceMakeTimeTiming = _buildGraceMakeTimeTiming(events);
    final fermataTiming = _buildFermataTiming(
      events,
      occurrences,
      musicXmlPerformance: musicXmlPerformance,
      musicXmlPartStaffIndices: musicXmlPartStaffIndices,
      graceMakeTimeTiming: graceMakeTimeTiming,
    );
    Fraction performanceTimeAt(Fraction sourceTime) =>
        fermataTiming.timeAt(graceMakeTimeTiming.timeAt(sourceTime));
    final performanceOccurrences = [
      for (final occurrence in occurrences)
        ScorePerformanceMeasureOccurrence(
          occurrenceIndex: occurrence.occurrenceIndex,
          measureIndex: occurrence.measureIndex,
          start: fermataTiming.timeAt(
            graceMakeTimeTiming.timeBefore(occurrence.start),
          ),
          end: fermataTiming.timeAt(
            graceMakeTimeTiming.timeBefore(occurrence.end),
          ),
        ),
    ];
    final timedTimelines = [
      for (final timeline in sourceTimelines)
        [
          for (final note in timeline)
            PlaybackNote(
              elementId: note.elementId,
              start: performanceTimeAt(note.start),
              duration:
                  fermataTiming.timeAt(
                    graceMakeTimeTiming.timeBefore(note.start + note.duration),
                  ) -
                  performanceTimeAt(note.start),
              isRest: note.isRest,
              voice: note.voice,
              measureIndex: note.measureIndex,
              chordPitches: note.chordPitches,
            ),
        ],
    ];
    final timedEvents = [
      for (final event in events)
        _withEventTiming(
          event,
          start: performanceTimeAt(event.sourceStart),
          end: fermataTiming.timeAt(
            graceMakeTimeTiming.timeBefore(
              event.sourceStart + event.sourceDuration,
            ),
          ),
        ),
    ];
    final eventsWithDynamics = _applyPerformanceDynamics(
      score,
      timedEvents,
      musicXmlPerformance: musicXmlPerformance,
      musicXmlPartStaffIndices: musicXmlPartStaffIndices,
      sourceOccurrences: occurrences,
      performanceTimeAt: performanceTimeAt,
    );
    final eventsWithOrnamentPitches = _resolveOrnamentPitches(
      score,
      eventsWithDynamics,
      occurrences,
    );
    final eventsWithGracePitches = _resolveGracePitches(
      score,
      eventsWithOrnamentPitches,
      occurrences,
    );
    final eventsWithTies = _applyTiedPitchDurations(eventsWithGracePitches);
    final eventsWithGraces = _applyGracePitchDurations(eventsWithTies);
    final eventsWithOrnaments = _applyOrnamentPitchDurations(eventsWithGraces);
    final eventsWithArpeggios = _applyArpeggioPitchDurations(
      eventsWithOrnaments,
    );
    final eventsWithTremolos = _applyTremoloPitchDurations(eventsWithArpeggios);
    final expressionCurves = _performanceExpressionCurves(
      score,
      eventsWithTremolos,
      staffRoutes,
      chordRoute,
    );
    final totalWholeNotes = performanceOccurrences.isEmpty
        ? Fraction.zero
        : performanceOccurrences.last.end;
    final controlChanges = _performancePedalControlChanges(
      score,
      eventsWithTremolos,
      staffRoutes,
      totalWholeNotes,
    );
    final diagnostics = _performanceDiagnostics(
      score,
      eventsWithTremolos,
      selected,
      musicXmlPerformance: musicXmlPerformance,
      musicXmlPartStaffIndices: musicXmlPartStaffIndices,
    );

    final initialBpm = quarterBpm ?? score.parts.first.tempo?.quarterBpm ?? 120;
    final tempoChanges = _tempoChanges(
      score.parts.first,
      performanceOccurrences,
      initialBpm,
    );
    final tempoMap = TempoMap([
      for (final change in tempoChanges)
        TempoSpan(change.start, change.quarterBpm),
    ]);

    return ScorePerformancePlan._(
      score: score,
      timelines: [
        for (final timeline in timedTimelines) List.unmodifiable(timeline),
      ],
      linearizedScores: List.unmodifiable(linearizedScores),
      events: List.unmodifiable(eventsWithTremolos),
      expressionCurves: List.unmodifiable(expressionCurves),
      controlChanges: List.unmodifiable(controlChanges),
      routes: List.unmodifiable(routes),
      staffRoutes: Map.unmodifiable(staffRoutes),
      chordRoute: chordRoute,
      measureOccurrences: List.unmodifiable(performanceOccurrences),
      tempoChanges: List.unmodifiable(tempoChanges),
      tempoMap: tempoMap,
      totalWholeNotes: totalWholeNotes,
      quarterBpm: initialBpm,
      includeChordSymbols: includeChordSymbols,
      selectedStaffIndices: Set.unmodifiable(selected),
      fermataTiming: fermataTiming,
      graceMakeTimeTiming: graceMakeTimeTiming,
      diagnostics: List.unmodifiable(diagnostics),
    );
  }

  const ScorePerformancePlan._({
    required this.score,
    required this.timelines,
    required this._linearizedScores,
    required this.events,
    required this.expressionCurves,
    required this.controlChanges,
    required this.routes,
    required this.staffRoutes,
    required this.chordRoute,
    required this.measureOccurrences,
    required this.tempoChanges,
    required this.tempoMap,
    required this.totalWholeNotes,
    required this.quarterBpm,
    required this.includeChordSymbols,
    required this.selectedStaffIndices,
    required this._fermataTiming,
    required this._graceMakeTimeTiming,
    required this.diagnostics,
  });

  final MultiPartScore score;
  final List<List<PlaybackNote>> timelines;
  final List<Score> _linearizedScores;
  final List<ScorePerformanceEvent> events;
  final List<ScorePerformanceExpressionCurve> expressionCurves;
  final List<ScorePerformanceControlChange> controlChanges;
  final List<ScorePerformanceRoute> routes;
  final Map<int, ScorePerformanceRoute> staffRoutes;
  final ScorePerformanceRoute? chordRoute;
  final List<ScorePerformanceMeasureOccurrence> measureOccurrences;
  final List<ScorePerformanceTempoChange> tempoChanges;
  final TempoMap tempoMap;
  final Fraction totalWholeNotes;
  final double quarterBpm;
  final bool includeChordSymbols;
  final Set<int> selectedStaffIndices;
  final _FermataTiming _fermataTiming;
  final _GraceMakeTimeTiming _graceMakeTimeTiming;
  final List<ScorePlaybackDiagnostic> diagnostics;

  Fraction get totalDurationWholeNotes => totalWholeNotes;

  Fraction playbackTimeForSource(Fraction sourceTime) =>
      _fermataTiming.timeAt(_graceMakeTimeTiming.timeAt(sourceTime));

  /// A repeat- and navigation-free score whose measure order matches this
  /// plan. MIDI generation uses it to keep note serialization on this shared
  /// occurrence sequence.
  Score linearizedScoreForStaff(int staffIndex) {
    RangeError.checkValidIndex(staffIndex, _linearizedScores, 'staffIndex');
    return _linearizedScores[staffIndex];
  }
}

int scoreMidiChannelForStaff(int staffIndex) {
  RangeError.checkNotNegative(staffIndex, 'staffIndex');
  final slot = staffIndex % 15;
  return slot >= 9 ? slot + 1 : slot;
}

List<ScorePerformanceEvent> _performanceStaffEvents(
  Score linearizedScore,
  int staffIndex,
  ScorePerformanceRoute? route,
  List<ScorePerformanceMeasureOccurrence> occurrences, {
  MusicXmlPerformanceMetadata? musicXmlPerformance,
  List<List<int>>? musicXmlPartStaffIndices,
}) {
  final events = <ScorePerformanceEvent>[];
  var meter = linearizedScore.timeSignature;
  for (final (occurrenceIndex, measure) in linearizedScore.measures.indexed) {
    if (occurrenceIndex >= occurrences.length) continue;
    meter = measure.timeChange ?? meter;
    final occurrence = occurrences[occurrenceIndex];
    final capacity = measure.capacityGiven(meter);
    final voices = [
      measure.elements,
      measure.voice2,
      measure.voice3,
      measure.voice4,
    ];
    for (final (voice, elements) in voices.indexed) {
      final isBarRest =
          elements.length == 1 &&
          elements.single is RestElement &&
          !(elements.single as RestElement).hidden &&
          elements.single.duration.base == DurationBase.whole &&
          elements.single.duration.dots == 0;
      var sourceStart = occurrence.start;
      for (var index = 0; index < elements.length; index++) {
        final element = elements[index];
        final duration = isBarRest && capacity != null
            ? capacity
            : measure.effectiveDurationAt(index, voice: voice);
        final note = element is NoteElement ? element : null;
        final localStart = sourceStart - occurrence.start;
        final graceParameters = note == null
            ? const <MusicXmlGraceMetadata>[]
            : _musicXmlGraceParametersForEvent(
                musicXmlPerformance,
                musicXmlPartStaffIndices,
                occurrence,
                staffIndex,
                voice,
                localStart,
                note.graceNotes.length,
              );
        final ornamentMetadata = note?.ornament == null
            ? null
            : _musicXmlOrnamentForEvent(
                musicXmlPerformance,
                musicXmlPartStaffIndices,
                occurrence,
                staffIndex,
                voice,
                localStart,
              );
        final tremoloMetadata = note == null
            ? null
            : _musicXmlTremoloForEvent(
                musicXmlPerformance,
                musicXmlPartStaffIndices,
                occurrence,
                staffIndex,
                voice,
                localStart,
              );
        final int? tremoloStrokes;
        if (tremoloMetadata == null) {
          tremoloStrokes = note?.tremolo;
        } else if (tremoloMetadata.rawType != null &&
            tremoloMetadata.rawType != 'single') {
          tremoloStrokes = null;
        } else if (tremoloMetadata.rawStrokes != null) {
          tremoloStrokes = tremoloMetadata.strokes;
        } else {
          tremoloStrokes = 3;
        }
        events.add(
          ScorePerformanceEvent(
            origin: ScorePerformanceOrigin(
              staffIndex: staffIndex,
              measureIndex: occurrence.measureIndex,
              voice: voice,
              elementId: element.id,
            ),
            start: sourceStart,
            duration: duration,
            sourceStart: sourceStart,
            sourceDuration: duration,
            isRest: element is RestElement,
            route: route,
            explicitVelocity: note?.velocity,
            pitches: note?.pitches ?? const [],
            articulations: note?.articulations ?? const {},
            arpeggio: note?.arpeggio,
            tremoloStrokes: tremoloStrokes,
            tieToNext: note?.tieToNext ?? false,
            showAccidental: note?.showAccidental,
            ornament: note?.ornament,
            ornamentAccidentalAlter:
                ornamentMetadata?.accidentalAlter ??
                note?.ornament?.trillAccidentalAlter,
            graceNotes: note?.graceNotes ?? const [],
            graceStyle: note?.graceStyle ?? GraceStyle.acciaccatura,
            graceTiesToMain: note?.graceTiesToMain ?? const {},
            graceParameters: graceParameters,
            gracePitchAlterOverrides: [
              for (final parameter in graceParameters) parameter.pitchAlter,
            ],
          ),
        );
        sourceStart += duration;
      }
    }
  }
  return events;
}

List<ScorePlaybackDiagnostic> _performanceDiagnostics(
  MultiPartScore score,
  List<ScorePerformanceEvent> events,
  Set<int> selectedStaffIndices, {
  MusicXmlPerformanceMetadata? musicXmlPerformance,
  List<List<int>>? musicXmlPartStaffIndices,
}) {
  final diagnostics = <ScorePlaybackDiagnostic>[];
  final seen = <String>{};

  void add(
    ScorePlaybackDiagnosticCode code, {
    int? staffIndex,
    int? measureIndex,
    Articulation? articulation,
    int? value,
    String? signal,
  }) {
    if (staffIndex != null && !selectedStaffIndices.contains(staffIndex)) {
      return;
    }
    final key =
        '$code|$staffIndex|$measureIndex|${articulation?.name}|$value|$signal';
    if (!seen.add(key)) return;
    diagnostics.add(
      ScorePlaybackDiagnostic(
        code: code,
        staffIndex: staffIndex,
        measureIndex: measureIndex,
        articulation: articulation,
        value: value,
        signal: signal,
      ),
    );
  }

  for (final event in events) {
    if (!selectedStaffIndices.contains(event.origin.staffIndex) ||
        event.isRest ||
        event.chordPitches != null) {
      continue;
    }
    for (final articulation in event.articulations) {
      if (articulation == Articulation.breath ||
          articulation == Articulation.upBow ||
          articulation == Articulation.downBow) {
        add(
          ScorePlaybackDiagnosticCode.unsupportedArticulation,
          staffIndex: event.origin.staffIndex,
          measureIndex: event.origin.measureIndex,
          articulation: articulation,
        );
      }
    }
    final strokes = event.tremoloStrokes;
    if (strokes != null && !_isSupportedTremoloStrokeCount(strokes)) {
      add(
        ScorePlaybackDiagnosticCode.unsupportedTremoloStrokes,
        staffIndex: event.origin.staffIndex,
        measureIndex: event.origin.measureIndex,
        value: strokes,
      );
    }
  }

  for (final (staffIndex, part) in score.parts.indexed) {
    if (!selectedStaffIndices.contains(staffIndex)) continue;
    final staffEvents = events
        .where((event) => event.origin.staffIndex == staffIndex)
        .toList();
    for (final hairpin in part.hairpins) {
      final starts = staffEvents
          .where((event) => event.origin.elementId == hairpin.startId)
          .toList();
      final ends = staffEvents
          .where((event) => event.origin.elementId == hairpin.endId)
          .toList();
      final hasEndpoint = starts.any(
        (start) => ends.any((end) => end.start > start.start),
      );
      if (!hasEndpoint) {
        add(
          ScorePlaybackDiagnosticCode.incompleteHairpin,
          staffIndex: staffIndex,
          measureIndex: starts.firstOrNull?.origin.measureIndex,
        );
      }
    }
    for (final pedal in part.pedals) {
      final start = staffEvents
          .where((event) => event.origin.elementId == pedal.startId)
          .firstOrNull;
      final hasRelease = staffEvents.any(
        (event) =>
            event.origin.elementId == pedal.endId &&
            start != null &&
            event.start >= start.start,
      );
      if (start == null || !hasRelease) {
        final end = staffEvents
            .where((event) => event.origin.elementId == pedal.endId)
            .firstOrNull;
        add(
          ScorePlaybackDiagnosticCode.incompletePedal,
          staffIndex: staffIndex,
          measureIndex: start?.origin.measureIndex ?? end?.origin.measureIndex,
        );
      }
    }
  }

  double scoreTempoAt(int measureIndex) {
    final firstPart = score.parts.first;
    var bpm = firstPart.tempo?.quarterBpm ?? 120;
    for (var index = 0; index <= measureIndex; index++) {
      if (index >= firstPart.measures.length) break;
      bpm = firstPart.measures[index].tempoChange?.quarterBpm ?? bpm;
    }
    return bpm;
  }

  final performance = musicXmlPerformance;
  if (performance != null) {
    for (final ornament in performance.ornaments) {
      for (final name in ornament.ornamentNames) {
        if (const {
          'trill-mark',
          'mordent',
          'inverted-mordent',
          'turn',
          'inverted-turn',
        }.contains(name)) {
          continue;
        }
        for (final staffIndex in _musicXmlDiagnosticStaffIndices(
          ornament.origin,
          score.parts.length,
          musicXmlPartStaffIndices,
        )) {
          add(
            ScorePlaybackDiagnosticCode.unsupportedOrnament,
            staffIndex: staffIndex,
            measureIndex: ornament.origin.measureIndex,
            signal: name,
          );
        }
      }
    }
    for (final tremolo in performance.tremolos) {
      final type = tremolo.rawType ?? 'single';
      final code = type != 'single'
          ? ScorePlaybackDiagnosticCode.unsupportedTremoloType
          : tremolo.rawStrokes != null && tremolo.strokes == null
          ? ScorePlaybackDiagnosticCode.unsupportedTremoloStrokes
          : tremolo.strokes != null &&
                !_isSupportedTremoloStrokeCount(tremolo.strokes)
          ? ScorePlaybackDiagnosticCode.unsupportedTremoloStrokes
          : null;
      if (code == null) continue;
      for (final staffIndex in _musicXmlDiagnosticStaffIndices(
        tremolo.origin,
        score.parts.length,
        musicXmlPartStaffIndices,
      )) {
        add(
          code,
          staffIndex: staffIndex,
          measureIndex: tremolo.origin.measureIndex,
          value: tremolo.strokes,
          signal: type != 'single' ? type : tremolo.rawStrokes,
        );
      }
    }
    for (final direction in performance.directions) {
      for (final mark in direction.dynamicMarks) {
        if (_dynamicLevelForName(mark) != null) continue;
        for (final staffIndex in _musicXmlDiagnosticStaffIndices(
          direction.origin,
          score.parts.length,
          musicXmlPartStaffIndices,
        )) {
          add(
            ScorePlaybackDiagnosticCode.unrecognizedDynamic,
            staffIndex: staffIndex,
            measureIndex: direction.origin.measureIndex,
            signal: mark,
          );
        }
      }
    }
    for (final sound in performance.sounds) {
      if (sound.rawDynamics != null && sound.dynamics == null) {
        for (final staffIndex in _musicXmlDiagnosticStaffIndices(
          sound.origin,
          score.parts.length,
          musicXmlPartStaffIndices,
        )) {
          add(
            ScorePlaybackDiagnosticCode.unrecognizedDynamic,
            staffIndex: staffIndex,
            measureIndex: sound.origin.measureIndex,
            signal: sound.rawDynamics,
          );
        }
      }

      final rawTempo = sound.rawTempo;
      if (rawTempo == null) continue;
      final tempo = sound.tempo;
      final tempoCode = tempo == null || !tempo.isFinite || tempo <= 0
          ? ScorePlaybackDiagnosticCode.invalidTempo
          : sound.origin.measureIndex < 0 ||
                sound.origin.measureIndex >=
                    score.parts.first.measures.length ||
                scoreTempoAt(sound.origin.measureIndex) != tempo
          ? ScorePlaybackDiagnosticCode.unsupportedTempo
          : null;
      if (tempoCode == null) continue;
      for (final staffIndex in _musicXmlDiagnosticStaffIndices(
        sound.origin,
        score.parts.length,
        musicXmlPartStaffIndices,
      )) {
        add(
          tempoCode,
          staffIndex: staffIndex,
          measureIndex: sound.origin.measureIndex,
          signal: rawTempo,
        );
      }
    }
  }
  return diagnostics;
}

List<int?> _musicXmlDiagnosticStaffIndices(
  MusicXmlPerformanceOrigin origin,
  int scoreStaffCount,
  List<List<int>>? partStaffIndices,
) {
  if (origin.staffIndex != null) return [origin.staffIndex];
  if (partStaffIndices != null &&
      origin.partIndex >= 0 &&
      origin.partIndex < partStaffIndices.length) {
    return partStaffIndices[origin.partIndex];
  }
  if (origin.partIndex >= 0 && origin.partIndex < scoreStaffCount) {
    return [origin.partIndex];
  }
  return [null];
}

List<ScorePerformanceControlChange> _performancePedalControlChanges(
  MultiPartScore score,
  List<ScorePerformanceEvent> events,
  Map<int, ScorePerformanceRoute> staffRoutes,
  Fraction totalWholeNotes,
) {
  final changes = <ScorePerformanceControlChange>[];
  for (final (staffIndex, part) in score.parts.indexed) {
    final route = staffRoutes[staffIndex];
    if (route == null || part.pedals.isEmpty) continue;
    final staffEvents = events
        .where((event) => event.origin.staffIndex == staffIndex)
        .toList();
    final edges =
        <({Fraction time, int delta, ScorePerformanceOrigin origin})>[];
    for (final pedal in part.pedals) {
      final starts =
          staffEvents
              .where((event) => event.origin.elementId == pedal.startId)
              .toList()
            ..sort((a, b) => a.sourceStart.compareTo(b.sourceStart));
      final ends =
          staffEvents
              .where((event) => event.origin.elementId == pedal.endId)
              .toList()
            ..sort((a, b) => a.sourceStart.compareTo(b.sourceStart));
      for (final start in starts) {
        ScorePerformanceEvent? end;
        for (final candidate in ends) {
          if (candidate.sourceStart >= start.sourceStart) {
            end = candidate;
            break;
          }
        }
        if (end == null) continue;
        final startTime = start.start;
        final endTime = end.highlightEnd > totalWholeNotes
            ? totalWholeNotes
            : end.highlightEnd;
        if (startTime >= totalWholeNotes || endTime <= startTime) continue;
        edges
          ..add((time: startTime, delta: 1, origin: start.origin))
          ..add((time: endTime, delta: -1, origin: end.origin));
      }
    }
    edges.sort((a, b) => a.time.compareTo(b.time));
    var activePedals = 0;
    var edgeIndex = 0;
    while (edgeIndex < edges.length) {
      final time = edges[edgeIndex].time;
      var endIndex = edgeIndex + 1;
      while (endIndex < edges.length && edges[endIndex].time == time) {
        endIndex++;
      }
      final sameTime = edges.sublist(edgeIndex, endIndex);
      final nextActive =
          activePedals + sameTime.fold<int>(0, (sum, edge) => sum + edge.delta);
      if (activePedals == 0 && nextActive > 0) {
        final origin = sameTime.firstWhere((edge) => edge.delta > 0).origin;
        changes.add(
          ScorePerformanceControlChange(
            origin: origin,
            start: time,
            route: route,
            controller: 64,
            value: 127,
          ),
        );
      } else if (activePedals > 0 && nextActive == 0) {
        final origin = sameTime.firstWhere((edge) => edge.delta < 0).origin;
        changes.add(
          ScorePerformanceControlChange(
            origin: origin,
            start: time,
            route: route,
            controller: 64,
            value: 0,
          ),
        );
      }
      activePedals = nextActive;
      edgeIndex = endIndex;
    }
  }
  return changes;
}

List<MusicXmlGraceMetadata> _musicXmlGraceParametersForEvent(
  MusicXmlPerformanceMetadata? performance,
  List<List<int>>? partStaffIndices,
  ScorePerformanceMeasureOccurrence occurrence,
  int staffIndex,
  int voiceIndex,
  Fraction localStart,
  int graceCount,
) {
  if (graceCount == 0 || performance == null) return const [];
  final matching = performance.graceNotes
      .where(
        (grace) => _musicXmlOriginMatchesEvent(
          grace.origin,
          partStaffIndices,
          occurrence,
          staffIndex,
          voiceIndex,
          localStart,
        ),
      )
      .toList();
  return matching.length <= graceCount
      ? matching
      : matching.take(graceCount).toList();
}

MusicXmlOrnamentMetadata? _musicXmlOrnamentForEvent(
  MusicXmlPerformanceMetadata? performance,
  List<List<int>>? partStaffIndices,
  ScorePerformanceMeasureOccurrence occurrence,
  int staffIndex,
  int voiceIndex,
  Fraction localStart,
) {
  if (performance == null) return null;
  for (final ornament in performance.ornaments) {
    if (_musicXmlOriginMatchesEvent(
      ornament.origin,
      partStaffIndices,
      occurrence,
      staffIndex,
      voiceIndex,
      localStart,
    )) {
      return ornament;
    }
  }
  return null;
}

MusicXmlTremoloMetadata? _musicXmlTremoloForEvent(
  MusicXmlPerformanceMetadata? performance,
  List<List<int>>? partStaffIndices,
  ScorePerformanceMeasureOccurrence occurrence,
  int staffIndex,
  int voiceIndex,
  Fraction localStart,
) {
  if (performance == null) return null;
  for (final tremolo in performance.tremolos) {
    if (_musicXmlOriginMatchesEvent(
      tremolo.origin,
      partStaffIndices,
      occurrence,
      staffIndex,
      voiceIndex,
      localStart,
    )) {
      return tremolo;
    }
  }
  return null;
}

bool _musicXmlOriginMatchesEvent(
  MusicXmlPerformanceOrigin origin,
  List<List<int>>? partStaffIndices,
  ScorePerformanceMeasureOccurrence occurrence,
  int staffIndex,
  int voiceIndex,
  Fraction localStart,
) {
  if (origin.measureIndex != occurrence.measureIndex ||
      _musicXmlWholeNotes(origin.onset) != localStart) {
    return false;
  }
  if (origin.staffIndex != null) {
    if (origin.staffIndex != staffIndex) return false;
  } else {
    final staffIndices =
        partStaffIndices != null &&
            origin.partIndex >= 0 &&
            origin.partIndex < partStaffIndices.length
        ? partStaffIndices[origin.partIndex]
        : [origin.partIndex];
    if (!staffIndices.contains(staffIndex)) return false;
  }
  final sourceVoice = int.tryParse(origin.voice ?? '');
  return sourceVoice == null ||
      sourceVoice < 1 ||
      sourceVoice > 4 ||
      voiceIndex == sourceVoice - 1;
}

ScorePerformanceEvent _withEventTiming(
  ScorePerformanceEvent event, {
  required Fraction start,
  required Fraction end,
}) => ScorePerformanceEvent(
  origin: event.origin,
  start: start,
  duration: end - start,
  sourceStart: event.sourceStart,
  sourceDuration: event.sourceDuration,
  isRest: event.isRest,
  route: event.route,
  velocity: event.velocity,
  sustainedDynamicVelocity: event.sustainedDynamicVelocity,
  dynamicTargetVelocity: event.dynamicTargetVelocity,
  explicitVelocity: event.explicitVelocity,
  pitches: event.pitches,
  articulations: event.articulations,
  arpeggio: event.arpeggio,
  tremoloStrokes: event.tremoloStrokes,
  tieToNext: event.tieToNext,
  showAccidental: event.showAccidental,
  ornament: event.ornament,
  ornamentAccidentalAlter: event.ornamentAccidentalAlter,
  ornamentUpperPitches: event.ornamentUpperPitches,
  ornamentLowerPitches: event.ornamentLowerPitches,
  graceNotes: event.graceNotes,
  graceStyle: event.graceStyle,
  graceTiesToMain: event.graceTiesToMain,
  graceParameters: event.graceParameters,
  gracePitchAlterOverrides: event.gracePitchAlterOverrides,
  pitchDurations: event.pitchDurations,
  chordPitches: event.chordPitches,
);

_FermataTiming _buildFermataTiming(
  List<ScorePerformanceEvent> events,
  List<ScorePerformanceMeasureOccurrence> occurrences, {
  MusicXmlPerformanceMetadata? musicXmlPerformance,
  List<List<int>>? musicXmlPartStaffIndices,
  required _GraceMakeTimeTiming graceMakeTimeTiming,
}) {
  final durationsByStart = <Fraction, Fraction>{};
  void addFermata(Fraction start, Fraction duration) {
    if (duration <= Fraction.zero) return;
    final current = durationsByStart[start];
    if (current == null || duration > current) {
      durationsByStart[start] = duration;
    }
  }

  for (final event in events) {
    if (!event.isRest &&
        event.chordPitches == null &&
        event.articulations.contains(Articulation.fermata)) {
      addFermata(
        graceMakeTimeTiming.timeAt(event.sourceStart),
        event.sourceDuration,
      );
    }
  }

  for (final fermata
      in musicXmlPerformance?.fermatas ?? const <MusicXmlFermataMetadata>[]) {
    if (!fermata.isRest) continue;
    final origin = fermata.origin;
    final staffIndices = origin.staffIndex == null
        ? musicXmlPartStaffIndices != null &&
                  origin.partIndex >= 0 &&
                  origin.partIndex < musicXmlPartStaffIndices.length
              ? musicXmlPartStaffIndices[origin.partIndex]
              : origin.partIndex >= 0
              ? [origin.partIndex]
              : const <int>[]
        : [origin.staffIndex!];
    final voiceIndex = int.tryParse(origin.voice ?? '');
    final sourceOffset = _musicXmlWholeNotes(origin.onset);
    for (final occurrence in occurrences) {
      if (occurrence.measureIndex != origin.measureIndex) continue;
      final sourceStart = occurrence.start + sourceOffset;
      for (final event in events) {
        if (!event.isRest ||
            event.origin.measureIndex != origin.measureIndex ||
            event.sourceStart != sourceStart ||
            !staffIndices.contains(event.origin.staffIndex) ||
            (voiceIndex != null &&
                voiceIndex >= 1 &&
                voiceIndex <= 4 &&
                event.origin.voice != voiceIndex - 1)) {
          continue;
        }
        addFermata(
          graceMakeTimeTiming.timeAt(event.sourceStart),
          event.sourceDuration,
        );
      }
    }
  }

  final extensions =
      durationsByStart.entries
          .map((entry) => _FermataExtension(entry.key, entry.value))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  return _FermataTiming(List.unmodifiable(extensions));
}

_GraceMakeTimeTiming _buildGraceMakeTimeTiming(
  List<ScorePerformanceEvent> events,
) {
  final durationsByStart = <Fraction, Fraction>{};
  for (final event in events) {
    if (event.graceNotes.isEmpty ||
        !event.graceParameters.any(
          (parameter) => parameter.makeTimeQuarterNotes != null,
        )) {
      continue;
    }
    final duration = event.graceParameters.fold(
      Fraction.zero,
      (total, parameter) =>
          total + _musicXmlWholeNotes(parameter.makeTimeQuarterNotes),
    );
    if (duration <= Fraction.zero) continue;
    final current = durationsByStart[event.sourceStart];
    if (current == null || duration > current) {
      durationsByStart[event.sourceStart] = duration;
    }
  }
  final extensions =
      durationsByStart.entries
          .map((entry) => _GraceMakeTimeExtension(entry.key, entry.value))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  return _GraceMakeTimeTiming(List.unmodifiable(extensions));
}

Score _linearizedScore(
  Score staffScore,
  Score primaryScore,
  List<ScorePerformanceMeasureOccurrence> occurrences,
) {
  final measures = <Measure>[];
  for (final occurrence in occurrences) {
    final index = occurrence.measureIndex;
    final structure = index < staffScore.measures.length
        ? staffScore.measures[index]
        : const Measure([]);
    final sourceIndex = _measureRepeatSourceIndex(primaryScore, index);
    final content = sourceIndex < staffScore.measures.length
        ? staffScore.measures[sourceIndex]
        : const Measure([]);
    measures.add(
      _linearizedMeasure(content, structure, occurrence.end - occurrence.start),
    );
  }
  return staffScore.copyWith(measures: measures);
}

Measure _linearizedMeasure(
  Measure content,
  Measure structure,
  Fraction duration,
) {
  final voices = [
    content.elements.toList(),
    content.voice2.toList(),
    content.voice3.toList(),
    content.voice4.toList(),
  ];
  final tuplets = content.tuplets.toList();
  var longest = Fraction.zero;
  var longestVoice = 0;
  for (final (voice, elements) in voices.indexed) {
    var end = Fraction.zero;
    if (elements.length == 1 && elements.single is RestElement) {
      end = duration;
    } else {
      for (var index = 0; index < elements.length; index++) {
        end += content.effectiveDurationAt(index, voice: voice);
      }
    }
    if (end > longest) {
      longest = end;
      longestVoice = voice;
    }
  }
  if (duration > longest) {
    _appendPadding(
      voices[longestVoice],
      tuplets,
      duration - longest,
      voiceIndex: longestVoice,
    );
  }
  return Measure(
    voices[0],
    voice2: voices[1],
    voice3: voices[2],
    voice4: voices[3],
    tuplets: tuplets,
    clefChange: structure.clefChange,
    inlineClefs: structure.inlineClefs,
    keyChange: structure.keyChange,
    timeChange: structure.timeChange,
    tempoChange: structure.tempoChange,
    multiRest: structure.multiRest,
    barline: BarlineStyle.normal,
    pickup: structure.pickup,
    actualDuration: duration > Fraction.zero ? duration : null,
  );
}

void _appendPadding(
  List<MusicElement> voice,
  List<TupletSpan> tuplets,
  Fraction duration, {
  required int voiceIndex,
}) {
  var remaining = duration;
  final wholeNotes = remaining.numerator ~/ remaining.denominator;
  for (var i = 0; i < wholeNotes; i++) {
    voice.add(RestElement(NoteDuration.whole));
  }
  remaining = Fraction(
    remaining.numerator - wholeNotes * remaining.denominator,
    remaining.denominator,
  );
  if (remaining <= Fraction.zero) return;
  final index = voice.length;
  voice.add(RestElement(NoteDuration.whole));
  if (remaining.denominator > 1) {
    tuplets.add(
      TupletSpan(
        index,
        index,
        actual: remaining.denominator,
        normal: remaining.numerator,
        voice: voiceIndex,
      ),
    );
  }
}

List<ScorePerformanceEvent> _applyPerformanceDynamics(
  MultiPartScore score,
  List<ScorePerformanceEvent> events, {
  MusicXmlPerformanceMetadata? musicXmlPerformance,
  List<List<int>>? musicXmlPartStaffIndices,
  required List<ScorePerformanceMeasureOccurrence> sourceOccurrences,
  required Fraction Function(Fraction) performanceTimeAt,
}) {
  final eventsByElement = <(int, String), List<ScorePerformanceEvent>>{};
  for (final event in events) {
    final id = event.origin.elementId;
    if (id == null || event.chordPitches != null) continue;
    eventsByElement
        .putIfAbsent((event.origin.staffIndex, id), () => [])
        .add(event);
  }

  final commands = <_DynamicCommand>[];
  var sequence = 0;
  for (final (staffIndex, part) in score.parts.indexed) {
    for (final marking in part.dynamics) {
      final level = _velocityForDynamicLevel(marking.level);
      for (final event
          in eventsByElement[(staffIndex, marking.elementId)] ??
              const <ScorePerformanceEvent>[]) {
        commands.add(
          _DynamicCommand(
            staffIndex: staffIndex,
            start: event.start,
            velocity: level,
            momentary: _isMomentaryDynamicLevel(marking.level),
            targetElementId: event.isRest ? null : marking.elementId,
            priority: 0,
            sequence: sequence++,
          ),
        );
      }
    }
  }

  void addMusicXmlCommand({
    required MusicXmlPerformanceOrigin origin,
    required Fraction relativeStart,
    required int velocity,
    required int priority,
    bool momentary = false,
  }) {
    final staffIndices = origin.staffIndex == null
        ? musicXmlPartStaffIndices != null &&
                  origin.partIndex >= 0 &&
                  origin.partIndex < musicXmlPartStaffIndices.length
              ? musicXmlPartStaffIndices[origin.partIndex]
              : origin.partIndex >= 0 && origin.partIndex < score.parts.length
              ? [origin.partIndex]
              : const <int>[]
        : [origin.staffIndex!];
    for (final occurrence in sourceOccurrences) {
      if (occurrence.measureIndex != origin.measureIndex) continue;
      final start = performanceTimeAt(occurrence.start + relativeStart);
      for (final staffIndex in staffIndices) {
        if (staffIndex < 0 || staffIndex >= score.parts.length) continue;
        commands.add(
          _DynamicCommand(
            staffIndex: staffIndex,
            start: start,
            velocity: velocity,
            momentary: momentary,
            priority: priority,
            sequence: sequence++,
          ),
        );
      }
    }
  }

  for (final direction
      in musicXmlPerformance?.directions ??
          const <MusicXmlDirectionMetadata>[]) {
    final start = _musicXmlDirectionStart(direction);
    for (final mark in direction.dynamicMarks) {
      final level = _dynamicLevelForName(mark);
      if (level == null) continue;
      addMusicXmlCommand(
        origin: direction.origin,
        relativeStart: start,
        velocity: _velocityForDynamicLevel(level),
        priority: 1,
        momentary: _isMomentaryDynamicLevel(level),
      );
    }
  }
  for (final sound
      in musicXmlPerformance?.sounds ?? const <MusicXmlSoundMetadata>[]) {
    final dynamics = sound.dynamics;
    if (dynamics == null || !dynamics.isFinite) continue;
    addMusicXmlCommand(
      origin: sound.origin,
      relativeStart: _musicXmlWholeNotes(sound.origin.onset),
      velocity: (_velocityForDynamicLevel(DynamicLevel.f) * dynamics / 100)
          .round()
          .clamp(1, 127),
      priority: 2,
    );
  }
  commands.sort((a, b) {
    final byStaff = a.staffIndex.compareTo(b.staffIndex);
    if (byStaff != 0) return byStaff;
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    final byPriority = a.priority.compareTo(b.priority);
    return byPriority != 0 ? byPriority : a.sequence.compareTo(b.sequence);
  });

  final commandsByStaff = <int, List<_DynamicCommand>>{};
  for (final command in commands) {
    commandsByStaff.putIfAbsent(command.staffIndex, () => []).add(command);
  }
  final output = <ScorePerformanceEvent>[];
  for (var staffIndex = 0; staffIndex < score.parts.length; staffIndex++) {
    final staffEvents = events
        .where((event) => event.origin.staffIndex == staffIndex)
        .toList();
    final staffCommands =
        commandsByStaff[staffIndex] ?? const <_DynamicCommand>[];
    var commandIndex = 0;
    var currentVelocity = _velocityForDynamicLevel(DynamicLevel.mf);
    int? pendingAccent;
    String? pendingAccentTarget;
    var eventIndex = 0;
    while (eventIndex < staffEvents.length) {
      final start = staffEvents[eventIndex].start;
      int? dynamicTargetVelocity;
      while (commandIndex < staffCommands.length &&
          staffCommands[commandIndex].start <= start) {
        final command = staffCommands[commandIndex++];
        if (command.momentary) {
          pendingAccent = command.velocity;
          pendingAccentTarget = command.targetElementId;
        } else {
          currentVelocity = command.velocity;
          pendingAccent = null;
          pendingAccentTarget = null;
          if (command.start == start) {
            dynamicTargetVelocity = command.velocity;
          }
        }
      }

      var groupEnd = eventIndex + 1;
      while (groupEnd < staffEvents.length &&
          staffEvents[groupEnd].start == start) {
        groupEnd++;
      }
      var accentConsumed = false;
      for (final event in staffEvents.sublist(eventIndex, groupEnd)) {
        if (event.isRest) {
          output.add(event);
          continue;
        }
        final id = event.origin.elementId;
        final targetsEvent =
            pendingAccentTarget == null || pendingAccentTarget == id;
        final baseVelocity = targetsEvent && pendingAccent != null
            ? pendingAccent
            : currentVelocity;
        final explicitVelocity = event.chordPitches == null
            ? event.explicitVelocity
            : null;
        var velocity = baseVelocity;
        if (event.chordPitches == null && explicitVelocity == null) {
          if (event.articulations.contains(Articulation.marcato)) {
            velocity += 20;
          } else if (event.articulations.contains(Articulation.accent)) {
            velocity += 15;
          }
        }
        output.add(
          ScorePerformanceEvent(
            origin: event.origin,
            start: event.start,
            duration: event.duration,
            isRest: event.isRest,
            route: event.route,
            velocity: (explicitVelocity ?? velocity).clamp(1, 127),
            sustainedDynamicVelocity: currentVelocity,
            dynamicTargetVelocity: dynamicTargetVelocity,
            sourceStart: event.sourceStart,
            sourceDuration: event.sourceDuration,
            explicitVelocity: event.explicitVelocity,
            pitches: event.pitches,
            articulations: event.articulations,
            arpeggio: event.arpeggio,
            tremoloStrokes: event.tremoloStrokes,
            tieToNext: event.tieToNext,
            showAccidental: event.showAccidental,
            ornament: event.ornament,
            ornamentAccidentalAlter: event.ornamentAccidentalAlter,
            ornamentUpperPitches: event.ornamentUpperPitches,
            ornamentLowerPitches: event.ornamentLowerPitches,
            graceNotes: event.graceNotes,
            graceStyle: event.graceStyle,
            graceTiesToMain: event.graceTiesToMain,
            graceParameters: event.graceParameters,
            gracePitchAlterOverrides: event.gracePitchAlterOverrides,
            pitchDurations: event.pitchDurations,
            chordPitches: event.chordPitches,
          ),
        );
        if (targetsEvent && pendingAccent != null) accentConsumed = true;
      }
      if (pendingAccent != null &&
          (pendingAccentTarget == null
              ? staffEvents
                    .sublist(eventIndex, groupEnd)
                    .any((event) => !event.isRest)
              : accentConsumed)) {
        pendingAccent = null;
        pendingAccentTarget = null;
      }
      eventIndex = groupEnd;
    }
  }
  output.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    final byStaff = a.origin.staffIndex.compareTo(b.origin.staffIndex);
    return byStaff != 0 ? byStaff : a.origin.voice.compareTo(b.origin.voice);
  });
  return output;
}

List<ScorePerformanceEvent> _applyTiedPitchDurations(
  List<ScorePerformanceEvent> events,
) {
  final eventsByVoice = <(int, int), List<int>>{};
  for (final (index, event) in events.indexed) {
    if (event.chordPitches != null) continue;
    eventsByVoice
        .putIfAbsent((event.origin.staffIndex, event.origin.voice), () => [])
        .add(index);
  }
  final nextByEvent = <int, int>{};
  for (final indices in eventsByVoice.values) {
    indices.sort(
      (a, b) => events[a].sourceStart.compareTo(events[b].sourceStart),
    );
    for (var index = 0; index + 1 < indices.length; index++) {
      nextByEvent[indices[index]] = indices[index + 1];
    }
  }

  final continuations = [for (final _ in events) <int>{}];
  for (final (index, event) in events.indexed) {
    if (event.isRest || !event.tieToNext) continue;
    final nextIndex = nextByEvent[index];
    if (nextIndex == null) continue;
    final next = events[nextIndex];
    if (next.isRest ||
        event.sourceStart + event.sourceDuration != next.sourceStart) {
      continue;
    }
    for (final pitch in event.pitches) {
      if (next.pitches.any(
        (candidate) => candidate.midiNumber == pitch.midiNumber,
      )) {
        continuations[nextIndex].add(pitch.midiNumber);
      }
    }
  }

  final output = <ScorePerformanceEvent>[];
  for (final (index, event) in events.indexed) {
    if (event.isRest || event.pitches.isEmpty || event.chordPitches != null) {
      output.add(event);
      continue;
    }
    final pitchDurations = <ScorePerformancePitchDuration>[];
    for (final pitch in event.pitches) {
      if (continuations[index].contains(pitch.midiNumber)) {
        pitchDurations.add(
          ScorePerformancePitchDuration(
            pitch: pitch,
            duration: event.duration,
            attack: false,
          ),
        );
        continue;
      }

      var lastEvent = index;
      var end = event.end;
      while (events[lastEvent].tieToNext) {
        final nextIndex = nextByEvent[lastEvent];
        if (nextIndex == null) break;
        final current = events[lastEvent];
        final next = events[nextIndex];
        if (current.isRest ||
            next.isRest ||
            current.sourceStart + current.sourceDuration != next.sourceStart ||
            !next.pitches.any(
              (candidate) => candidate.midiNumber == pitch.midiNumber,
            )) {
          break;
        }
        continuations[nextIndex].add(pitch.midiNumber);
        lastEvent = nextIndex;
        end = next.end;
      }
      var duration = end - event.start;
      if (lastEvent == index) {
        duration = _articulatedDuration(duration, event.articulations);
      }
      pitchDurations.add(
        ScorePerformancePitchDuration(
          pitch: pitch,
          duration: duration,
          attack: true,
        ),
      );
    }
    output.add(
      ScorePerformanceEvent(
        origin: event.origin,
        start: event.start,
        duration: event.duration,
        sourceStart: event.sourceStart,
        sourceDuration: event.sourceDuration,
        isRest: event.isRest,
        route: event.route,
        velocity: event.velocity,
        sustainedDynamicVelocity: event.sustainedDynamicVelocity,
        dynamicTargetVelocity: event.dynamicTargetVelocity,
        explicitVelocity: event.explicitVelocity,
        pitches: event.pitches,
        articulations: event.articulations,
        arpeggio: event.arpeggio,
        tremoloStrokes: event.tremoloStrokes,
        tieToNext: event.tieToNext,
        showAccidental: event.showAccidental,
        ornament: event.ornament,
        ornamentAccidentalAlter: event.ornamentAccidentalAlter,
        ornamentUpperPitches: event.ornamentUpperPitches,
        ornamentLowerPitches: event.ornamentLowerPitches,
        graceNotes: event.graceNotes,
        graceStyle: event.graceStyle,
        graceTiesToMain: event.graceTiesToMain,
        graceParameters: event.graceParameters,
        gracePitchAlterOverrides: event.gracePitchAlterOverrides,
        pitchDurations: pitchDurations,
        chordPitches: event.chordPitches,
      ),
    );
  }
  return output;
}

List<ScorePerformanceEvent> _resolveGracePitches(
  MultiPartScore score,
  List<ScorePerformanceEvent> events,
  List<ScorePerformanceMeasureOccurrence> occurrences,
) {
  final gracePitches = [
    for (final event in events) [...event.graceNotes],
  ];
  for (final (staffIndex, part) in score.parts.indexed) {
    for (final occurrence in occurrences) {
      var keySignature = part.keySignature;
      for (
        var measureIndex = 0;
        measureIndex <= occurrence.measureIndex &&
            measureIndex < part.measures.length;
        measureIndex++
      ) {
        keySignature = part.measures[measureIndex].keyChange ?? keySignature;
      }

      final indices =
          [
            for (final (index, event) in events.indexed)
              if (event.origin.staffIndex == staffIndex &&
                  event.origin.measureIndex == occurrence.measureIndex &&
                  event.sourceStart >= occurrence.start &&
                  event.sourceStart < occurrence.end)
                index,
          ]..sort((a, b) {
            final byStart = events[a].sourceStart.compareTo(
              events[b].sourceStart,
            );
            if (byStart != 0) return byStart;
            return events[a].origin.voice.compareTo(events[b].origin.voice);
          });
      final measureAccidentals = <(Step, int), int>{};
      var index = 0;
      while (index < indices.length) {
        final start = events[indices[index]].sourceStart;
        var groupEnd = index + 1;
        while (groupEnd < indices.length &&
            events[indices[groupEnd]].sourceStart == start) {
          groupEnd++;
        }

        for (final eventIndex in indices.sublist(index, groupEnd)) {
          final event = events[eventIndex];
          for (final (graceIndex, pitch) in event.graceNotes.indexed) {
            final explicitAlter =
                graceIndex < event.gracePitchAlterOverrides.length
                ? event.gracePitchAlterOverrides[graceIndex]
                : null;
            final alteration =
                explicitAlter ??
                measureAccidentals[(pitch.step, pitch.octave)] ??
                (pitch.alter != 0
                    ? pitch.alter
                    : keySignature.alterFor(pitch.step));
            gracePitches[eventIndex][graceIndex] = Pitch(
              pitch.step,
              alter: alteration,
              octave: pitch.octave,
            );
            if (explicitAlter != null || pitch.alter != 0) {
              measureAccidentals[(pitch.step, pitch.octave)] = alteration;
            }
          }
        }

        for (final eventIndex in indices.sublist(index, groupEnd)) {
          final event = events[eventIndex];
          if (event.isRest || event.pitches.isEmpty) continue;
          for (final pitch in event.pitches) {
            if (event.showAccidental == true ||
                pitch.alter != keySignature.alterFor(pitch.step)) {
              measureAccidentals[(pitch.step, pitch.octave)] = pitch.alter;
            }
          }
        }
        index = groupEnd;
      }
    }
  }

  return [
    for (final (index, event) in events.indexed)
      _copyPerformanceEvent(event, graceNotes: gracePitches[index]),
  ];
}

List<ScorePerformanceEvent> _applyGracePitchDurations(
  List<ScorePerformanceEvent> events,
) {
  final eventIndicesByVoice = <(int, int), List<int>>{};
  for (final (index, event) in events.indexed) {
    if (event.chordPitches != null) continue;
    eventIndicesByVoice
        .putIfAbsent((event.origin.staffIndex, event.origin.voice), () => [])
        .add(index);
  }
  final previousByEvent = <int, int>{};
  for (final indices in eventIndicesByVoice.values) {
    indices.sort(
      (a, b) => events[a].sourceStart.compareTo(events[b].sourceStart),
    );
    for (var index = 1; index < indices.length; index++) {
      final previousIndex = indices[index - 1];
      final currentIndex = indices[index];
      final previous = events[previousIndex];
      final current = events[currentIndex];
      if (previous.sourceStart + previous.sourceDuration ==
          current.sourceStart) {
        previousByEvent[currentIndex] = previousIndex;
      }
    }
  }

  final output = [...events];
  for (final (index, event) in events.indexed) {
    if (event.isRest ||
        event.graceNotes.isEmpty ||
        event.pitchDurations.isEmpty) {
      continue;
    }
    final previousIndex = previousByEvent[index];
    final previous = previousIndex == null || output[previousIndex].isRest
        ? null
        : output[previousIndex];
    final graceDurations = _graceDurationTicks(event, previous);
    final totalGraceTicks = graceDurations.fold<int>(0, (a, b) => a + b);
    if (totalGraceTicks <= 0) continue;

    final hasMakeTime = event.graceParameters.any(
      (parameter) => parameter.makeTimeQuarterNotes != null,
    );
    final hasStealTimeFollowing =
        !hasMakeTime &&
        event.graceParameters.any(
          (parameter) => parameter.stealTimeFollowing != null,
        );
    final hasStealTimePrevious =
        !hasMakeTime &&
        !hasStealTimeFollowing &&
        event.graceParameters.any(
          (parameter) => parameter.stealTimePrevious != null,
        );
    final stealsFollowing = !hasMakeTime && !hasStealTimePrevious;
    final startsBeforePrincipal = hasMakeTime || hasStealTimePrevious;
    final graceStartOffset = startsBeforePrincipal ? -totalGraceTicks : 0;
    final graceOffsets = <int>[];
    var elapsedGraceTicks = 0;
    for (final duration in graceDurations) {
      graceOffsets.add(graceStartOffset + elapsedGraceTicks);
      elapsedGraceTicks += duration;
    }

    var tiedGraceIndex = -1;
    if (event.graceTiesToMain.contains(event.graceNotes.length - 1)) {
      final candidate = event.graceNotes.length - 1;
      if (event.pitchDurations.any(
        (principal) =>
            principal.pitch.midiNumber ==
            event.graceNotes[candidate].midiNumber,
      )) {
        tiedGraceIndex = candidate;
      }
    }

    final pitchDurations = <ScorePerformancePitchDuration>[];
    for (final principal in event.pitchDurations) {
      final tiedToPrincipal =
          tiedGraceIndex >= 0 &&
          principal.pitch.midiNumber ==
              event.graceNotes[tiedGraceIndex].midiNumber;
      if (tiedToPrincipal) {
        final startOffset = _performanceFractionForTicks(
          graceOffsets[tiedGraceIndex],
        );
        final endOffset = principal.startOffset + principal.duration;
        final duration = endOffset - startOffset;
        pitchDurations.add(
          ScorePerformancePitchDuration(
            pitch: principal.pitch,
            startOffset: startOffset,
            duration: duration > Fraction.zero ? duration : Fraction.zero,
            attack: principal.attack && duration > Fraction.zero,
            sourceDriven: principal.sourceDriven,
          ),
        );
      } else if (stealsFollowing && principal.sourceDriven) {
        final startOffset =
            principal.startOffset +
            _performanceFractionForTicks(totalGraceTicks);
        final endOffset = principal.startOffset + principal.duration;
        final duration = endOffset - startOffset;
        pitchDurations.add(
          ScorePerformancePitchDuration(
            pitch: principal.pitch,
            startOffset: startOffset,
            duration: duration > Fraction.zero ? duration : Fraction.zero,
            attack: principal.attack && duration > Fraction.zero,
            sourceDriven: principal.sourceDriven,
          ),
        );
      } else {
        pitchDurations.add(principal);
      }
    }

    final gracePitchDurations = <ScorePerformancePitchDuration>[
      for (final (graceIndex, gracePitch) in event.graceNotes.indexed)
        if (graceIndex != tiedGraceIndex && graceDurations[graceIndex] > 0)
          ScorePerformancePitchDuration(
            pitch: gracePitch,
            startOffset: _performanceFractionForTicks(graceOffsets[graceIndex]),
            duration: _performanceFractionForTicks(graceDurations[graceIndex]),
            attack: true,
            sourceDriven: false,
          ),
    ];
    output[index] = _copyPerformanceEvent(
      event,
      pitchDurations: [...pitchDurations, ...gracePitchDurations],
    );

    if (hasStealTimePrevious && previousIndex != null && previous != null) {
      final previousPitchDurations = [
        for (final pitchDuration in previous.pitchDurations)
          if (!pitchDuration.attack)
            pitchDuration
          else
            ScorePerformancePitchDuration(
              pitch: pitchDuration.pitch,
              startOffset: pitchDuration.startOffset,
              duration: _nonnegativeFraction(
                pitchDuration.duration -
                    _performanceFractionForTicks(totalGraceTicks),
              ),
              attack:
                  pitchDuration.duration >
                  _performanceFractionForTicks(totalGraceTicks),
              sourceDriven: pitchDuration.sourceDriven,
            ),
      ];
      var shortenedDuration = Fraction.zero;
      for (final pitchDuration in previousPitchDurations) {
        final pitchEnd = pitchDuration.startOffset + pitchDuration.duration;
        if (pitchEnd > shortenedDuration) shortenedDuration = pitchEnd;
      }
      output[previousIndex] = _copyPerformanceEvent(
        previous,
        duration: shortenedDuration < previous.duration
            ? shortenedDuration
            : previous.duration,
        pitchDurations: previousPitchDurations,
      );
    }
  }
  return output;
}

List<int> _graceDurationTicks(
  ScorePerformanceEvent event,
  ScorePerformanceEvent? previous,
) {
  final count = event.graceNotes.length;
  final makeTime = [
    for (var index = 0; index < count; index++)
      if (index < event.graceParameters.length)
        event.graceParameters[index].makeTimeQuarterNotes
      else
        null,
  ];
  if (event.graceParameters.any(
    (parameter) => parameter.makeTimeQuarterNotes != null,
  )) {
    if (makeTime.length == count && makeTime.every((value) => value != null)) {
      return [
        for (final value in makeTime)
          _performanceTicks(_musicXmlWholeNotes(value)),
      ];
    }
    final total = makeTime.fold(
      0,
      (ticks, value) =>
          ticks +
          (value == null ? 0 : _performanceTicks(_musicXmlWholeNotes(value))),
    );
    return _splitTicks(total, count);
  }

  final following = [
    for (final parameter in event.graceParameters) parameter.stealTimeFollowing,
  ].whereType<double>().toList();
  final previousPercentages = [
    for (final parameter in event.graceParameters) parameter.stealTimePrevious,
  ].whereType<double>().toList();
  final sourceTicks = _performanceTicks(event.sourceDuration);
  var totalTicks = 0;
  if (following.isNotEmpty) {
    totalTicks = _percentageTicks(
      sourceTicks,
      following.reduce((a, b) => a > b ? a : b),
    ).clamp(0, sourceTicks).toInt();
  } else if (previousPercentages.isNotEmpty) {
    final previousTicks = previous == null
        ? 0
        : _performanceTicks(previous.sourceDuration);
    final percentage = previousPercentages.reduce((a, b) => a > b ? a : b);
    totalTicks = _percentageTicks(previousTicks, percentage);
    totalTicks = totalTicks.clamp(0, previousTicks).toInt();
  } else if (event.graceStyle == GraceStyle.appoggiatura) {
    totalTicks = sourceTicks ~/ 2;
  } else {
    final defaultGraceTicks = _scorePlanTicksPerQuarter ~/ 4;
    final principalLimit = sourceTicks ~/ 4;
    totalTicks = defaultGraceTicks < principalLimit
        ? defaultGraceTicks
        : principalLimit;
  }
  return _splitTicks(totalTicks, count);
}

int _percentageTicks(int ticks, double percentage) =>
    (ticks * percentage.clamp(0, 100) / 100).round();

Fraction _nonnegativeFraction(Fraction value) =>
    value < Fraction.zero ? Fraction.zero : value;

List<ScorePerformanceEvent> _resolveOrnamentPitches(
  MultiPartScore score,
  List<ScorePerformanceEvent> events,
  List<ScorePerformanceMeasureOccurrence> occurrences,
) {
  final upperPitches = [for (final _ in events) <Pitch>[]];
  final lowerPitches = [for (final _ in events) <Pitch>[]];

  for (final (staffIndex, part) in score.parts.indexed) {
    for (final occurrence in occurrences) {
      var keySignature = part.keySignature;
      for (
        var measureIndex = 0;
        measureIndex <= occurrence.measureIndex &&
            measureIndex < part.measures.length;
        measureIndex++
      ) {
        keySignature = part.measures[measureIndex].keyChange ?? keySignature;
      }

      final indices =
          [
            for (final (index, event) in events.indexed)
              if (event.origin.staffIndex == staffIndex &&
                  event.origin.measureIndex == occurrence.measureIndex &&
                  event.sourceStart >= occurrence.start &&
                  event.sourceStart < occurrence.end)
                index,
          ]..sort((a, b) {
            final byStart = events[a].sourceStart.compareTo(
              events[b].sourceStart,
            );
            if (byStart != 0) return byStart;
            return events[a].origin.voice.compareTo(events[b].origin.voice);
          });
      final measureAccidentals = <(Step, int), int>{};
      var index = 0;
      while (index < indices.length) {
        final start = events[indices[index]].sourceStart;
        var groupEnd = index + 1;
        while (groupEnd < indices.length &&
            events[indices[groupEnd]].sourceStart == start) {
          groupEnd++;
        }

        for (final eventIndex in indices.sublist(index, groupEnd)) {
          final event = events[eventIndex];
          if (event.isRest || event.pitches.isEmpty) continue;
          for (final pitch in event.pitches) {
            if (event.showAccidental == true ||
                pitch.alter != keySignature.alterFor(pitch.step)) {
              measureAccidentals[(pitch.step, pitch.octave)] = pitch.alter;
            }
          }
        }

        for (final eventIndex in indices.sublist(index, groupEnd)) {
          final event = events[eventIndex];
          final ornament = event.ornament;
          if (event.isRest || ornament == null) continue;
          final explicitAlter =
              event.ornamentAccidentalAlter ?? ornament.trillAccidentalAlter;
          for (final pitch in event.pitches) {
            upperPitches[eventIndex].add(
              _ornamentNeighbor(
                pitch,
                1,
                explicitAlter: explicitAlter,
                keySignature: keySignature,
                measureAccidentals: measureAccidentals,
              ),
            );
            lowerPitches[eventIndex].add(
              _ornamentNeighbor(
                pitch,
                -1,
                explicitAlter: explicitAlter,
                keySignature: keySignature,
                measureAccidentals: measureAccidentals,
              ),
            );
          }
        }
        index = groupEnd;
      }
    }
  }

  return [
    for (final (index, event) in events.indexed)
      _copyPerformanceEvent(
        event,
        ornamentUpperPitches: upperPitches[index],
        ornamentLowerPitches: lowerPitches[index],
      ),
  ];
}

Pitch _ornamentNeighbor(
  Pitch principal,
  int direction, {
  required int? explicitAlter,
  required KeySignature keySignature,
  required Map<(Step, int), int> measureAccidentals,
}) {
  final targetDiatonic = principal.diatonicIndex + direction;
  final octave = (targetDiatonic / 7).floor();
  final step = Step.values[targetDiatonic - octave * 7];
  final alteration =
      explicitAlter ??
      measureAccidentals[(step, octave)] ??
      keySignature.alterFor(step);
  return Pitch(step, alter: alteration, octave: octave);
}

List<ScorePerformanceEvent> _applyOrnamentPitchDurations(
  List<ScorePerformanceEvent> events,
) => [
  for (final event in events)
    if (event.isRest || event.ornament == null || event.pitchDurations.isEmpty)
      event
    else
      _copyPerformanceEvent(
        event,
        pitchDurations: [
          for (final (pitchIndex, pitchDuration)
              in event.pitchDurations.indexed)
            ..._ornamentPitchDurationsFor(event, pitchIndex, pitchDuration),
        ],
      ),
];

List<ScorePerformanceEvent> _applyArpeggioPitchDurations(
  List<ScorePerformanceEvent> events,
) => [
  for (final event in events)
    if (event.isRest ||
        event.arpeggio == null ||
        event.pitchDurations.length < 2)
      event
    else
      _copyPerformanceEvent(
        event,
        pitchDurations: _arpeggioPitchDurations(event),
      ),
];

List<ScorePerformancePitchDuration> _arpeggioPitchDurations(
  ScorePerformanceEvent event,
) {
  final attacks = [
    for (final (index, pitchDuration) in event.pitchDurations.indexed)
      if (pitchDuration.attack && pitchDuration.sourceDriven) index,
  ];
  if (attacks.length < 2) return event.pitchDurations;

  attacks.sort((a, b) {
    final comparison = event.pitchDurations[a].pitch.midiNumber.compareTo(
      event.pitchDurations[b].pitch.midiNumber,
    );
    return event.arpeggio == Arpeggio.down ? -comparison : comparison;
  });
  final sourceTicks = _performanceTicks(event.sourceDuration);
  final staggerTicks = min(
    _scorePlanTicksPerQuarter ~/ 8,
    sourceTicks ~/ attacks.length,
  );
  if (staggerTicks <= 0) return event.pitchDurations;

  final rankByIndex = {
    for (final (rank, index) in attacks.indexed) index: rank,
  };
  return [
    for (final (index, pitchDuration) in event.pitchDurations.indexed)
      if (!rankByIndex.containsKey(index))
        pitchDuration
      else
        _arpeggiatedPitchDuration(
          pitchDuration,
          rank: rankByIndex[index]!,
          staggerTicks: staggerTicks,
          sourceTicks: sourceTicks,
        ),
  ];
}

ScorePerformancePitchDuration _arpeggiatedPitchDuration(
  ScorePerformancePitchDuration pitchDuration, {
  required int rank,
  required int staggerTicks,
  required int sourceTicks,
}) {
  final startTick = _performanceTicks(pitchDuration.startOffset);
  final durationTicks = _performanceTicks(pitchDuration.duration);
  if (durationTicks <= 1) return pitchDuration;
  final maxDelay = min(durationTicks - 1, max(0, sourceTicks - startTick - 1));
  final delayTicks = min(rank * staggerTicks, maxDelay);
  return ScorePerformancePitchDuration(
    pitch: pitchDuration.pitch,
    startOffset: _performanceFractionForTicks(startTick + delayTicks),
    duration: _performanceFractionForTicks(durationTicks - delayTicks),
    attack: pitchDuration.attack,
    sourceDriven: pitchDuration.sourceDriven,
  );
}

List<ScorePerformanceEvent> _applyTremoloPitchDurations(
  List<ScorePerformanceEvent> events,
) => [
  for (final event in events)
    if (event.isRest ||
        !_isSupportedTremoloStrokeCount(event.tremoloStrokes) ||
        event.pitchDurations.isEmpty)
      event
    else
      _copyPerformanceEvent(
        event,
        pitchDurations: _tremoloPitchDurations(event),
      ),
];

List<ScorePerformancePitchDuration> _tremoloPitchDurations(
  ScorePerformanceEvent event,
) {
  final subdivisionTicks = _tremoloSubdivisionTicks(event.tremoloStrokes);
  final output = <ScorePerformancePitchDuration>[];
  for (final pitchDuration in event.pitchDurations) {
    final durationTicks = _performanceTicks(pitchDuration.duration);
    if (!pitchDuration.attack || durationTicks <= 0) {
      output.add(pitchDuration);
      continue;
    }

    final startTick = _performanceTicks(pitchDuration.startOffset);
    for (var offset = 0; offset < durationTicks; offset += subdivisionTicks) {
      final segmentTicks = min(subdivisionTicks, durationTicks - offset);
      output.add(
        ScorePerformancePitchDuration(
          pitch: pitchDuration.pitch,
          startOffset: _performanceFractionForTicks(startTick + offset),
          duration: _performanceFractionForTicks(segmentTicks),
          attack: true,
          sourceDriven: offset == 0 && pitchDuration.sourceDriven,
        ),
      );
    }
  }
  return output;
}

int _tremoloSubdivisionTicks(int? strokes) {
  if (!_isSupportedTremoloStrokeCount(strokes)) {
    throw ArgumentError.value(strokes, 'strokes');
  }
  return _scorePlanTicksPerQuarter >> strokes!;
}

bool _isSupportedTremoloStrokeCount(int? strokes) =>
    strokes != null && strokes >= 1 && strokes <= 5;

List<ScorePerformancePitchDuration> _ornamentPitchDurationsFor(
  ScorePerformanceEvent event,
  int pitchIndex,
  ScorePerformancePitchDuration principal,
) {
  if (!principal.attack || !principal.sourceDriven) return [principal];
  final sourceTicks = _performanceTicks(event.sourceDuration);
  final durationTicks = _performanceTicks(principal.duration);
  final windowTicks =
      (sourceTicks < durationTicks ? sourceTicks : durationTicks) ~/ 2;
  final ornament = event.ornament!;
  final upper = pitchIndex < event.ornamentUpperPitches.length
      ? event.ornamentUpperPitches[pitchIndex]
      : principal.pitch;
  final lower = pitchIndex < event.ornamentLowerPitches.length
      ? event.ornamentLowerPitches[pitchIndex]
      : principal.pitch;

  final pattern = <(Pitch, int)>[];
  switch (ornament) {
    case Ornament.trill ||
        Ornament.trillSharp ||
        Ornament.trillFlat ||
        Ornament.trillNatural:
      final count = windowTicks ~/ 60;
      if (count < 2) return [principal];
      for (var i = 0; i < count; i++) {
        pattern.add((i.isEven ? principal.pitch : upper, 60));
      }
    case Ornament.mordent || Ornament.shortTrill:
      final count = ornament == Ornament.mordent ? 3 : 3;
      if (windowTicks < count) return [principal];
      final lengths = _splitTicks(windowTicks, count);
      final pitches = ornament == Ornament.mordent
          ? [principal.pitch, lower, principal.pitch]
          : [principal.pitch, upper, principal.pitch];
      for (var i = 0; i < count; i++) {
        pattern.add((pitches[i], lengths[i]));
      }
    case Ornament.turn || Ornament.invertedTurn:
      const count = 4;
      if (windowTicks < count) return [principal];
      final lengths = _splitTicks(windowTicks, count);
      final pitches = ornament == Ornament.turn
          ? [upper, principal.pitch, lower, principal.pitch]
          : [lower, principal.pitch, upper, principal.pitch];
      for (var i = 0; i < count; i++) {
        pattern.add((pitches[i], lengths[i]));
      }
  }

  final result = <ScorePerformancePitchDuration>[
    ScorePerformancePitchDuration(
      pitch: principal.pitch,
      duration: principal.duration,
      attack: false,
      sourceDriven: true,
    ),
  ];
  var startTick = 0;
  for (final (pitch, lengthTicks) in pattern) {
    _appendOrnamentSegment(
      result,
      pitch: pitch,
      startTick: startTick,
      durationTicks: lengthTicks,
    );
    startTick += lengthTicks;
  }
  if (startTick < durationTicks) {
    _appendOrnamentSegment(
      result,
      pitch: principal.pitch,
      startTick: startTick,
      durationTicks: durationTicks - startTick,
    );
  }
  return [
    for (final segment in result)
      ScorePerformancePitchDuration(
        pitch: segment.pitch,
        startOffset: principal.startOffset + segment.startOffset,
        duration: segment.duration,
        attack: segment.attack,
        sourceDriven: segment.sourceDriven,
      ),
  ];
}

void _appendOrnamentSegment(
  List<ScorePerformancePitchDuration> output, {
  required Pitch pitch,
  required int startTick,
  required int durationTicks,
}) {
  if (durationTicks <= 0) return;
  if (output.isNotEmpty) {
    final previous = output.last;
    if (!previous.sourceDriven &&
        previous.attack &&
        previous.pitch == pitch &&
        _performanceTicks(previous.startOffset + previous.duration) ==
            startTick) {
      output[output.length - 1] = ScorePerformancePitchDuration(
        pitch: pitch,
        startOffset: previous.startOffset,
        duration: _performanceFractionForTicks(
          _performanceTicks(previous.duration) + durationTicks,
        ),
        attack: true,
        sourceDriven: false,
      );
      return;
    }
  }
  output.add(
    ScorePerformancePitchDuration(
      pitch: pitch,
      startOffset: _performanceFractionForTicks(startTick),
      duration: _performanceFractionForTicks(durationTicks),
      attack: true,
      sourceDriven: false,
    ),
  );
}

List<int> _splitTicks(int totalTicks, int count) => [
  for (var index = 0; index < count; index++)
    totalTicks ~/ count + (index < totalTicks % count ? 1 : 0),
];

ScorePerformanceEvent _copyPerformanceEvent(
  ScorePerformanceEvent event, {
  Fraction? duration,
  List<Pitch>? ornamentUpperPitches,
  List<Pitch>? ornamentLowerPitches,
  List<Pitch>? graceNotes,
  List<ScorePerformancePitchDuration>? pitchDurations,
}) => ScorePerformanceEvent(
  origin: event.origin,
  start: event.start,
  duration: duration ?? event.duration,
  sourceStart: event.sourceStart,
  sourceDuration: event.sourceDuration,
  isRest: event.isRest,
  route: event.route,
  velocity: event.velocity,
  sustainedDynamicVelocity: event.sustainedDynamicVelocity,
  dynamicTargetVelocity: event.dynamicTargetVelocity,
  explicitVelocity: event.explicitVelocity,
  pitches: event.pitches,
  articulations: event.articulations,
  arpeggio: event.arpeggio,
  tremoloStrokes: event.tremoloStrokes,
  tieToNext: event.tieToNext,
  showAccidental: event.showAccidental,
  ornament: event.ornament,
  ornamentAccidentalAlter: event.ornamentAccidentalAlter,
  ornamentUpperPitches: ornamentUpperPitches ?? event.ornamentUpperPitches,
  ornamentLowerPitches: ornamentLowerPitches ?? event.ornamentLowerPitches,
  graceNotes: graceNotes ?? event.graceNotes,
  graceStyle: event.graceStyle,
  graceTiesToMain: event.graceTiesToMain,
  graceParameters: event.graceParameters,
  gracePitchAlterOverrides: event.gracePitchAlterOverrides,
  pitchDurations: pitchDurations ?? event.pitchDurations,
  chordPitches: event.chordPitches,
);

int _performanceTicks(Fraction duration) {
  final numerator = duration.numerator * 4 * _scorePlanTicksPerQuarter;
  return (numerator + duration.denominator ~/ 2) ~/ duration.denominator;
}

Fraction _performanceFractionForTicks(int ticks) =>
    Fraction(ticks, 4 * _scorePlanTicksPerQuarter);

Fraction _articulatedDuration(
  Fraction duration,
  Set<Articulation> articulations,
) {
  if (articulations.contains(Articulation.staccatissimo)) {
    return Fraction(duration.numerator, duration.denominator * 4);
  }
  if (articulations.contains(Articulation.staccato)) {
    return Fraction(duration.numerator, duration.denominator * 2);
  }
  if (articulations.contains(Articulation.tenuto)) {
    return Fraction(duration.numerator * 19, duration.denominator * 20);
  }
  return duration;
}

int _velocityForDynamicLevel(DynamicLevel level) => switch (level) {
  DynamicLevel.pppp => 8,
  DynamicLevel.ppp => 20,
  DynamicLevel.pp => 33,
  DynamicLevel.p => 49,
  DynamicLevel.mp => 64,
  DynamicLevel.mf => 80,
  DynamicLevel.f => 96,
  DynamicLevel.ff => 112,
  DynamicLevel.fff => 122,
  DynamicLevel.ffff => 127,
  DynamicLevel.sf => 112,
  DynamicLevel.sfz => 118,
  DynamicLevel.sffz => 124,
  DynamicLevel.fz => 112,
  DynamicLevel.rf => 100,
  DynamicLevel.fp => 96,
};

DynamicLevel? _dynamicLevelForName(String name) =>
    DynamicLevel.values.asNameMap()[name.trim().toLowerCase()];

bool _isMomentaryDynamicLevel(DynamicLevel level) => switch (level) {
  DynamicLevel.sf ||
  DynamicLevel.sfz ||
  DynamicLevel.sffz ||
  DynamicLevel.fz ||
  DynamicLevel.rf ||
  DynamicLevel.fp => true,
  _ => false,
};

Fraction _musicXmlDirectionStart(MusicXmlDirectionMetadata direction) {
  var start = _musicXmlWholeNotes(direction.origin.onset);
  if (direction.offsetAffectsSound != true && direction.offset != null) {
    start -= _musicXmlWholeNotes(direction.offset);
  }
  return start;
}

Fraction _musicXmlWholeNotes(MusicXmlPosition? position) {
  if (position == null) return Fraction.zero;
  final numerator = int.tryParse(position.numerator);
  final denominator = int.tryParse(position.denominator);
  if (numerator == null || denominator == null || denominator <= 0) {
    return Fraction.zero;
  }
  return Fraction(numerator, denominator * 4);
}

List<ScorePerformanceExpressionCurve> _performanceExpressionCurves(
  MultiPartScore score,
  List<ScorePerformanceEvent> events,
  Map<int, ScorePerformanceRoute> staffRoutes,
  ScorePerformanceRoute? chordRoute,
) {
  final curves = <ScorePerformanceExpressionCurve>[];
  for (final (staffIndex, part) in score.parts.indexed) {
    final staffRoute = staffRoutes[staffIndex];
    if (staffRoute == null) continue;
    final staffEvents = events
        .where(
          (event) =>
              event.origin.staffIndex == staffIndex &&
              event.chordPitches == null &&
              !event.isRest,
        )
        .toList();
    for (final hairpin in part.hairpins) {
      final starts = staffEvents
          .where((event) => event.origin.elementId == hairpin.startId)
          .toList();
      final ends = staffEvents
          .where((event) => event.origin.elementId == hairpin.endId)
          .toList();
      for (final (startIndex, start) in starts.indexed) {
        final nextStart = startIndex + 1 < starts.length
            ? starts[startIndex + 1].start
            : null;
        final end = ends
            .where(
              (event) =>
                  event.start > start.start &&
                  (nextStart == null || event.start < nextStart),
            )
            .firstOrNull;
        if (end == null) continue;
        final growing = hairpin.type == HairpinType.crescendo;
        final startVelocity =
            start.sustainedDynamicVelocity ??
            _velocityForDynamicLevel(DynamicLevel.mf);
        final endVelocity =
            end.dynamicTargetVelocity ??
            _adjacentGraduatedVelocity(startVelocity, growing: growing);
        final routeCurves = [
          (route: staffRoute, hasEvents: true),
          if (chordRoute != null &&
              events.any(
                (event) =>
                    event.route?.kind ==
                        ScorePerformanceRouteKind.accompaniment &&
                    event.origin.staffIndex == staffIndex &&
                    event.start >= start.start &&
                    event.start <= end.start,
              ))
            (route: chordRoute, hasEvents: true),
        ];
        for (final item in routeCurves) {
          if (!item.hasEvents) continue;
          curves.add(
            ScorePerformanceExpressionCurve(
              route: item.route,
              start: start.start,
              end: end.start,
              startValue: startVelocity,
              endValue: endVelocity,
            ),
          );
        }
      }
    }
  }
  curves.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    final byTrack = a.route.trackIndex.compareTo(b.route.trackIndex);
    return byTrack != 0 ? byTrack : a.end.compareTo(b.end);
  });
  return curves;
}

const _graduatedDynamicVelocities = [8, 20, 33, 49, 64, 80, 96, 112, 122, 127];

int _adjacentGraduatedVelocity(int velocity, {required bool growing}) {
  final adjacent = growing
      ? _graduatedDynamicVelocities.firstWhere(
          (level) => level > velocity,
          orElse: () => velocity,
        )
      : _graduatedDynamicVelocities.lastWhere(
          (level) => level < velocity,
          orElse: () => velocity,
        );
  return adjacent.clamp(1, 127);
}

List<List<int>> _musicXmlPartStaffIndices(ScoreDocument document) {
  final result = <List<int>>[];
  var firstStaff = 0;
  while (firstStaff < document.score.parts.length) {
    final declaredCount = firstStaff < document.staves.length
        ? document.staves[firstStaff].staffCountInPart
        : 1;
    final count = declaredCount
        .clamp(1, document.score.parts.length - firstStaff)
        .toInt();
    result.add(List.generate(count, (offset) => firstStaff + offset));
    firstStaff += count;
  }
  return result;
}

class _DynamicCommand {
  const _DynamicCommand({
    required this.staffIndex,
    required this.start,
    required this.velocity,
    required this.priority,
    required this.sequence,
    this.momentary = false,
    this.targetElementId,
  });

  final int staffIndex;
  final Fraction start;
  final int velocity;
  final int priority;
  final int sequence;
  final bool momentary;
  final String? targetElementId;
}

class _PerformanceJump {
  const _PerformanceJump({
    required this.id,
    required this.originIndex,
    required this.destinationIndex,
    this.playUntilIndex,
    this.continueAtIndex,
    this.stopAtFine = false,
    this.armCoda = false,
    this.repeatsAfterJump,
    this.timeOnlyPasses = const {},
  });

  final int id;
  final int originIndex;
  final int destinationIndex;
  final int? playUntilIndex;
  final int? continueAtIndex;
  final bool stopAtFine;
  final bool armCoda;
  final bool? repeatsAfterJump;
  final Set<int> timeOnlyPasses;

  bool appliesToPass(int pass) =>
      timeOnlyPasses.isEmpty || timeOnlyPasses.contains(pass);
}

class _PerformanceCodaJump {
  const _PerformanceCodaJump({
    required this.originIndex,
    required this.destinationIndex,
    this.timeOnlyPasses = const {},
  });

  final int originIndex;
  final int destinationIndex;
  final Set<int> timeOnlyPasses;

  bool appliesToPass(int pass) =>
      timeOnlyPasses.isEmpty || timeOnlyPasses.contains(pass);
}

class _RepeatPolicy {
  const _RepeatPolicy({this.passes, this.afterJump});

  final int? passes;
  final bool? afterJump;
}

class _PerformanceNavigation {
  const _PerformanceNavigation({
    required this.jumpsByOrigin,
    required this.codaJumpsByOrigin,
    required this.fineIndices,
    required this.repeatStarts,
    required this.repeatEnds,
    required this.repeatAtStart,
    required this.repeatAtEnd,
    required this.passagePasses,
    required this.playRepeats,
    required this.repeatsAfterJump,
  });

  final Map<int, List<_PerformanceJump>> jumpsByOrigin;
  final Map<int, List<_PerformanceCodaJump>> codaJumpsByOrigin;
  final Set<int> fineIndices;
  final Set<int> repeatStarts;
  final Set<int> repeatEnds;
  final Map<int, _RepeatPolicy> repeatAtStart;
  final Map<int, _RepeatPolicy> repeatAtEnd;
  final Map<int, Set<int>> passagePasses;
  final bool playRepeats;
  final bool? repeatsAfterJump;
}

class _PerformanceRepeatFrame {
  _PerformanceRepeatFrame({
    required this.start,
    required this.passes,
    this.afterJump,
  }) : jumpsLeft = passes - 1;

  final int start;
  final int passes;
  final bool? afterJump;
  int jumpsLeft;
  int? end;

  int get pass => passes - jumpsLeft;
}

_PerformanceNavigation _buildPerformanceNavigation(
  Score score, {
  MuseScorePerformanceMetadata? museScorePerformance,
  MusicXmlPerformanceMetadata? musicXmlPerformance,
}) {
  final measureCount = score.measures.length;
  final issues = <ScorePerformanceNavigationIssue>[];
  final jumpsByOrigin = <int, List<_PerformanceJump>>{};
  final codaJumpsByOrigin = <int, List<_PerformanceCodaJump>>{};
  final fineIndices = <int>{};
  final repeatStarts = <int>{
    for (final (index, measure) in score.measures.indexed)
      if (measure.startRepeat) index,
  };
  final repeatEnds = <int>{
    for (final (index, measure) in score.measures.indexed)
      if (measure.endRepeat) index,
  };
  final repeatAtStart = <int, _RepeatPolicy>{};
  final repeatAtEnd = <int, _RepeatPolicy>{};
  final passagePasses = <int, Set<int>>{};
  final graphEdges = <(int, int)>[];
  var nextJumpId = 0;

  void issue(
    ScorePerformanceNavigationIssueCode code,
    String message, {
    int? staffIndex,
    int? measureIndex,
  }) {
    issues.add(
      ScorePerformanceNavigationIssue(
        code: code,
        message: message,
        staffIndex: staffIndex,
        measureIndex: measureIndex,
      ),
    );
  }

  bool validMeasureIndex(int index, String source) {
    if (index >= 0 && index < measureCount) return true;
    issue(
      ScorePerformanceNavigationIssueCode.invalidNavigation,
      '$source refers to invalid measure index $index',
      measureIndex: index,
    );
    return false;
  }

  void addJump(_PerformanceJump jump, String source) {
    if (!validMeasureIndex(jump.originIndex, source) ||
        jump.destinationIndex < 0 ||
        jump.destinationIndex > measureCount) {
      return;
    }
    final existing = jumpsByOrigin[jump.originIndex] ?? const [];
    if (existing.any(
      (item) =>
          item.destinationIndex == jump.destinationIndex &&
          item.playUntilIndex == jump.playUntilIndex &&
          item.continueAtIndex == jump.continueAtIndex,
    )) {
      return;
    }
    if (existing.isNotEmpty) {
      issue(
        ScorePerformanceNavigationIssueCode.conflictingNavigation,
        'multiple jump destinations at measure ${jump.originIndex} ($source)',
        measureIndex: jump.originIndex,
      );
      return;
    }
    jumpsByOrigin.putIfAbsent(jump.originIndex, () => []).add(jump);
    graphEdges.add((jump.originIndex, jump.destinationIndex));
    if (jump.playUntilIndex != null && jump.continueAtIndex != null) {
      graphEdges.add((jump.playUntilIndex!, jump.continueAtIndex!));
    }
    nextJumpId++;
  }

  void addCodaJump(_PerformanceCodaJump jump, String source) {
    if (!validMeasureIndex(jump.originIndex, source) ||
        jump.destinationIndex < 0 ||
        jump.destinationIndex > measureCount) {
      return;
    }
    final existing = codaJumpsByOrigin[jump.originIndex] ?? const [];
    if (existing.any(
      (item) => item.destinationIndex == jump.destinationIndex,
    )) {
      return;
    }
    if (existing.isNotEmpty) {
      issue(
        ScorePerformanceNavigationIssueCode.conflictingNavigation,
        'multiple To Coda destinations at measure ${jump.originIndex}',
        measureIndex: jump.originIndex,
      );
      return;
    }
    codaJumpsByOrigin.putIfAbsent(jump.originIndex, () => []).add(jump);
    graphEdges.add((jump.originIndex, jump.destinationIndex));
  }

  void mergeRepeatPolicy(
    Map<int, _RepeatPolicy> policies,
    int index,
    _RepeatPolicy next,
    String source,
  ) {
    final previous = policies[index];
    if (previous != null &&
        ((previous.passes != null &&
                next.passes != null &&
                previous.passes != next.passes) ||
            (previous.afterJump != null &&
                next.afterJump != null &&
                previous.afterJump != next.afterJump))) {
      issue(
        ScorePerformanceNavigationIssueCode.conflictingNavigation,
        'conflicting repeat parameters at measure $index ($source)',
        measureIndex: index,
      );
      return;
    }
    policies[index] = _RepeatPolicy(
      passes: next.passes ?? previous?.passes,
      afterJump: next.afterJump ?? previous?.afterJump,
    );
  }

  final museScore = museScorePerformance;
  if (museScore != null) {
    for (final diagnostic in museScore.diagnostics) {
      if (diagnostic.origin.staffIndex != null &&
          diagnostic.origin.staffIndex != 0) {
        continue;
      }
      final code = switch (diagnostic.code) {
        MuseScorePerformanceDiagnosticCode.duplicateMarkerLabel ||
        MuseScorePerformanceDiagnosticCode.ambiguousDestination ||
        MuseScorePerformanceDiagnosticCode.conflictingPlayRepeats ||
        MuseScorePerformanceDiagnosticCode.conflictingPassages =>
          ScorePerformanceNavigationIssueCode.conflictingNavigation,
        MuseScorePerformanceDiagnosticCode.unresolvedDestination =>
          ScorePerformanceNavigationIssueCode.unresolvedDestination,
        MuseScorePerformanceDiagnosticCode.invalidPlayRepeats ||
        MuseScorePerformanceDiagnosticCode.invalidPassage =>
          ScorePerformanceNavigationIssueCode.invalidNavigation,
      };
      issue(
        code,
        diagnostic.message,
        staffIndex: diagnostic.origin.staffIndex,
        measureIndex: diagnostic.origin.measureIndex,
      );
    }
    if (museScore.playRepeatsDeclarations.isNotEmpty &&
        museScore.playRepeats == null) {
      issue(
        ScorePerformanceNavigationIssueCode.conflictingNavigation,
        'MuseScore playRepeats declarations are invalid or conflicting',
        staffIndex: museScore.playRepeatsDeclarations.first.origin.staffIndex,
        measureIndex:
            museScore.playRepeatsDeclarations.first.origin.measureIndex,
      );
    }
    for (final passage in museScore.passages) {
      if (passage.origin.staffIndex != null && passage.origin.staffIndex != 0) {
        continue;
      }
      final end = passage.endMeasureIndexExclusive ?? measureCount;
      if (passage.passNumbers.isEmpty ||
          passage.startMeasureIndex < 0 ||
          passage.startMeasureIndex >= end ||
          end > measureCount) {
        issue(
          ScorePerformanceNavigationIssueCode.invalidNavigation,
          'invalid MuseScore passage at measure ${passage.startMeasureIndex}',
          staffIndex: passage.origin.staffIndex,
          measureIndex: passage.startMeasureIndex,
        );
        continue;
      }
      final passes = passage.passNumbers.toSet();
      for (var index = passage.startMeasureIndex; index < end; index++) {
        final previous = passagePasses[index];
        if (previous != null && !_sameIntSet(previous, passes)) {
          issue(
            ScorePerformanceNavigationIssueCode.conflictingNavigation,
            'conflicting MuseScore passages at measure $index',
            staffIndex: passage.origin.staffIndex,
            measureIndex: index,
          );
        } else {
          passagePasses[index] = passes;
        }
      }
    }
    for (final jump in museScore.jumps) {
      if (jump.origin.staffIndex != null && jump.origin.staffIndex != 0) {
        continue;
      }
      final origin = jump.origin.measureIndex;
      if (origin == null || !validMeasureIndex(origin, 'MuseScore Jump')) {
        continue;
      }
      int? destination(
        MuseScorePerformanceDestination? value,
        String? reference,
        String field,
      ) {
        if (reference == null) return null;
        if (value == null) {
          issue(
            ScorePerformanceNavigationIssueCode.unresolvedDestination,
            'MuseScore Jump at measure $origin has unresolved $field "$reference"',
            staffIndex: jump.origin.staffIndex,
            measureIndex: origin,
          );
          return null;
        }
        final index = value.kind == MuseScoreDestinationKind.scoreEnd
            ? measureCount
            : value.measureIndex;
        if (index < 0 || index > measureCount) {
          issue(
            ScorePerformanceNavigationIssueCode.invalidNavigation,
            'MuseScore Jump at measure $origin has invalid $field index $index',
            staffIndex: jump.origin.staffIndex,
            measureIndex: origin,
          );
          return null;
        }
        return index;
      }

      final target = destination(jump.jumpToDestination, jump.jumpTo, 'jumpTo');
      if (target == null) continue;
      final playUntil = destination(
        jump.playUntilDestination,
        jump.playUntil,
        'playUntil',
      );
      final continueAt =
          destination(
            jump.continueAtDestination,
            jump.continueAt,
            'continueAt',
          ) ??
          (jump.continueAt == null ? measureCount : null);
      if (jump.playUntil != null && playUntil == null) continue;
      addJump(
        _PerformanceJump(
          id: nextJumpId,
          originIndex: origin,
          destinationIndex: target,
          playUntilIndex: playUntil,
          continueAtIndex: playUntil == null ? null : continueAt,
          armCoda: jump.continueAt != null,
          repeatsAfterJump: jump.playRepeats,
        ),
        'MuseScore Jump',
      );
    }
  }

  final musicXml = musicXmlPerformance;
  final xmlSounds =
      musicXml?.sounds
          .where(
            (sound) =>
                sound.origin.partIndex == 0 &&
                (sound.origin.staffIndex == null ||
                    sound.origin.staffIndex == 0),
          )
          .toList() ??
      const <MusicXmlSoundMetadata>[];
  final segnoTargets = <String, List<int>>{};
  final codaTargets = <String, List<int>>{};
  final xmlFineIndices = <int>{};
  void addLabelTarget(
    Map<String, List<int>> targets,
    String? label,
    int index,
  ) {
    final normalized = label?.trim();
    if (normalized == null || normalized.isEmpty) return;
    (targets[normalized] ??= []).add(index);
  }

  for (final sound in xmlSounds) {
    final index = sound.origin.measureIndex;
    if (!validMeasureIndex(index, 'MusicXML sound')) continue;
    addLabelTarget(segnoTargets, sound.segno, index);
    addLabelTarget(codaTargets, sound.coda, index);
    if (sound.fine != null) {
      xmlFineIndices.add(index);
      fineIndices.add(index);
    }
    if (sound.rawForwardRepeat != null && sound.forwardRepeat == null) {
      issue(
        ScorePerformanceNavigationIssueCode.invalidNavigation,
        'invalid MusicXML forward-repeat at measure $index',
        staffIndex: sound.origin.staffIndex,
        measureIndex: index,
      );
    }
    if (sound.forwardRepeat == true) repeatStarts.add(index);
  }

  int? xmlDestination(
    Map<String, List<int>> targets,
    String? reference,
    String source,
    int measureIndex,
    int? staffIndex,
  ) {
    final label = reference?.trim();
    if (label == null || label.isEmpty) {
      issue(
        ScorePerformanceNavigationIssueCode.unresolvedDestination,
        '$source has an empty destination label',
        staffIndex: staffIndex,
        measureIndex: measureIndex,
      );
      return null;
    }
    final candidates = targets[label];
    if (candidates == null || candidates.isEmpty) {
      issue(
        ScorePerformanceNavigationIssueCode.unresolvedDestination,
        '$source refers to missing label "$label"',
        staffIndex: staffIndex,
        measureIndex: measureIndex,
      );
      return null;
    }
    if (candidates.length != 1) {
      issue(
        ScorePerformanceNavigationIssueCode.conflictingNavigation,
        '$source refers to ambiguous label "$label"',
        staffIndex: staffIndex,
        measureIndex: measureIndex,
      );
      return null;
    }
    return candidates.single;
  }

  for (final sound in xmlSounds) {
    final index = sound.origin.measureIndex;
    if (sound.toCoda != null) {
      final target = xmlDestination(
        codaTargets,
        sound.toCoda,
        'MusicXML To Coda at measure $index',
        index,
        sound.origin.staffIndex,
      );
      if (target != null) {
        addCodaJump(
          _PerformanceCodaJump(
            originIndex: index,
            destinationIndex: target,
            timeOnlyPasses: sound.timeOnlyPasses.toSet(),
          ),
          'MusicXML To Coda',
        );
      }
    }

    final hasDaCapo = sound.daCapo == true;
    final hasDalSegno = sound.dalSegno != null;
    if (sound.rawDaCapo != null && sound.daCapo == null) {
      issue(
        ScorePerformanceNavigationIssueCode.invalidNavigation,
        'invalid MusicXML daCapo at measure $index',
        staffIndex: sound.origin.staffIndex,
        measureIndex: index,
      );
    }
    if (hasDaCapo && hasDalSegno) {
      issue(
        ScorePerformanceNavigationIssueCode.conflictingNavigation,
        'MusicXML sound has both daCapo and dalSegno at measure $index',
        staffIndex: sound.origin.staffIndex,
        measureIndex: index,
      );
      continue;
    }
    if (!hasDaCapo && !hasDalSegno) continue;
    final target = hasDaCapo
        ? 0
        : xmlDestination(
            segnoTargets,
            sound.dalSegno,
            'MusicXML D.S. at measure $index',
            index,
            sound.origin.staffIndex,
          );
    if (target == null) continue;
    addJump(
      _PerformanceJump(
        id: nextJumpId,
        originIndex: index,
        destinationIndex: target,
        armCoda: xmlSounds.any((candidate) => candidate.toCoda != null),
        stopAtFine: xmlFineIndices.isNotEmpty,
        timeOnlyPasses: sound.timeOnlyPasses.toSet(),
      ),
      'MusicXML D.C./D.S.',
    );
  }

  for (final repeat in musicXml?.repeats ?? const <MusicXmlRepeatMetadata>[]) {
    if (repeat.origin.partIndex != 0 ||
        (repeat.origin.staffIndex != null && repeat.origin.staffIndex != 0)) {
      continue;
    }
    final index = repeat.origin.measureIndex;
    if (!validMeasureIndex(index, 'MusicXML repeat')) continue;
    if (repeat.rawTimes != null &&
        (repeat.times == null || repeat.times! < 1)) {
      issue(
        ScorePerformanceNavigationIssueCode.invalidNavigation,
        'invalid MusicXML repeat count at measure $index',
        staffIndex: repeat.origin.staffIndex,
        measureIndex: index,
      );
    }
    if (repeat.rawAfterJump != null && repeat.afterJump == null) {
      issue(
        ScorePerformanceNavigationIssueCode.invalidNavigation,
        'invalid MusicXML after-jump value at measure $index',
        staffIndex: repeat.origin.staffIndex,
        measureIndex: index,
      );
    }
    final policy = _RepeatPolicy(
      passes: repeat.times,
      afterJump: repeat.afterJump,
    );
    switch (repeat.direction) {
      case 'forward':
        repeatStarts.add(index);
        mergeRepeatPolicy(repeatAtStart, index, policy, 'MusicXML forward');
      case 'backward':
        repeatEnds.add(index);
        mergeRepeatPolicy(repeatAtEnd, index, policy, 'MusicXML backward');
      default:
        issue(
          ScorePerformanceNavigationIssueCode.invalidNavigation,
          'unknown MusicXML repeat direction "${repeat.direction}"',
          staffIndex: repeat.origin.staffIndex,
          measureIndex: index,
        );
    }
  }
  final hasMetadataJumps =
      (museScore?.jumps.isNotEmpty ?? false) ||
      xmlSounds.any(
        (sound) =>
            sound.daCapo == true ||
            sound.dalSegno != null ||
            sound.toCoda != null,
      );
  if (!hasMetadataJumps) {
    final segnoIndices = [
      for (final (index, measure) in score.measures.indexed)
        if (measure.navigation == NavigationMark.segno) index,
    ];
    final codaIndices = [
      for (final (index, measure) in score.measures.indexed)
        if (measure.navigation == NavigationMark.coda) index,
    ];
    final segnoIndex = segnoIndices.firstOrNull;
    final codaIndex = codaIndices.firstOrNull;
    if (segnoIndices.length > 1 || codaIndices.length > 1) {
      issue(
        ScorePerformanceNavigationIssueCode.conflictingNavigation,
        'score has multiple unnamed Segno or Coda targets',
        measureIndex: segnoIndices.firstOrNull ?? codaIndices.firstOrNull,
      );
    }
    for (final (index, measure) in score.measures.indexed) {
      final mark = measure.navigation;
      if (mark == NavigationMark.fine) fineIndices.add(index);
      if (mark == NavigationMark.toCoda) {
        if (codaIndex == null) {
          issue(
            ScorePerformanceNavigationIssueCode.unresolvedDestination,
            'To Coda at measure $index has no Coda target',
            measureIndex: index,
          );
        } else {
          addCodaJump(
            _PerformanceCodaJump(
              originIndex: index,
              destinationIndex: codaIndex,
            ),
            'score To Coda',
          );
        }
      }
      final target = switch (mark) {
        NavigationMark.daCapo ||
        NavigationMark.daCapoAlFine ||
        NavigationMark.daCapoAlCoda => 0,
        NavigationMark.dalSegno ||
        NavigationMark.dalSegnoAlFine ||
        NavigationMark.dalSegnoAlCoda => segnoIndex,
        _ => null,
      };
      if (target == null) {
        if (mark == NavigationMark.dalSegno ||
            mark == NavigationMark.dalSegnoAlFine ||
            mark == NavigationMark.dalSegnoAlCoda) {
          issue(
            ScorePerformanceNavigationIssueCode.unresolvedDestination,
            'D.S. at measure $index has no Segno target',
            measureIndex: index,
          );
        }
        continue;
      }
      addJump(
        _PerformanceJump(
          id: nextJumpId,
          originIndex: index,
          destinationIndex: target,
          stopAtFine:
              mark == NavigationMark.daCapoAlFine ||
              mark == NavigationMark.dalSegnoAlFine,
          armCoda:
              mark == NavigationMark.daCapoAlCoda ||
              mark == NavigationMark.dalSegnoAlCoda,
        ),
        'score navigation mark',
      );
    }
    if (score.measures.any(
          (measure) =>
              measure.navigation == NavigationMark.daCapoAlCoda ||
              measure.navigation == NavigationMark.dalSegnoAlCoda,
        ) &&
        codaIndex == null) {
      issue(
        ScorePerformanceNavigationIssueCode.unresolvedDestination,
        'al Coda navigation has no Coda target',
        measureIndex: score.measures.indexWhere(
          (measure) =>
              measure.navigation == NavigationMark.daCapoAlCoda ||
              measure.navigation == NavigationMark.dalSegnoAlCoda,
        ),
      );
    }
  }

  if (_hasNavigationCycle(graphEdges)) {
    issue(
      ScorePerformanceNavigationIssueCode.cyclicNavigation,
      'navigation destinations form a cycle',
    );
  }
  if (issues.isNotEmpty) {
    throw ScorePerformanceNavigationException(List.unmodifiable(issues));
  }
  return _PerformanceNavigation(
    jumpsByOrigin: {
      for (final entry in jumpsByOrigin.entries)
        entry.key: List.unmodifiable(entry.value),
    },
    codaJumpsByOrigin: {
      for (final entry in codaJumpsByOrigin.entries)
        entry.key: List.unmodifiable(entry.value),
    },
    fineIndices: Set.unmodifiable(fineIndices),
    repeatStarts: Set.unmodifiable(repeatStarts),
    repeatEnds: Set.unmodifiable(repeatEnds),
    repeatAtStart: Map.unmodifiable(repeatAtStart),
    repeatAtEnd: Map.unmodifiable(repeatAtEnd),
    passagePasses: {
      for (final entry in passagePasses.entries)
        entry.key: Set.unmodifiable(entry.value),
    },
    playRepeats: museScore?.playRepeats ?? true,
    repeatsAfterJump: museScore?.playRepeats,
  );
}

bool _hasNavigationCycle(List<(int, int)> edges) {
  final outgoing = <int, List<int>>{};
  for (final (source, destination) in edges) {
    outgoing.putIfAbsent(source, () => []).add(destination);
  }
  final active = <int>{};
  final complete = <int>{};
  bool visit(int index) {
    if (active.contains(index)) return true;
    if (!complete.add(index)) return false;
    active.add(index);
    for (final next in outgoing[index] ?? const <int>[]) {
      if (visit(next)) return true;
    }
    active.remove(index);
    return false;
  }

  return outgoing.keys.any(visit);
}

List<int> _performanceMeasureOrder(
  Score score, {
  MuseScorePerformanceMetadata? museScorePerformance,
  MusicXmlPerformanceMetadata? musicXmlPerformance,
}) {
  final navigation = _buildPerformanceNavigation(
    score,
    museScorePerformance: museScorePerformance,
    musicXmlPerformance: musicXmlPerformance,
  );
  final order = <int>[];
  final repeats = <_PerformanceRepeatFrame>[];
  final firedJumps = <int>{};
  final seenStates = <String>{};
  var sectionStart = 0;
  var index = 0;
  var returnedFromJump = false;
  var codaArmed = false;
  var stopAtFine = false;
  var repeatsAfterJump = navigation.repeatsAfterJump;
  _PerformanceJump? pendingBoundary;

  bool repeatEnabled(
    int measureIndex, {
    bool atEnd = false,
    _PerformanceRepeatFrame? frame,
  }) {
    if (!returnedFromJump) return navigation.playRepeats;
    final matchingEnd = atEnd
        ? measureIndex
        : navigation.repeatStarts.contains(measureIndex)
        ? _matchingRepeatEnd(navigation, measureIndex, score.measures.length)
        : null;
    final metadataPolicy =
        (atEnd
            ? navigation.repeatAtEnd[measureIndex]?.afterJump
            : navigation.repeatAtStart[measureIndex]?.afterJump) ??
        (matchingEnd == null
            ? null
            : navigation.repeatAtEnd[matchingEnd]?.afterJump);
    return metadataPolicy ?? frame?.afterJump ?? repeatsAfterJump ?? false;
  }

  while (true) {
    final repeatState = repeats
        .map(
          (frame) =>
              '${frame.start}:${frame.passes}:'
              '${frame.jumpsLeft}:${frame.end}',
        )
        .join(',');
    final firedState = (firedJumps.toList()..sort()).join(',');
    final pendingState = pendingBoundary == null
        ? '-'
        : '${pendingBoundary.id}:${pendingBoundary.playUntilIndex}:'
              '${pendingBoundary.continueAtIndex}';
    final state =
        '$index|$sectionStart|$returnedFromJump|$codaArmed|$stopAtFine|'
        '$repeatsAfterJump|$pendingState|$repeatState|$firedState';
    if (!seenStates.add(state)) {
      throw ScorePerformanceNavigationException([
        ScorePerformanceNavigationIssue(
          code: ScorePerformanceNavigationIssueCode.cyclicNavigation,
          message: 'navigation revisits measure index $index in the same state',
          measureIndex: index,
        ),
      ]);
    }

    if (pendingBoundary?.playUntilIndex == index) {
      final boundary = pendingBoundary!;
      pendingBoundary = null;
      repeats.clear();
      sectionStart = boundary.continueAtIndex ?? score.measures.length;
      index = sectionStart;
      continue;
    }
    if (index >= score.measures.length) break;

    final measure = score.measures[index];
    final canRepeat = repeatEnabled(index);
    final canRepeatAtEnd = repeatEnabled(
      index,
      atEnd: true,
      frame: repeats.isEmpty ? null : repeats.last,
    );
    if (canRepeat || canRepeatAtEnd) {
      if (canRepeat &&
          navigation.repeatStarts.contains(index) &&
          (repeats.isEmpty || repeats.last.start != index)) {
        final end = _matchingRepeatEnd(
          navigation,
          index,
          score.measures.length,
        );
        final passes = _repeatPasses(
          score,
          navigation,
          index,
          end ?? score.measures.length - 1,
        );
        repeats.add(
          _PerformanceRepeatFrame(
            start: index,
            passes: passes,
            afterJump: navigation.repeatAtStart[index]?.afterJump,
          ),
        );
      }
      while (repeats.isNotEmpty &&
          repeats.last.jumpsLeft == 0 &&
          repeats.last.end != null &&
          measure.volta == null &&
          !navigation.passagePasses.containsKey(index) &&
          index > repeats.last.end!) {
        repeats.removeLast();
      }
      final pass = repeats.isEmpty ? 1 : repeats.last.pass;
      final modelPasses = measure.volta == null
          ? null
          : measure.voltaPasses.toSet();
      final passagePasses = navigation.passagePasses[index];
      if (modelPasses != null &&
          passagePasses != null &&
          !_sameIntSet(modelPasses, passagePasses)) {
        throw ScorePerformanceNavigationException([
          ScorePerformanceNavigationIssue(
            code: ScorePerformanceNavigationIssueCode.conflictingNavigation,
            message:
                'volta and passage pass numbers conflict at measure $index',
            measureIndex: index,
          ),
        ]);
      }
      final allowedPasses = modelPasses ?? passagePasses;
      if (allowedPasses != null && !allowedPasses.contains(pass)) {
        index++;
        continue;
      }
      if (allowedPasses != null &&
          repeats.isNotEmpty &&
          repeats.last.jumpsLeft == 0) {
        sectionStart = index + 1;
      }
    }

    if (order.length >= _maximumPlaybackMeasureOccurrences) {
      throw ScorePerformanceNavigationException([
        ScorePerformanceNavigationIssue(
          code: ScorePerformanceNavigationIssueCode
              .measureOccurrenceLimitExceeded,
          message:
              'playback exceeds $_maximumPlaybackMeasureOccurrences '
              'measure occurrences',
          measureIndex: index,
        ),
      ]);
    }
    order.add(index);
    if (stopAtFine && navigation.fineIndices.contains(index)) break;

    if (codaArmed) {
      final codaJump = navigation.codaJumpsByOrigin[index]
          ?.where(
            (jump) =>
                jump.appliesToPass(repeats.isEmpty ? 1 : repeats.last.pass),
          )
          .firstOrNull;
      if (codaJump != null) {
        codaArmed = false;
        repeats.clear();
        index = codaJump.destinationIndex;
        continue;
      }
    }

    if (canRepeatAtEnd && navigation.repeatEnds.contains(index)) {
      while (repeats.isNotEmpty &&
          repeats.last.jumpsLeft == 0 &&
          repeats.last.end != index) {
        repeats.removeLast();
      }
      if (repeats.isEmpty) {
        repeats.add(
          _PerformanceRepeatFrame(
            start: sectionStart,
            passes: _repeatPasses(score, navigation, sectionStart, index),
            afterJump: navigation.repeatAtEnd[index]?.afterJump,
          ),
        );
      }
      final frame = repeats.last;
      if (frame.jumpsLeft > 0) {
        frame.jumpsLeft--;
        frame.end = index;
        index = frame.start;
        continue;
      }
      repeats.removeLast();
      sectionStart = index + 1;
    }

    final pass = repeats.isEmpty ? 1 : repeats.last.pass;
    final jump = navigation.jumpsByOrigin[index]
        ?.where(
          (candidate) =>
              !firedJumps.contains(candidate.id) &&
              candidate.appliesToPass(pass),
        )
        .firstOrNull;
    if (jump != null) {
      firedJumps.add(jump.id);
      returnedFromJump = true;
      codaArmed = jump.armCoda;
      stopAtFine = jump.stopAtFine;
      repeatsAfterJump = jump.repeatsAfterJump ?? navigation.repeatsAfterJump;
      pendingBoundary = jump.playUntilIndex == null ? null : jump;
      repeats.clear();
      sectionStart = jump.destinationIndex;
      index = jump.destinationIndex;
      continue;
    }
    index++;
  }
  return order;
}

int? _matchingRepeatEnd(
  _PerformanceNavigation navigation,
  int start,
  int measureCount,
) {
  var depth = 0;
  for (var index = start; index < measureCount; index++) {
    if (navigation.repeatStarts.contains(index)) depth++;
    if (navigation.repeatEnds.contains(index)) {
      depth--;
      if (depth <= 0) return index;
    }
  }
  return null;
}

int _repeatPasses(
  Score score,
  _PerformanceNavigation navigation,
  int start,
  int end,
) {
  final declared =
      navigation.repeatAtEnd[end]?.passes ??
      navigation.repeatAtStart[start]?.passes;
  var voltaPasses = 1;
  bool hasEnding(int index) =>
      score.measures[index].volta != null ||
      navigation.passagePasses.containsKey(index);
  var firstEnding = end;
  while (firstEnding > start && hasEnding(firstEnding - 1)) {
    firstEnding--;
  }
  var lastEnding = end;
  while (lastEnding + 1 < score.measures.length &&
      hasEnding(lastEnding + 1) &&
      !navigation.repeatStarts.contains(lastEnding + 1)) {
    lastEnding++;
  }
  for (var index = firstEnding; index <= lastEnding; index++) {
    for (final pass in score.measures[index].voltaPasses) {
      if (pass > voltaPasses) voltaPasses = pass;
    }
    for (final pass in navigation.passagePasses[index] ?? const <int>{}) {
      if (pass > voltaPasses) voltaPasses = pass;
    }
  }
  return declared == null
      ? (voltaPasses < 2 ? 2 : voltaPasses)
      : (declared < voltaPasses ? voltaPasses : declared);
}

bool _sameIntSet(Set<int> first, Set<int> second) =>
    first.length == second.length && first.containsAll(second);

List<Fraction> _measureDurations(Score score) {
  final durations = <Fraction>[];
  var meter = score.timeSignature;
  for (final (index, measure) in score.measures.indexed) {
    meter = measure.timeChange ?? meter;
    final source = _measureRepeatSourceIndex(score, index);
    if (source != index && source < durations.length) {
      durations.add(durations[source]);
      continue;
    }
    if (measure.multiRest != null && meter != null) {
      durations.add(Fraction(meter.beats * measure.multiRest!, meter.beatUnit));
      continue;
    }
    final capacity = measure.capacityGiven(meter);
    var longest = Fraction.zero;
    for (final (voice, elements) in [
      measure.elements,
      measure.voice2,
      measure.voice3,
      measure.voice4,
    ].indexed) {
      var end = Fraction.zero;
      if (elements.length == 1 &&
          elements.single is RestElement &&
          capacity != null) {
        end = capacity;
      } else {
        for (var i = 0; i < elements.length; i++) {
          end += measure.effectiveDurationAt(i, voice: voice);
        }
      }
      if (end > longest) longest = end;
    }
    if (longest == Fraction.zero && meter != null) {
      longest = Fraction(meter.beats, meter.beatUnit);
    }
    durations.add(longest);
  }
  return durations;
}

int _measureRepeatSourceIndex(Score score, int index) {
  var source = index;
  for (var guard = 0; guard < score.measures.length; guard++) {
    final count = score.measures[source].measureRepeat;
    if (count == null || source - count < 0) return source;
    source -= count;
  }
  return index;
}

List<ScorePerformanceTempoChange> _tempoChanges(
  Score score,
  List<ScorePerformanceMeasureOccurrence> occurrences,
  double initialBpm,
) {
  final changes = <ScorePerformanceTempoChange>[
    ScorePerformanceTempoChange(
      origin: const ScorePerformanceOrigin(
        staffIndex: 0,
        measureIndex: 0,
        voice: 0,
      ),
      start: Fraction.zero,
      quarterBpm: initialBpm,
    ),
  ];
  var currentBpm = initialBpm;
  for (final occurrence in occurrences) {
    final change = score.measures[occurrence.measureIndex].tempoChange;
    if (change == null || change.quarterBpm == currentBpm) continue;
    currentBpm = change.quarterBpm;
    final next = ScorePerformanceTempoChange(
      origin: ScorePerformanceOrigin(
        staffIndex: 0,
        measureIndex: occurrence.measureIndex,
        voice: 0,
      ),
      start: occurrence.start,
      quarterBpm: currentBpm,
    );
    if (occurrence.start == Fraction.zero) {
      changes[0] = next;
    } else {
      changes.add(next);
    }
  }
  return changes;
}
