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
  test('arpeggio direction staggers pitches without changing event bounds', () {
    final document = _document([
      _score([
        Measure([
          NoteElement(
            pitches: [Pitch(Step.c), Pitch(Step.e), Pitch(Step.g)],
            duration: NoteDuration.quarter,
            arpeggio: Arpeggio.up,
            id: 'up',
          ),
          NoteElement(
            pitches: [
              Pitch(Step.c, octave: 5),
              Pitch(Step.e, octave: 5),
              Pitch(Step.g, octave: 5),
            ],
            duration: NoteDuration.quarter,
            arpeggio: Arpeggio.down,
            id: 'down',
          ),
        ]),
      ]),
      _score([
        Measure([
          NoteElement.note(Pitch(Step.a), NoteDuration.quarter, id: 'sync'),
        ]),
      ]),
    ]);
    final plan = ScorePerformancePlan.fromDocument(document);
    final map = ScorePlaybackMap.fromPlan(plan);
    final midi = sk.MidiReader.fromBytes(
      buildScoreMidi(document, performancePlan: plan),
    );

    expect(_attacks(midi, [60, 64, 67]), [(60, 0), (64, 60), (67, 120)]);
    expect(_attacks(midi, [72, 76, 79]), [(79, 480), (76, 540), (72, 600)]);
    for (final pitch in [60, 64, 67]) {
      expect(_pitchEvents(midi, pitch), [
        (false, _attackTick(midi, pitch)),
        (true, 480),
      ]);
    }
    for (final pitch in [72, 76, 79]) {
      expect(_pitchEvents(midi, pitch), [
        (false, _attackTick(midi, pitch)),
        (true, 960),
      ]);
    }

    expect(map.startOfElement('up'), Duration.zero);
    expect(map.endOfMeasure(0), const Duration(seconds: 1));
    expect(map.soundingAt(const Duration(milliseconds: 250)), contains('up'));
    expect(
      _attacks(midi, [69]).first.$2,
      0,
      reason: 'the other staff remains synchronized at the source onset',
    );
    expect(plan.timelines[0].first.start, plan.timelines[1].first.start);
  });

  test('arpeggio stagger stays within a short tuplet source event', () {
    final document = _document([
      _score([
        Measure(
          [
            NoteElement(
              pitches: [
                Pitch(Step.c),
                Pitch(Step.e),
                Pitch(Step.g),
                Pitch(Step.c, octave: 5),
                Pitch(Step.e, octave: 5),
              ],
              duration: NoteDuration.eighth,
              arpeggio: Arpeggio.up,
              id: 'short-tuplet-arpeggio',
            ),
          ],
          tuplets: const [TupletSpan(0, 0, actual: 3, normal: 2)],
        ),
      ]),
    ]);
    final midi = sk.MidiReader.fromBytes(buildScoreMidi(document));

    expect(_pitchEvents(midi, 60), [(false, 0), (true, 160)]);
    expect(_pitchEvents(midi, 64), [(false, 32), (true, 160)]);
    expect(_pitchEvents(midi, 67), [(false, 64), (true, 160)]);
    expect(_pitchEvents(midi, 72), [(false, 96), (true, 160)]);
    expect(_pitchEvents(midi, 76), [(false, 128), (true, 160)]);
  });

  test(
    'overlapping same-pitch notes defer release until the longer note ends',
    () {
      final document = _document([
        _score([
          Measure(
            [NoteElement.note(Pitch(Step.c), NoteDuration.half, id: 'long')],
            voice2: [
              RestElement(NoteDuration.quarter),
              NoteElement.note(Pitch(Step.c), NoteDuration.eighth, id: 'short'),
            ],
            voice3: [
              RestElement(NoteDuration.half),
              NoteElement.note(
                Pitch(Step.c),
                NoteDuration.quarter,
                id: 'boundary',
              ),
            ],
          ),
        ]),
      ]);
      final midi = sk.MidiReader.fromBytes(buildScoreMidi(document));

      expect(_pitchEvents(midi, 60), [
        (false, 0),
        (false, 480),
        (true, 960),
        (false, 960),
        (true, 1440),
      ]);
      final boundaryEvents = midi.tracks.single.events
          .where(
            (event) =>
                event.absoluteTick == 960 &&
                ((event is sk.NoteOnEvent && event.note == 60) ||
                    (event is sk.NoteOffEvent && event.note == 60)),
          )
          .map((event) => event is sk.NoteOffEvent ? 'off' : 'on')
          .toList();
      expect(boundaryEvents, ['off', 'on']);
    },
  );

  test(
    'explicit tremolo strokes subdivide tuplets without extending events',
    () {
      final document = _document([
        _score([
          Measure(
            [
              NoteElement.note(
                Pitch(Step.g),
                NoteDuration.eighth,
                tremolo: 2,
                id: 'short-tremolo',
              ),
              NoteElement.note(Pitch(Step.a), NoteDuration.eighth, id: 'after'),
              NoteElement.note(Pitch(Step.b), NoteDuration.eighth, id: 'last'),
            ],
            tuplets: const [TupletSpan(0, 2, actual: 3, normal: 2)],
          ),
        ]),
      ]);
      final plan = ScorePerformancePlan.fromDocument(document);
      final event = plan.events.singleWhere(
        (item) => item.origin.elementId == 'short-tremolo',
      );
      final midi = sk.MidiReader.fromBytes(
        buildScoreMidi(document, performancePlan: plan),
      );

      expect(event.duration, Fraction(1, 12));
      expect(_pitchEvents(midi, 67), [
        (false, 0),
        (true, 120),
        (false, 120),
        (true, 160),
      ]);
      expect(_pitchEvents(midi, 69).first, (false, 160));
    },
  );

  test('unstroked MusicXML tremolo defaults to thirty-second notes', () {
    final document = parseScoreDocument(
      File('test/fixtures/scores/musicxml_tremolo_default.musicxml')
          .readAsBytesSync(),
    );
    final plan = ScorePerformancePlan.fromDocument(document);
    final midi = sk.MidiReader.fromBytes(
      buildScoreMidi(document, performancePlan: plan),
    );
    final tremolo = plan.events.firstWhere(
      (event) => event.tremoloStrokes != null,
    );

    expect(document.musicXmlPerformance!.tremolos.single.strokes, isNull);
    expect(tremolo.tremoloStrokes, 3);
    expect(_pitchEvents(midi, 60), [
      (false, 0),
      (true, 60),
      (false, 60),
      (true, 120),
      (false, 120),
      (true, 180),
      (false, 180),
      (true, 240),
      (false, 240),
      (true, 300),
      (false, 300),
      (true, 360),
      (false, 360),
      (true, 420),
      (false, 420),
      (true, 480),
    ]);
  });

  test('pedal spans route CC64 and overlap without premature release', () {
    final document = _document([
      _score(
        [
          Measure([
            NoteElement.note(
              Pitch(Step.c),
              NoteDuration.quarter,
              id: 'pedal-1',
            ),
            NoteElement.note(
              Pitch(Step.d),
              NoteDuration.quarter,
              id: 'pedal-2',
            ),
            NoteElement.note(
              Pitch(Step.e),
              NoteDuration.quarter,
              id: 'pedal-3',
            ),
            NoteElement.note(
              Pitch(Step.f),
              NoteDuration.quarter,
              id: 'pedal-4',
            ),
          ]),
        ],
        pedals: const [
          Pedal('pedal-1', 'pedal-3'),
          Pedal('pedal-2', 'pedal-4'),
        ],
      ),
    ]);
    final plan = ScorePerformancePlan.fromDocument(document);
    final midi = sk.MidiReader.fromBytes(
      buildScoreMidi(document, performancePlan: plan),
    );

    expect(
      plan.controlChanges.map(
        (change) => (
          change.origin.staffIndex,
          change.start,
          change.controller,
          change.value,
        ),
      ),
      [(0, Fraction.zero, 64, 127), (0, Fraction(1, 1), 64, 0)],
    );
    expect(_controlEvents(midi), [(0, 64, 127, 0), (0, 64, 0, 1920)]);
  });
}

