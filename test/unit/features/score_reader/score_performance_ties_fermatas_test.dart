import 'dart:io';

import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_performance_plan.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_playback_map.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundfont_kit/soundfont_kit.dart' as sk;

void main() {
  test('imports a rest fermata missing from the notation model', () {
    final document = parseScoreDocument(
      File('test/fixtures/scores/musicxml_rest_fermata.musicxml')
          .readAsBytesSync(),
    );
    final rest = document.score.parts.single.measures.single.elements
        .whereType<RestElement>()
        .single;

    expect(rest.id, isNotNull);
    expect(document.musicXmlPerformance!.fermatas, hasLength(1));
    expect(document.musicXmlPerformance!.fermatas.single.isRest, isTrue);
    expect(
      document.musicXmlPerformance!.fermatas.single.origin.onset?.quarterNotes,
      0,
    );

    final plan = ScorePerformancePlan.fromDocument(document);
    final map = ScorePlaybackMap.fromPlan(plan);
    expect(map.duration, const Duration(milliseconds: 2500));
    expect(
      map.startOfElement(
        document.score.parts.single.measures.single.elements
            .whereType<NoteElement>()
            .first
            .id!,
      ),
      const Duration(seconds: 1),
    );
    final midi = sk.MidiReader.fromBytes(
      buildScoreMidi(document, performancePlan: plan),
    );
    expect(_pitchEvents(midi, 60), [(false, 960), (true, 1440)]);
  });

  test('one duplicated fermata extends every staff and the final duration', () {
    final document = _document([
      _score([
        _measure([
          _note(Step.c, 'upper-fermata', fermata: true),
          _note(Step.d, 'upper-after'),
          _note(Step.e, 'upper-third'),
          _note(Step.f, 'upper-fourth'),
        ]),
        _measure(_fourNotes('upper-final')),
      ]),
      _score([
        _measure([
          _note(Step.c, 'lower-fermata', fermata: true),
          _note(Step.d, 'lower-after'),
          _note(Step.e, 'lower-third'),
          _note(Step.f, 'lower-fourth'),
        ]),
        _measure(_fourNotes('lower-final')),
      ]),
      _score([
        _measure([
          _note(Step.g, 'unmarked-simultaneous'),
          _note(Step.a, 'unmarked-after'),
          _note(Step.b, 'unmarked-third'),
          _note(Step.c, 'unmarked-fourth'),
        ]),
        _measure(_fourNotes('unmarked-final')),
      ]),
    ]);
    final plan = ScorePerformancePlan.fromDocument(document);
    final map = ScorePlaybackMap.fromPlan(plan);

    expect(map.duration, const Duration(milliseconds: 4500));
    expect(plan.totalWholeNotes, Fraction(9, 4));
    expect(map.endOfMeasure(0), const Duration(milliseconds: 2500));
    expect(map.startOfMeasure(1), const Duration(milliseconds: 2500));
    expect(map.endOfMeasure(1), const Duration(milliseconds: 4500));
    expect(map.startOfElement('upper-after'), const Duration(seconds: 1));
    expect(map.startOfElement('lower-after'), const Duration(seconds: 1));
    expect(
      map.soundingAt(const Duration(milliseconds: 750)),
      containsAll(['upper-fermata', 'lower-fermata', 'unmarked-simultaneous']),
    );
    expect(map.measureAt(const Duration(milliseconds: 750)), 0);
    expect(map.measureAt(const Duration(milliseconds: 2600)), 1);
    expect(map.measureAt(const Duration(milliseconds: 4500)), isNull);

    final midi = sk.MidiReader.fromBytes(
      buildScoreMidi(document, performancePlan: plan),
    );
    final unmarkedNote = _pitchEvents(midi, 67, trackIndex: 2);
    expect(unmarkedNote, [(false, 0), (true, 960)]);
    expect(midi.totalTicks, 4320);
  });

  test(
    'tied equal pitches have one MIDI attack and keep both origins active',
    () {
      final document = _document([
        _score([
          _measure([
            NoteElement.note(
              Pitch(Step.c),
              NoteDuration.quarter,
              tieToNext: true,
              id: 'tie-start',
            ),
            _note(Step.c, 'tie-end'),
            _note(Step.d, 'after-tie'),
            _note(Step.e, 'fourth'),
          ]),
        ]),
      ]);
      final plan = ScorePerformancePlan.fromDocument(document);
      final map = ScorePlaybackMap.fromPlan(plan);
      final midi = sk.MidiReader.fromBytes(
        buildScoreMidi(document, performancePlan: plan),
      );

      expect(_pitchEvents(midi, 60), [(false, 0), (true, 960)]);
      expect(
        map.soundingAt(const Duration(milliseconds: 750)),
        containsAll(['tie-start', 'tie-end']),
      );
    },
  );

  test('partial chord ties sustain only matching pitches', () {
    final document = _document([
      _score([
        _measure([
          NoteElement(
            pitches: [Pitch(Step.c), Pitch(Step.e)],
            duration: NoteDuration.quarter,
            tieToNext: true,
            id: 'partial-start',
          ),
          NoteElement(
            pitches: [Pitch(Step.c), Pitch(Step.g)],
            duration: NoteDuration.quarter,
            id: 'partial-end',
          ),
          _note(Step.a, 'third'),
          _note(Step.b, 'fourth'),
        ]),
      ]),
    ]);
    final midi = sk.MidiReader.fromBytes(buildScoreMidi(document));

    expect(_pitchEvents(midi, 60), [(false, 0), (true, 960)]);
    expect(_pitchEvents(midi, 64), [(false, 0), (true, 480)]);
    expect(_pitchEvents(midi, 67), [(false, 480), (true, 960)]);
  });

  test(
    'staccato, tenuto and staccatissimo use 50%, 95% and 25% MIDI lengths',
    () {
      final document = _document([
        _score([
          _measure([
            _note(Step.c, 'staccato', articulations: {Articulation.staccato}),
            _note(Step.d, 'tenuto', articulations: {Articulation.tenuto}),
            _note(
              Step.e,
              'staccatissimo',
              articulations: {Articulation.staccatissimo},
            ),
            _note(Step.f, 'accent', articulations: {Articulation.accent}),
          ]),
          _measure([
            _note(Step.g, 'marcato', articulations: {Articulation.marcato}),
            _note(Step.a, 'plain-two'),
            _note(Step.b, 'plain-three'),
            _note(Step.c, 'plain-four'),
          ]),
        ]),
      ]);
      final midi = sk.MidiReader.fromBytes(buildScoreMidi(document));

      expect(_pitchEvents(midi, 60), [
        (false, 0),
        (true, 240),
        (false, 3360),
        (true, 3840),
      ]);
      expect(_pitchEvents(midi, 62), [(false, 480), (true, 936)]);
      expect(_pitchEvents(midi, 64), [(false, 960), (true, 1080)]);
      expect(_noteOffTick(midi, 60, onset: 0), 240);
      expect(_noteOffTick(midi, 62, onset: 480), 936);
      expect(_noteOffTick(midi, 64, onset: 960), 1080);
      expect(_noteOffTick(midi, 65, onset: 1440), 1920);
      expect(_noteOffTick(midi, 67, onset: 1920), 2400);
      expect(_noteOn(midi, 65).velocity, 95);
      expect(_noteOn(midi, 67).velocity, 100);
    },
  );

  test(
    'a fermata in a repeated final measure extends each occurrence once',
    () {
      final document = _document([
        _score([
          _measure(_fourNotes('repeat-first'), startRepeat: true),
          _measure([
            _note(Step.g, 'last-first'),
            _note(Step.a, 'last-second'),
            _note(Step.b, 'last-third'),
            _note(Step.c, 'final-fermata', fermata: true),
          ], endRepeat: true),
        ]),
      ]);
      final plan = ScorePerformancePlan.fromDocument(document);
      final map = ScorePlaybackMap.fromPlan(plan);

      expect(plan.measureOccurrences.map((item) => item.measureIndex), [
        0,
        1,
        0,
        1,
      ]);
      expect(map.duration, const Duration(seconds: 9));
      expect(plan.totalWholeNotes, Fraction(9, 2));
      expect(map.measureAt(const Duration(milliseconds: 8500)), 1);
      expect(map.measureAt(const Duration(seconds: 9)), isNull);

      final midi = sk.MidiReader.fromBytes(
        buildScoreMidi(document, performancePlan: plan),
      );
      final finalNotes = _pitchEvents(midi, 60);
      expect(finalNotes, [
        (false, 0),
        (true, 480),
        (false, 3360),
        (true, 4320),
        (false, 4320),
        (true, 4800),
        (false, 7680),
        (true, 8640),
      ]);
      expect(midi.totalTicks, 8640);
    },
  );

  test('a fermata extension follows D.C. al Fine navigation', () {
    final document = _document([
      _score([
        _measure([
          _note(Step.c, 'navigation-fermata', fermata: true),
          _note(Step.d, 'navigation-first-after'),
          _note(Step.e, 'navigation-third'),
          _note(Step.f, 'navigation-fourth'),
        ], navigation: NavigationMark.fine),
        _measure(
          _fourNotes('navigation-return'),
          navigation: NavigationMark.daCapoAlFine,
        ),
      ]),
    ]);
    final plan = ScorePerformancePlan.fromDocument(document);
    final map = ScorePlaybackMap.fromPlan(plan);

    expect(plan.measureOccurrences.map((item) => item.measureIndex), [0, 1, 0]);
    expect(map.duration, const Duration(seconds: 7));
    expect(map.measureAt(const Duration(milliseconds: 5250)), 0);
    expect(
      map.soundingAt(const Duration(milliseconds: 5250)),
      contains('navigation-fermata'),
    );
    expect(map.endOfMeasure(0), const Duration(milliseconds: 2500));

    final midi = sk.MidiReader.fromBytes(
      buildScoreMidi(document, performancePlan: plan),
    );
    expect(_pitchEvents(midi, 60), [
      (false, 0),
      (true, 960),
      (false, 2400),
      (true, 2880),
      (false, 4320),
      (true, 5280),
    ]);
    expect(midi.totalTicks, 6720);
  });
}

