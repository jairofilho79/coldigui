import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/score_reader/domain/entities/musescore_performance_metadata.dart';
import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_performance_plan.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_playback_map.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports dynamics and hairpins through repeats at exact MIDI ticks', () {
    final document = _musicXmlDynamicsDocument();
    expect(
      document.score.parts.single.dynamics.map((mark) => mark.level),
      contains(DynamicLevel.p),
    );
    expect(document.score.parts.single.hairpins, hasLength(1));
    expect(document.score.parts.single.measures[1].tempoChange?.quarterBpm, 60);
    expect(document.musicXmlPerformance!.sounds.single.dynamics, 73.5);
    final plan = ScorePerformancePlan.fromDocument(document);
    final notes = _trackMessages(
      buildScoreMidi(document, performancePlan: plan),
    ).where((message) => message.status & 0xf0 == 0x90);

    expect(
      notes.map((message) => (message.data1, message.tick, message.data2)),
      [
        (60, 480, 49),
        (62, 960, 49),
        (64, 1440, 49),
        (60, 2400, 49),
        (62, 2880, 49),
        (64, 3360, 49),
        (67, 3840, 71),
        (69, 5760, 80),
        (71, 6240, 96),
        (72, 6720, 118),
        (74, 7200, 96),
      ],
    );
    expect(
      ScorePlaybackMap.fromPlan(plan).duration,
      const Duration(seconds: 12),
    );

    final expression = _trackMessages(
      buildScoreMidi(document, performancePlan: plan),
    ).where((message) => message.status & 0xf0 == 0xb0 && message.data1 == 11);
    final firstCurve = [
      for (var index = 0; index <= 8; index++)
        (480 + 120 * index, [49, 51, 53, 55, 57, 58, 60, 62, 64][index]),
    ];
    expect(
      expression.map((message) => (message.tick, message.data2)).toList(),
      [
        ...firstCurve,
        ...firstCurve.map((event) => (event.$1 + 1920, event.$2)),
      ],
    );
  });

  test('an explicit note velocity overrides score and imported dynamics', () {
    final document = _musicXmlDynamicsDocument();
    final source = document.score.parts.single;
    final measures = source.measures.toList();
    final lastMeasure = measures[2];
    measures[2] = lastMeasure.copyWith(
      elements: [
        for (final element in lastMeasure.elements)
          if (element is NoteElement && element.pitches.single.midiNumber == 71)
            element.copyWith(velocity: 37)
          else
            element,
      ],
    );
    final explicitDocument = ScoreDocument(
      score: MultiPartScore([source.copyWith(measures: measures)]),
      staves: document.staves,
      format: document.format,
      musicXmlPerformance: document.musicXmlPerformance,
    );

    final note =
        _trackMessages(
          buildScoreMidi(
            explicitDocument,
            performancePlan: ScorePerformancePlan.fromDocument(
              explicitDocument,
            ),
          ),
        ).singleWhere(
          (message) => message.status & 0xf0 == 0x90 && message.data1 == 71,
        );
    expect(note.data2, 37);
  });

  test('hairpin start ignores momentary accent and articulation velocity', () {
    final source = _musicXmlDynamicsDocument();
    final part = source.score.parts.single;
    final firstNote = part.measures[0].elements.whereType<NoteElement>().first;
    final firstId = firstNote.id!;
    final measures = part.measures.toList()
      ..[0] = part.measures[0].copyWith(
        elements: [
          for (final element in part.measures[0].elements)
            if (element is NoteElement && element.id == firstId)
              element.copyWith(articulations: {Articulation.accent})
            else
              element,
        ],
      );
    final document = ScoreDocument(
      score: MultiPartScore([
        part.copyWith(
          measures: measures,
          dynamics: [
            ...part.dynamics,
            DynamicMarking(firstId, DynamicLevel.sfz),
          ],
        ),
      ]),
      staves: source.staves,
      format: source.format,
      musicXmlPerformance: source.musicXmlPerformance,
    );
    final messages = _trackMessages(
      buildScoreMidi(
        document,
        performancePlan: ScorePerformancePlan.fromDocument(document),
      ),
    );
    final firstAttack = messages.singleWhere(
      (message) =>
          message.status & 0xf0 == 0x90 &&
          message.data1 == firstNote.pitches.single.midiNumber &&
          message.tick == 480,
    );
    final expression = messages
        .where(
          (message) => message.status & 0xf0 == 0xb0 && message.data1 == 11,
        )
        .map((message) => (message.tick, message.data2))
        .toList();
    final firstCurve = [
      for (var index = 0; index <= 8; index++)
        (480 + 120 * index, [49, 51, 53, 55, 57, 58, 60, 62, 64][index]),
    ];

    expect(firstAttack.data2, 127);
    expect(expression, [
      ...firstCurve,
      ...firstCurve.map((event) => (event.$1 + 1920, event.$2)),
    ]);
  });

  test('MusicXML sound dynamics targets a hairpin endpoint', () {
    final source = _musicXmlDynamicsDocument();
    final metadata = source.musicXmlPerformance!;
    final document = ScoreDocument(
      score: source.score,
      staves: source.staves,
      format: source.format,
      musicXmlPerformance: MusicXmlPerformanceMetadata(
        directions: metadata.directions,
        sounds: [
          ...metadata.sounds,
          const MusicXmlSoundMetadata(
            origin: MusicXmlPerformanceOrigin(
              partIndex: 0,
              measureIndex: 0,
              onset: MusicXmlPosition(numerator: '3', denominator: '1'),
            ),
            rawDynamics: '73.5',
            dynamics: 73.5,
          ),
        ],
        repeats: metadata.repeats,
        graceNotes: metadata.graceNotes,
      ),
    );
    final messages = _trackMessages(
      buildScoreMidi(
        document,
        performancePlan: ScorePerformancePlan.fromDocument(document),
      ),
    );
    final expression = messages
        .where(
          (message) => message.status & 0xf0 == 0xb0 && message.data1 == 11,
        )
        .map((message) => (message.tick, message.data2))
        .toList();
    final firstCurve = [
      for (var index = 0; index <= 8; index++)
        (480 + 120 * index, [49, 52, 55, 57, 60, 63, 66, 68, 71][index]),
    ];

    expect(expression, [
      ...firstCurve,
      ...firstCurve.map((event) => (event.$1 + 1920, event.$2)),
    ]);
  });

  test('diminuendo emits an exact monotone CC11 curve', () {
    final source = _musicXmlDynamicsDocument();
    final part = source.score.parts.single;
    final firstId = part.measures[0].elements
        .whereType<NoteElement>()
        .first
        .id!;
    final lastId = part.measures[0].elements.whereType<NoteElement>().last.id!;
    final document = ScoreDocument(
      score: MultiPartScore([
        part.copyWith(
          hairpins: [Hairpin(firstId, lastId, HairpinType.diminuendo)],
        ),
      ]),
      staves: source.staves,
      format: source.format,
      musicXmlPerformance: source.musicXmlPerformance,
    );
    final messages = _trackMessages(
      buildScoreMidi(
        document,
        performancePlan: ScorePerformancePlan.fromDocument(document),
      ),
    );
    final expression = messages
        .where(
          (message) => message.status & 0xf0 == 0xb0 && message.data1 == 11,
        )
        .map((message) => (message.tick, message.data2))
        .toList();
    final firstCurve = [
      for (var index = 0; index <= 8; index++)
        (480 + 120 * index, [49, 47, 45, 43, 41, 39, 37, 35, 33][index]),
    ];

    expect(expression, [
      ...firstCurve,
      ...firstCurve.map((event) => (event.$1 + 1920, event.$2)),
    ]);
    final values = expression.map((event) => event.$2).toList();
    for (var start = 0; start < values.length; start += firstCurve.length) {
      final segment = values.skip(start).take(firstCurve.length).toList();
      expect(segment, orderedEquals([...segment]..sort((a, b) => b - a)));
    }
  });

  test('expression curves follow repeated measures and D.S. navigation', () {
    final source = parseScoreDocument(
      File('test/fixtures/scores/musicxml_navigation.musicxml')
          .readAsBytesSync(),
    );
    final part = source.score.parts.first;
    final startId = part.measures[3].elements.single.id!;
    final endId = part.measures[4].elements.single.id!;
    final measures = part.measures.toList()
      ..[4] = part.measures[4].copyWith(tempoChange: const Tempo(60));
    final routedPart = part.copyWith(
      measures: measures,
      dynamics: [
        DynamicMarking(startId, DynamicLevel.p),
        DynamicMarking(endId, DynamicLevel.f),
      ],
      hairpins: [Hairpin(startId, endId, HairpinType.crescendo)],
    );
    final document = ScoreDocument(
      score: MultiPartScore([routedPart, ...source.score.parts.skip(1)]),
      staves: source.staves,
      format: source.format,
      musicXmlPerformance: source.musicXmlPerformance,
    );
    final plan = ScorePerformancePlan.fromDocument(document);

    expect(plan.measureOccurrences.map((item) => item.measureIndex), [
      0,
      1,
      0,
      2,
      3,
      4,
      5,
      3,
      4,
      6,
    ]);
    expect(
      ScorePlaybackMap.fromPlan(plan).duration,
      const Duration(seconds: 30),
    );
    final messages = _trackMessages(
      buildScoreMidi(document, performancePlan: plan),
    );
    final notes = messages.where((message) => message.status & 0xf0 == 0x90);
    expect(
      notes
          .where((message) => message.data1 == 65 || message.data1 == 67)
          .map((message) => (message.data1, message.tick, message.data2)),
      [(65, 7680, 49), (67, 9600, 96), (65, 13440, 49), (67, 15360, 96)],
    );
    final expression = messages.where(
      (message) => message.status & 0xf0 == 0xb0 && message.data1 == 11,
    );
    final curve = [
      for (var index = 0; index <= 16; index++)
        (
          7680 + 120 * index,
          [
            49,
            52,
            55,
            58,
            61,
            64,
            67,
            70,
            73,
            75,
            78,
            81,
            84,
            87,
            90,
            93,
            96,
          ][index],
        ),
    ];
    expect(
      expression.map((message) => (message.tick, message.data2)).toList(),
      [...curve, ...curve.map((event) => (event.$1 + 5760, event.$2))],
    );
  });

  test('scores without dynamics keep the default velocity and no CC11', () {
    final document = ScoreDocument(
      score: MultiPartScore([
        Score(
          clef: Clef.treble,
          timeSignature: const TimeSignature(4, 4),
          measures: [
            Measure([
              NoteElement.note(
                const Pitch(Step.c, octave: 4),
                NoteDuration.quarter,
                id: 'plain-note',
              ),
            ]),
          ],
        ),
      ]),
      staves: const [ScoreStaff(index: 0, partName: 'Plain')],
      format: ScoreSourceFormat.musicXml,
    );
    final messages = _trackMessages(buildScoreMidi(document));

    expect(
      messages
          .where((message) => message.status & 0xf0 == 0x90)
          .map((message) => message.data2),
      [80],
    );
    expect(
      messages.where(
        (message) => message.status & 0xf0 == 0xb0 && message.data1 == 11,
      ),
      isEmpty,
    );
  });
}