ScoreDocument _document(List<Score> scores) => ScoreDocument(
  score: MultiPartScore(scores),
  staves: [
    for (var index = 0; index < scores.length; index++)
      ScoreStaff(index: index, partName: 'Staff $index'),
  ],
  format: ScoreSourceFormat.musicXml,
);

Score _score(List<Measure> measures, {List<Pedal> pedals = const []}) => Score(
  clef: Clef.treble,
  timeSignature: const TimeSignature(4, 4),
  measures: measures,
  pedals: pedals,
);

List<(int, int)> _attacks(sk.MidiFile midi, List<int> pitches) => [
  for (final track in midi.tracks)
    for (final event in track.events)
      if (event is sk.NoteOnEvent &&
          !event.isNoteOff &&
          pitches.contains(event.note))
        (event.note, event.absoluteTick),
];

List<(bool, int)> _pitchEvents(sk.MidiFile midi, int pitch) => [
  for (final event in midi.tracks.first.events)
    if (event is sk.NoteOnEvent && event.note == pitch)
      (event.isNoteOff, event.absoluteTick)
    else if (event is sk.NoteOffEvent && event.note == pitch)
      (true, event.absoluteTick),
];

int _attackTick(sk.MidiFile midi, int pitch) => midi.tracks.first.events
    .whereType<sk.NoteOnEvent>()
    .firstWhere((event) => event.note == pitch && !event.isNoteOff)
    .absoluteTick;

List<(int, int, int, int)> _controlEvents(sk.MidiFile midi) => [
  for (final event in midi.tracks.first.events)
    if (event is sk.ControlChangeEvent && event.controller == 64)
      (event.channel, event.controller, event.value, event.absoluteTick),
];