ScoreDocument _document(List<Score> parts) => ScoreDocument(
  score: MultiPartScore(parts),
  staves: [
    for (final (index, _) in parts.indexed)
      ScoreStaff(index: index, partName: 'Staff $index'),
  ],
  format: ScoreSourceFormat.musicXml,
);

Score _score(List<Measure> measures) => Score(
  clef: Clef.treble,
  timeSignature: const TimeSignature(4, 4),
  measures: measures,
);

Measure _measure(
  List<MusicElement> elements, {
  bool startRepeat = false,
  bool endRepeat = false,
  NavigationMark? navigation,
}) => Measure(
  elements,
  startRepeat: startRepeat,
  endRepeat: endRepeat,
  navigation: navigation,
);

List<MusicElement> _fourNotes(String prefix) => [
  _note(Step.c, '$prefix-1'),
  _note(Step.d, '$prefix-2'),
  _note(Step.e, '$prefix-3'),
  _note(Step.f, '$prefix-4'),
];

NoteElement _note(
  Step step,
  String id, {
  bool fermata = false,
  Set<Articulation> articulations = const {},
}) => NoteElement.note(
  Pitch(step),
  NoteDuration.quarter,
  id: id,
  articulations: {...articulations, if (fermata) Articulation.fermata},
);

List<(bool, int)> _pitchEvents(
  sk.MidiFile midi,
  int pitch, {
  int trackIndex = 0,
}) => [
  for (final event in midi.tracks[trackIndex].events)
    if (event is sk.NoteOnEvent && event.note == pitch)
      (event.isNoteOff, event.absoluteTick)
    else if (event is sk.NoteOffEvent && event.note == pitch)
      (true, event.absoluteTick),
];

int _noteOffTick(sk.MidiFile midi, int pitch, {required int onset}) =>
    _pitchEvents(
      midi,
      pitch,
    ).firstWhere((event) => event.$1 && event.$2 > onset).$2;

sk.NoteOnEvent _noteOn(sk.MidiFile midi, int pitch) =>
    _pitchEvents(midi, pitch).isNotEmpty
    ? midi.tracks.single.events.whereType<sk.NoteOnEvent>().singleWhere(
        (event) => event.note == pitch && !event.isNoteOff,
      )
    : throw StateError('missing note-on for pitch $pitch');