ScoreDocument _musicXmlDynamicsDocument() => parseScoreDocument(
  File('test/fixtures/scores/musicxml_dynamics.musicxml').readAsBytesSync(),
);

List<({int tick, int status, int data1, int data2})> _trackMessages(
  Uint8List midi,
) {
  var offset = 14;
  final trackLength =
      (midi[offset + 4] << 24) |
      (midi[offset + 5] << 16) |
      (midi[offset + 6] << 8) |
      midi[offset + 7];
  offset += 8;
  final end = offset + trackLength;
  var tick = 0;
  final messages = <({int tick, int status, int data1, int data2})>[];
  while (offset < end) {
    final (delta, next) = _readVarLen(midi, offset);
    tick += delta;
    offset = next;
    final status = midi[offset++];
    if (status == 0xff) {
      offset++;
      final (length, afterLength) = _readVarLen(midi, offset);
      offset = afterLength + length;
      continue;
    }
    final kind = status & 0xf0;
    final data1 = midi[offset++];
    final data2 = kind == 0xc0 || kind == 0xd0 ? 0 : midi[offset++];
    messages.add((tick: tick, status: status, data1: data1, data2: data2));
  }
  return messages;
}

(int, int) _readVarLen(Uint8List bytes, int offset) {
  var value = 0;
  var index = offset;
  while (true) {
    final byte = bytes[index++];
    value = (value << 7) | (byte & 0x7f);
    if (byte & 0x80 == 0) return (value, index);
  }
}
