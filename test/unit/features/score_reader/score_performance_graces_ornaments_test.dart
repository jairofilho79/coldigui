import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/entities/musescore_performance_metadata.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_performance_plan.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_playback_map.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart' hide Interval;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundfont_kit/soundfont_kit.dart' as sk;

void main() {
  test(
    'trill alternates in fusas during the first half and ends principal',
    () {
      final document = _document(
        NoteElement.note(
          const Pitch(Step.c),
          NoteDuration.quarter,
          ornament: Ornament.trill,
          id: 'trill',
        ),
      );
      final midi = sk.MidiReader.fromBytes(buildScoreMidi(document));
      final map = ScorePlaybackMap.fromDocument(document);

      expect(_eventsForPitches(midi, {60, 62}), [
        (60, 0, false),
        (60, 60, true),
        (62, 60, false),
        (62, 120, true),
        (60, 120, false),
        (60, 180, true),
        (62, 180, false),
        (62, 240, true),
        (60, 240, false),
        (60, 480, true),
      ]);
      expect(map.performancePlan.totalWholeNotes, Fraction(1, 1));
      expect(map.duration, const Duration(seconds: 2));
      expect(map.startOfElement('trill'), Duration.zero);
      expect(
        map.soundingAt(const Duration(milliseconds: 100)),
        contains('trill'),
      );
      expect(
        map.soundingAt(const Duration(milliseconds: 450)),
        contains('trill'),
      );
    },
  );

  test('mordents, short trills, and turns use exact diatonic patterns', () {
    final cases = <(Ornament, Pitch, List<(int, int, bool)>)>[
      (
        Ornament.mordent,
        const Pitch(Step.e),
        [
          (64, 0, false),
          (64, 80, true),
          (62, 80, false),
          (62, 160, true),
          (64, 160, false),
          (64, 480, true),
        ],
      ),
      (
        Ornament.shortTrill,
        const Pitch(Step.e),
        [
          (64, 0, false),
          (64, 80, true),
          (65, 80, false),
          (65, 160, true),
          (64, 160, false),
          (64, 480, true),
        ],
      ),
      (
        Ornament.turn,
        const Pitch(Step.d),
        [
          (64, 0, false),
          (64, 60, true),
          (62, 60, false),
          (62, 120, true),
          (60, 120, false),
          (60, 180, true),
          (62, 180, false),
          (62, 480, true),
        ],
      ),
      (
        Ornament.invertedTurn,
        const Pitch(Step.d),
        [
          (60, 0, false),
          (60, 60, true),
          (62, 60, false),
          (62, 120, true),
          (64, 120, false),
          (64, 180, true),
          (62, 180, false),
          (62, 480, true),
        ],
      ),
    ];

    for (final (ornament, pitch, expected) in cases) {
      final document = _document(
        NoteElement.note(
          pitch,
          NoteDuration.quarter,
          ornament: ornament,
          id: ornament.name,
        ),
      );
      final midi = sk.MidiReader.fromBytes(buildScoreMidi(document));

      expect(
        _eventsForPitches(midi, {for (final event in expected) event.$1}),
        expected,
        reason: ornament.name,
      );
    }
  });

  test('trill accidental variants override key signature', () {
    final cases = <(Ornament, int)>[
      (Ornament.trillSharp, 63),
      (Ornament.trillFlat, 61),
      (Ornament.trillNatural, 62),
    ];

    for (final (ornament, auxiliaryPitch) in cases) {
      final document = _document(
        NoteElement.note(
          const Pitch(Step.c),
          NoteDuration.quarter,
          ornament: ornament,
        ),
        keySignature: const KeySignature(1),
      );
      final midi = sk.MidiReader.fromBytes(buildScoreMidi(document));

      expect(_eventsForPitches(midi, {60, auxiliaryPitch}), [
        (60, 0, false),
        (60, 60, true),
        (auxiliaryPitch, 60, false),
        (auxiliaryPitch, 120, true),
        (60, 120, false),
        (60, 180, true),
        (auxiliaryPitch, 180, false),
        (auxiliaryPitch, 240, true),
        (60, 240, false),
        (60, 480, true),
      ], reason: ornament.name);
    }
  });

  test('auxiliary pitch honors key signature and prior measure accidental', () {
    final keyed = _document(
      NoteElement.note(
        const Pitch(Step.e),
        NoteDuration.quarter,
        ornament: Ornament.trill,
      ),
      keySignature: const KeySignature(1),
    );
    final keyedMidi = sk.MidiReader.fromBytes(buildScoreMidi(keyed));
    expect(_eventsForPitches(keyedMidi, {64, 66}), [
      (64, 0, false),
      (64, 60, true),
      (66, 60, false),
      (66, 120, true),
      (64, 120, false),
      (64, 180, true),
      (66, 180, false),
      (66, 240, true),
      (64, 240, false),
      (64, 480, true),
    ]);

    final accidental = _document(
      NoteElement.note(
        const Pitch(Step.f),
        NoteDuration.quarter,
        showAccidental: true,
      ),
      second: NoteElement.note(
        const Pitch(Step.e),
        NoteDuration.quarter,
        ornament: Ornament.trill,
        id: 'after-f-natural',
      ),
      keySignature: const KeySignature(1),
    );
    final accidentalMidi = sk.MidiReader.fromBytes(buildScoreMidi(accidental));
    expect(_eventsForPitches(accidentalMidi, {64, 65}), [
      (65, 0, false),
      (65, 480, true),
      (64, 480, false),
      (64, 540, true),
      (65, 540, false),
      (65, 600, true),
      (64, 600, false),
      (64, 660, true),
      (65, 660, false),
      (65, 720, true),
      (64, 720, false),
      (64, 960, true),
    ]);
  });

  test('acciaccaturas and appoggiaturas use defaults and share grace time', () {
    final acciaccatura = _document(
      NoteElement.note(
        const Pitch(Step.c),
        NoteDuration.quarter,
        graceNotes: [
          const Pitch(Step.g, octave: 3),
          const Pitch(Step.a, octave: 3),
        ],
        id: 'acciaccatura-main',
      ),
    );
    final acciaccaturaMidi = sk.MidiReader.fromBytes(
      buildScoreMidi(acciaccatura),
    );
    final acciaccaturaMap = ScorePlaybackMap.fromDocument(acciaccatura);

    expect(_eventsForPitches(acciaccaturaMidi, {55, 57, 60}), [
      (55, 0, false),
      (55, 60, true),
      (57, 60, false),
      (57, 120, true),
      (60, 120, false),
      (60, 480, true),
    ]);
    expect(acciaccaturaMap.performancePlan.totalWholeNotes, Fraction(1, 1));
    expect(acciaccaturaMap.startOfElement('acciaccatura-main'), Duration.zero);
    expect(
      acciaccaturaMap.soundingAt(const Duration(milliseconds: 50)),
      contains('acciaccatura-main'),
    );

    final appoggiatura = _document(
      NoteElement.note(
        const Pitch(Step.c),
        NoteDuration.quarter,
        graceNotes: [const Pitch(Step.g)],
        graceStyle: GraceStyle.appoggiatura,
        id: 'appoggiatura-main',
      ),
    );
    final appoggiaturaMidi = sk.MidiReader.fromBytes(
      buildScoreMidi(appoggiatura),
    );
    expect(_eventsForPitches(appoggiaturaMidi, {60, 67}), [
      (67, 0, false),
      (67, 240, true),
      (60, 240, false),
      (60, 480, true),
    ]);
    expect(
      ScorePlaybackMap.fromDocument(appoggiatura)
          .performancePlan
          .totalWholeNotes,
      Fraction(1, 1),
    );
  });

  test('a grace tied into the principal does not reattack its pitch', () {
    final document = _document(
      NoteElement.note(
        const Pitch(Step.c),
        NoteDuration.quarter,
        graceNotes: [const Pitch(Step.d), const Pitch(Step.c)],
        graceTiesToMain: {1},
        id: 'tied-grace-main',
      ),
    );
    final midi = sk.MidiReader.fromBytes(buildScoreMidi(document));
    final map = ScorePlaybackMap.fromDocument(document);

    expect(_eventsForPitches(midi, {60, 62}), [
      (62, 0, false),
      (62, 60, true),
      (60, 60, false),
      (60, 480, true),
    ]);
    expect(
      map.soundingAt(const Duration(milliseconds: 450)),
      contains('tied-grace-main'),
    );
  });

  test(
    'short tuplet graces stay inside the source event with positive ticks',
    () {
      final score = Score(
        clef: Clef.treble,
        timeSignature: const TimeSignature(4, 4),
        measures: [
          Measure(
            [
              NoteElement.note(
                const Pitch(Step.c),
                NoteDuration.eighth,
                graceNotes: [const Pitch(Step.d), const Pitch(Step.e)],
                id: 'tuplet-grace-main',
              ),
              RestElement(NoteDuration.eighth),
              RestElement(NoteDuration.eighth),
            ],
            tuplets: const [TupletSpan(0, 2, actual: 3, normal: 2)],
          ),
        ],
      );
      final document = _documentForScore(score);
      final midi = sk.MidiReader.fromBytes(buildScoreMidi(document));
      final map = ScorePlaybackMap.fromDocument(document);
      final events = _eventsForPitches(midi, {60, 62, 64});

      expect(events, [
        (62, 0, false),
        (62, 20, true),
        (64, 20, false),
        (64, 40, true),
        (60, 40, false),
        (60, 160, true),
      ]);
      expect(map.performancePlan.totalWholeNotes, Fraction(1, 4));
      expect(map.duration, const Duration(milliseconds: 500));
      for (final (pitch, onTick, isOff) in events) {
        if (isOff) {
          expect(onTick, greaterThan(0), reason: 'note $pitch');
        }
      }
    },
  );

  test(
    'explicit MusicXML make-time shifts every staff and extends the bar',
    () {
      final document = _musicXmlDocument(
        graceAttributes: 'slash="yes" make-time="2"',
        includeSecondStaff: true,
      );
      final plan = ScorePerformancePlan.fromDocument(document);
      final map = ScorePlaybackMap.fromPlan(plan);
      final midi = sk.MidiReader.fromBytes(
        buildScoreMidi(document, performancePlan: plan),
      );

      expect(_eventsForPitches(midi, {67, 60}), [
        (67, 0, false),
        (67, 240, true),
        (60, 240, false),
        (60, 720, true),
      ]);
      expect(_eventsForPitches(midi, {57}, trackIndex: 1), [
        (57, 240, false),
        (57, 2160, true),
      ]);
      expect(plan.totalWholeNotes, Fraction(9, 8));
      expect(map.duration, const Duration(milliseconds: 2250));
      expect(map.endOfMeasure(0), const Duration(milliseconds: 2250));
      expect(midi.totalTicks, 2160);
    },
  );

  test('explicit steal-time-following overrides the acciaccatura default', () {
    final document = _musicXmlDocument(
      graceAttributes: 'slash="yes" steal-time-following="50"',
    );
    final plan = ScorePerformancePlan.fromDocument(document);
    final midi = sk.MidiReader.fromBytes(
      buildScoreMidi(document, performancePlan: plan),
    );

    expect(_eventsForPitches(midi, {67, 60}), [
      (67, 0, false),
      (67, 240, true),
      (60, 240, false),
      (60, 480, true),
    ]);
    expect(plan.totalWholeNotes, Fraction(1, 1));
    expect(midi.totalTicks, 1920);
  });

  test(
    'grace pitches honor key signatures and explicit natural accidentals',
    () {
      final keyed = _musicXmlDocument(
        graceAttributes: 'slash="yes"',
        gracePitch: 'F',
        keyFifths: 1,
      );
      final keyedMidi = sk.MidiReader.fromBytes(buildScoreMidi(keyed));
      expect(
        _eventsForPitches(keyedMidi, {66}).where((event) => event.$2 <= 120),
        [(66, 0, false), (66, 120, true)],
      );

      final natural = _musicXmlDocument(
        graceAttributes: 'slash="yes"',
        gracePitch: 'F',
        graceAlter: '<alter>0</alter>',
        keyFifths: 1,
      );
      final naturalMidi = sk.MidiReader.fromBytes(buildScoreMidi(natural));
      expect(
        _eventsForPitches(naturalMidi, {65}).where((event) => event.$2 <= 120),
        [(65, 0, false), (65, 120, true)],
      );
    },
  );

  test('MusicXML accidental mark overrides the ornament auxiliary pitch', () {
    final document = _musicXmlDocument(
      graceAttributes: 'slash="yes"',
      ornamentMark: '<trill-mark/><accidental-mark>sharp</accidental-mark>',
      includeGrace: false,
    );
    final midi = sk.MidiReader.fromBytes(buildScoreMidi(document));
    expect(_eventsForPitches(midi, {60, 63}), [
      (60, 0, false),
      (60, 60, true),
      (63, 60, false),
      (63, 120, true),
      (60, 120, false),
      (60, 180, true),
      (63, 180, false),
      (63, 240, true),
      (60, 240, false),
      (60, 480, true),
    ]);
  });

  test(
    'steal-time-previous shortens the prior note and keeps grace origin',
    () {
      final score = Score(
        clef: Clef.treble,
        timeSignature: const TimeSignature(4, 4),
        measures: [
          Measure([
            NoteElement.note(
              const Pitch(Step.c),
              NoteDuration.quarter,
              id: 'previous',
            ),
            NoteElement.note(
              const Pitch(Step.d),
              NoteDuration.quarter,
              graceNotes: [const Pitch(Step.g)],
              id: 'grace-main',
            ),
            RestElement(NoteDuration.quarter),
            RestElement(NoteDuration.quarter),
          ]),
        ],
      );
      final document = ScoreDocument(
        score: MultiPartScore([score]),
        staves: const [ScoreStaff(index: 0, partName: 'Test')],
        format: ScoreSourceFormat.musicXml,
        musicXmlPerformance: MusicXmlPerformanceMetadata(
          graceNotes: [
            MusicXmlGraceMetadata(
              origin: MusicXmlPerformanceOrigin(
                partIndex: 0,
                measureIndex: 0,
                voice: '1',
                onset: const MusicXmlPosition(numerator: '1', denominator: '1'),
              ),
              stealTimePrevious: 50,
            ),
          ],
        ),
      );
      final plan = ScorePerformancePlan.fromDocument(document);
      final midi = sk.MidiReader.fromBytes(
        buildScoreMidi(document, performancePlan: plan),
      );
      final map = ScorePlaybackMap.fromPlan(plan);

      expect(_eventsForPitches(midi, {60, 67, 62}), [
        (60, 0, false),
        (60, 240, true),
        (67, 240, false),
        (67, 480, true),
        (62, 480, false),
        (62, 960, true),
      ]);
      expect(plan.totalWholeNotes, Fraction(1, 1));
      expect(
        map.startOfElement('grace-main'),
        const Duration(milliseconds: 250),
      );
      expect(
        map.soundingAt(const Duration(milliseconds: 300)),
        contains('grace-main'),
      );
      expect(
        map.soundingAt(const Duration(milliseconds: 300)),
        isNot(contains('previous')),
      );
      expect(map.duration, const Duration(seconds: 2));
    },
  );
}

