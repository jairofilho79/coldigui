import 'dart:io';

import 'package:coldigui/features/score_reader/domain/entities/musescore_performance_metadata.dart';
import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_performance_plan.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_playback_map.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundfont_kit/soundfont_kit.dart' as sk;

void main() {
  test('projects the imported 499 D.S. al Coda path to every staff', () {
    final document = parseScoreDocument(
      File('test/fixtures/scores/499.mscz').readAsBytesSync(),
    );
    final plan = ScorePerformancePlan.fromDocument(document);
    final expected = [
      ...List.generate(73, (index) => index),
      ...List.generate(13, (index) => index + 29),
      ...List.generate(14, (index) => index + 73),
    ];

    expect(
      plan.measureOccurrences.map((occurrence) => occurrence.measureIndex),
      expected,
    );
    for (final (staffIndex, timeline) in plan.timelines.indexed) {
      for (final occurrence in plan.measureOccurrences) {
        expect(
          timeline.any(
            (note) =>
                note.measureIndex == occurrence.measureIndex &&
                note.start >= occurrence.start &&
                note.start < occurrence.end,
          ),
          isTrue,
          reason:
              'staff $staffIndex should play measure '
              '${occurrence.measureIndex} at ${occurrence.start}',
        );
      }
    }
  });

  test(
    'applies top-staff MusicXML repeat, volta and D.S. al Coda globally',
    () {
      final document = parseScoreDocument(
        File('test/fixtures/scores/musicxml_navigation.musicxml')
            .readAsBytesSync(),
      );
      final plan = ScorePerformancePlan.fromDocument(document);
      const expected = [0, 1, 0, 2, 3, 4, 5, 3, 4, 6];

      expect(
        plan.measureOccurrences.map((occurrence) => occurrence.measureIndex),
        expected,
      );
      final midi = sk.MidiReader.fromBytes(
        buildScoreMidi(document, performancePlan: plan),
      );
      for (final (staffIndex, timeline) in plan.timelines.indexed) {
        expect(timeline.map((note) => note.measureIndex), expected);
        final sounding = midi.tracks[staffIndex].events
            .whereType<sk.NoteOnEvent>()
            .where((event) => !event.isNoteOff)
            .map((event) => event.note)
            .toList();
        expect(
          sounding,
          staffIndex == 0
              ? [60, 62, 60, 64, 65, 67, 69, 65, 67, 71]
              : [48, 50, 48, 52, 53, 55, 57, 53, 55, 59],
        );
      }
      expect(
        ScorePlaybackMap.fromDocument(document).duration,
        const Duration(seconds: 20),
      );
    },
  );

  test('honors a declared MusicXML repeat pass count', () {
    final document = _musicXmlDocument(
      repeats: const [
        MusicXmlRepeatMetadata(
          origin: MusicXmlPerformanceOrigin(partIndex: 0, measureIndex: 1),
          direction: 'backward',
          rawTimes: '3',
          times: 3,
        ),
      ],
    );

    final plan = ScorePerformancePlan.fromDocument(document);

    expect(
      plan.measureOccurrences.map((occurrence) => occurrence.measureIndex),
      [0, 1, 0, 1, 0, 1],
    );
  });

  test('rejects repeat counts that exceed the measure occurrence limit', () {
    final document = _musicXmlDocument(
      repeats: const [
        MusicXmlRepeatMetadata(
          origin: MusicXmlPerformanceOrigin(partIndex: 0, measureIndex: 1),
          direction: 'backward',
          rawTimes: '5001',
          times: 5001,
        ),
      ],
    );

    expect(
      () => ScorePerformancePlan.fromDocument(document),
      throwsA(
        isA<ScorePerformanceNavigationException>().having(
          (exception) => exception.issues.single.code,
          'issue code',
          ScorePerformanceNavigationIssueCode.measureOccurrenceLimitExceeded,
        ),
      ),
    );
  });

  test('honors MusicXML repeat afterJump policy on a D.C. return', () {
    final document = ScoreDocument(
      score: MultiPartScore([
        _score([
          _noteMeasure(0),
          _noteMeasure(1, startRepeat: true),
          _noteMeasure(2, endRepeat: true),
          _noteMeasure(3),
        ]),
      ]),
      staves: const [ScoreStaff(index: 0, partName: 'Test')],
      format: ScoreSourceFormat.musicXml,
      musicXmlPerformance: MusicXmlPerformanceMetadata(
        repeats: const [
          MusicXmlRepeatMetadata(
            origin: MusicXmlPerformanceOrigin(partIndex: 0, measureIndex: 2),
            direction: 'backward',
            rawTimes: '2',
            times: 2,
            rawAfterJump: 'yes',
            afterJump: true,
          ),
        ],
        sounds: [MusicXmlSoundMetadata(origin: _origin(3), daCapo: true)],
      ),
    );

    expect(
      ScorePerformancePlan.fromDocument(document).measureOccurrences
          .map((occurrence) => occurrence.measureIndex),
      [0, 1, 2, 1, 2, 3, 0, 1, 2, 1, 2, 3],
    );
  });

  test('applies MuseScore passage passes and score-wide playRepeats', () {
    final passages = [
      for (final (index, pass) in [1, 2].indexed)
        MuseScorePassageMetadata(
          origin: MuseScorePerformanceOrigin(
            kind: MuseScorePerformanceOriginKind.passage,
            elementName: 'Volta',
            staffIndex: 0,
            measureIndex: index + 1,
          ),
          startMeasureIndex: index + 1,
          endMeasureIndexExclusive: index + 2,
          passNumbers: [pass],
          declaredMeasureCount: 1,
        ),
    ];
    final measures = [
      _noteMeasure(0, startRepeat: true),
      _noteMeasure(1, endRepeat: true),
      _noteMeasure(2),
    ];
    final repeated = _museScoreDocument(
      measures,
      passages: passages,
      playRepeats: true,
    );
    final unrepeated = _museScoreDocument(
      measures,
      passages: passages,
      playRepeats: false,
    );

    expect(
      ScorePerformancePlan.fromDocument(repeated).measureOccurrences
          .map((item) => item.measureIndex),
      [0, 1, 0, 2],
    );
    expect(
      ScorePerformancePlan.fromDocument(unrepeated).measureOccurrences
          .map((item) => item.measureIndex),
      [0, 1, 2],
    );
  });

  test('honors Jump playRepeats on the return traversal', () {
    final destination = MuseScorePerformanceDestination(
      reference: 'segno',
      measureIndex: 1,
      kind: MuseScoreDestinationKind.marker,
      origin: const MuseScorePerformanceOrigin(
        kind: MuseScorePerformanceOriginKind.marker,
        elementName: 'Marker',
        staffIndex: 0,
        measureIndex: 1,
      ),
    );
    final measures = [
      _noteMeasure(0),
      _noteMeasure(1, startRepeat: true),
      _noteMeasure(2, endRepeat: true),
      _noteMeasure(3),
    ];

    for (final (playRepeats, expected) in [
      (false, [0, 1, 2, 1, 2, 3, 1, 2, 3]),
      (true, [0, 1, 2, 1, 2, 3, 1, 2, 1, 2, 3]),
    ]) {
      final document = _museScoreDocument(
        measures,
        playRepeats: true,
        jumps: [
          MuseScoreJumpMetadata(
            origin: const MuseScorePerformanceOrigin(
              kind: MuseScorePerformanceOriginKind.jump,
              elementName: 'Jump',
              staffIndex: 0,
              measureIndex: 3,
            ),
            jumpTo: 'segno',
            playRepeats: playRepeats,
            jumpToDestination: destination,
          ),
        ],
      );
      expect(
        ScorePerformancePlan.fromDocument(document).measureOccurrences
            .map((item) => item.measureIndex),
        expected,
      );
    }
  });

  test('surfaces unresolved MusicXML destinations', () {
    final document = _musicXmlDocument(
      repeats: const [],
      sounds: [MusicXmlSoundMetadata(origin: _origin(0), dalSegno: 'Missing')],
    );

    expect(
      () => ScorePerformancePlan.fromDocument(document),
      throwsA(
        isA<ScorePerformanceNavigationException>().having(
          (error) => error.issues.map((issue) => issue.code),
          'issues',
          contains(ScorePerformanceNavigationIssueCode.unresolvedDestination),
        ),
      ),
    );
  });

  test('surfaces cyclic MusicXML navigation', () {
    final document = _musicXmlDocument(
      repeats: const [],
      sounds: [
        MusicXmlSoundMetadata(origin: _origin(0), segno: 'S'),
        MusicXmlSoundMetadata(origin: _origin(0), dalSegno: 'S'),
      ],
    );

    expect(
      () => ScorePerformancePlan.fromDocument(document),
      throwsA(
        isA<ScorePerformanceNavigationException>().having(
          (error) => error.issues.map((issue) => issue.code),
          'issues',
          contains(ScorePerformanceNavigationIssueCode.cyclicNavigation),
        ),
      ),
    );
  });

  test('surfaces conflicting MusicXML jump declarations', () {
    final document = _musicXmlDocument(
      repeats: const [],
      sounds: [
        MusicXmlSoundMetadata(origin: _origin(0), daCapo: true, dalSegno: 'S'),
        MusicXmlSoundMetadata(origin: _origin(0), segno: 'S'),
      ],
    );

    expect(
      () => ScorePerformancePlan.fromDocument(document),
      throwsA(
        isA<ScorePerformanceNavigationException>().having(
          (error) => error.issues.map((issue) => issue.code),
          'issues',
          contains(ScorePerformanceNavigationIssueCode.conflictingNavigation),
        ),
      ),
    );
  });
}

MusicXmlPerformanceOrigin _origin(int measureIndex) =>
    MusicXmlPerformanceOrigin(partIndex: 0, measureIndex: measureIndex);

ScoreDocument _museScoreDocument(
  List<Measure> measures, {
  List<MuseScoreJumpMetadata> jumps = const [],
  List<MuseScorePassageMetadata> passages = const [],
  required bool playRepeats,
}) => ScoreDocument(
  score: MultiPartScore([_score(measures)]),
  staves: const [ScoreStaff(index: 0, partName: 'Test')],
  format: ScoreSourceFormat.mscx,
  museScorePerformance: MuseScorePerformanceMetadata(
    jumps: jumps,
    passages: passages,
    playRepeatsDeclarations: [
      MuseScorePlayRepeatsMetadata(
        origin: const MuseScorePerformanceOrigin(
          kind: MuseScorePerformanceOriginKind.playRepeats,
          elementName: 'playRepeats',
        ),
        rawValue: playRepeats ? '1' : '0',
        value: playRepeats,
      ),
    ],
  ),
);

ScoreDocument _musicXmlDocument({
  required List<MusicXmlRepeatMetadata> repeats,
  List<MusicXmlSoundMetadata> sounds = const [],
}) => ScoreDocument(
  score: MultiPartScore([
    _score([
      _noteMeasure(0, startRepeat: true),
      _noteMeasure(1, endRepeat: true),
    ]),
  ]),
  staves: const [ScoreStaff(index: 0, partName: 'Test')],
  format: ScoreSourceFormat.musicXml,
  musicXmlPerformance: MusicXmlPerformanceMetadata(
    repeats: repeats,
    sounds: sounds,
  ),
);

Score _score(List<Measure> measures) => Score(
  clef: Clef.treble,
  timeSignature: const TimeSignature(4, 4),
  measures: measures,
);

Measure _noteMeasure(
  int index, {
  bool startRepeat = false,
  bool endRepeat = false,
}) => Measure(
  [
    NoteElement.note(
      Pitch(Step.values[index % Step.values.length], octave: 4),
      NoteDuration.whole,
      id: 'm$index',
    ),
  ],
  startRepeat: startRepeat,
  endRepeat: endRepeat,
);