ScoreDocument _document(
  NoteElement first, {
  NoteElement? second,
  KeySignature keySignature = const KeySignature(0),
}) {
  final elements = <MusicElement>[
    first.copyWith(id: first.id ?? 'first'),
    if (second != null) second.copyWith(id: second.id ?? 'second'),
    for (var i = 0; i < (second == null ? 3 : 2); i++)
      RestElement(NoteDuration.quarter),
  ];
  final score = Score(
    clef: Clef.treble,
    keySignature: keySignature,
    timeSignature: const TimeSignature(4, 4),
    measures: [Measure(elements)],
  );
  return ScoreDocument(
    score: MultiPartScore([score]),
    staves: const [ScoreStaff(index: 0, partName: 'Test')],
    format: ScoreSourceFormat.musicXml,
  );
}

ScoreDocument _documentForScore(Score score) => ScoreDocument(
  score: MultiPartScore([score]),
  staves: const [ScoreStaff(index: 0, partName: 'Test')],
  format: ScoreSourceFormat.musicXml,
);

ScoreDocument _musicXmlDocument({
  required String graceAttributes,
  bool includeSecondStaff = false,
  bool includeGrace = true,
  String gracePitch = 'G',
  String graceAlter = '',
  int? keyFifths,
  String ornamentMark = '',
}) {
  final secondPart = includeSecondStaff
      ? '''
  <score-part id="P2"><part-name>Second staff</part-name></score-part>'''
      : '';
  final secondMeasure = includeSecondStaff
      ? '''
  <part id="P2"><measure number="1">
    <attributes><divisions>4</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
    <note><pitch><step>A</step><octave>3</octave></pitch><duration>16</duration><voice>1</voice><type>whole</type></note>
  </measure></part>'''
      : '';
  final xml =
      '''
<score-partwise version="4.0">
  <part-list>
    <score-part id="P1"><part-name>Grace part</part-name></score-part>
    $secondPart
  </part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>4</divisions>${keyFifths == null ? '' : '<key><fifths>$keyFifths</fifths></key>'}<time><beats>4</beats><beat-type>4</beat-type></time></attributes>
    ${includeGrace ? '<note><grace $graceAttributes/><pitch><step>$gracePitch</step>$graceAlter<octave>4</octave></pitch><voice>1</voice><type>16th</type></note>' : ''}
    <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type>${ornamentMark.isEmpty ? '' : '<notations><ornaments>$ornamentMark</ornaments></notations>'}</note>
    <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
    <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
    <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type></note>
  </measure></part>
  $secondMeasure
</score-partwise>''';
  return parseScoreDocument(Uint8List.fromList(utf8.encode(xml)));
}

List<(int, int, bool)> _eventsForPitches(
  sk.MidiFile midi,
  Set<int> pitches, {
  int trackIndex = 0,
}) => [
  for (final event in midi.tracks[trackIndex].events)
    if (event is sk.NoteOnEvent && pitches.contains(event.note))
      (event.note, event.absoluteTick, event.isNoteOff)
    else if (event is sk.NoteOffEvent && pitches.contains(event.note))
      (event.note, event.absoluteTick, true),
];
