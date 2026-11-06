import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_performance_plan.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart' hide Interval;
import 'package:flutter_test/flutter_test.dart';

typedef _MidiNoteEvent = ({int tick, int channel, int pitch, bool noteOn});

typedef _ParsedTrack = ({List<_MidiNoteEvent> notes, int endTick});

List<Uint8List> _tracks(Uint8List midi) {
  final bytes = ByteData.sublistView(midi);
  final tracks = <Uint8List>[];
  var offset = 14;
  while (offset + 8 <= midi.length) {
    final length = bytes.getUint32(offset + 4);
    tracks.add(Uint8List.sublistView(midi, offset + 8, offset + 8 + length));
    offset += 8 + length;
  }
  return tracks;
}

_ParsedTrack _parseTrack(Uint8List track) {
  final notes = <_MidiNoteEvent>[];
  var offset = 0;
  var tick = 0;
  while (offset < track.length) {
    final (delta, afterDelta) = _readVariableLength(track, offset);
    offset = afterDelta;
    tick += delta;
    final status = track[offset];
    if (status == 0xFF) {
      final type = track[offset + 1];
      final (length, afterLength) = _readVariableLength(track, offset + 2);
      if (type == 0x2F) return (notes: notes, endTick: tick);
      offset = afterLength + length;
      continue;
    }

    final kind = status & 0xF0;
    final dataLength = kind == 0xC0 || kind == 0xD0 ? 1 : 2;
    final pitch = track[offset + 1];
    final velocity = dataLength == 2 ? track[offset + 2] : 0;
    if (kind == 0x80 || kind == 0x90) {
      notes.add((
        tick: tick,
        channel: status & 0x0F,
        pitch: pitch,
        noteOn: kind == 0x90 && velocity > 0,
      ));
    }
    offset += 1 + dataLength;
  }
  throw const FormatException('MIDI track is missing End of Track');
}

(int, int) _readVariableLength(Uint8List bytes, int offset) {
  var value = 0;
  while (true) {
    final byte = bytes[offset++];
    value = (value << 7) | (byte & 0x7F);
    if (byte & 0x80 == 0) return (value, offset);
  }
}

List<_MidiNoteEvent> _expectedChordMessages(
  Iterable<ScorePerformanceEvent> events, {
  required int channel,
}) => [
  for (final event in events)
    for (final pitch in event.chordPitches!)
      (
        tick: _fractionToTicks(event.start),
        channel: channel,
        pitch: pitch.midiNumber,
        noteOn: true,
      ),
  for (final event in events)
    for (final pitch in event.chordPitches!)
      (
        tick: _fractionToTicks(event.end),
        channel: channel,
        pitch: pitch.midiNumber,
        noteOn: false,
      ),
];

int _fractionToTicks(Fraction time) =>
    (time.numerator * 4 * kScoreMidiTicksPerQuarter / time.denominator).round();

void main() {
  for (final fixture in ['chord_playback.musicxml', 'chord_playback.mscx']) {
    test('$fixture adds an exact opt-in chord track', () {
      final document = parseScoreDocument(
        File('test/fixtures/scores/$fixture').readAsBytesSync(),
      );
      final plan = ScorePerformancePlan.fromDocument(
        document,
        includeChordSymbols: true,
      );
      final chordEvents = plan.events
          .where((event) => event.chordPitches != null)
          .toList();
      expect(chordEvents, hasLength(1));
      expect(chordEvents.single.start, Fraction.zero);
      expect(chordEvents.single.duration, Fraction(1, 1));
      expect(
        chordEvents.single.chordPitches!.map((pitch) => pitch.midiNumber),
        [60, 64, 67],
      );

      final unchanged = buildScoreMidi(document);
      final explicitOff = buildScoreMidi(
        document,
        includeChordAccompaniment: false,
      );
      expect(explicitOff, equals(unchanged));
      expect(_tracks(unchanged), hasLength(document.staves.length));
      expect(_parseTrack(_tracks(unchanged).single).notes, [
        (tick: 0, channel: 0, pitch: 69, noteOn: true),
        (tick: 1920, channel: 0, pitch: 69, noteOn: false),
      ]);

      final enabled = _tracks(
        buildScoreMidi(document, includeChordAccompaniment: true),
      );
      expect(enabled, hasLength(document.staves.length + 1));
      expect(enabled.first, orderedEquals(_tracks(unchanged).first));
      expect(
        _parseTrack(enabled.last).notes,
        unorderedEquals([
          (tick: 0, channel: 15, pitch: 60, noteOn: true),
          (tick: 0, channel: 15, pitch: 64, noteOn: true),
          (tick: 0, channel: 15, pitch: 67, noteOn: true),
          (tick: 1920, channel: 15, pitch: 60, noteOn: false),
          (tick: 1920, channel: 15, pitch: 64, noteOn: false),
          (tick: 1920, channel: 15, pitch: 67, noteOn: false),
        ]),
      );
      expect(_parseTrack(enabled.last).endTick, 1920);
    });
  }

  test(
    'slash bass, degrees, offsets, durations, N.C. and repeats use plan events',
    () {
      final base = parseScoreDocument(
        File('test/fixtures/scores/chord_playback.musicxml').readAsBytesSync(),
      );
      final sourcePart = base.score.parts.single;
      final anchorId = sourcePart.measures.single.elements.single.id!;
      final repeatedMeasure = sourcePart.measures.single.copyWith(
        startRepeat: true,
        endRepeat: true,
      );
      final chords = [
        ChordSymbol(
          anchorId,
          const Pitch(Step.a),
          ChordSymbolKind.minor,
          bass: const Pitch(Step.g),
        ),
        ChordSymbol(
          anchorId,
          const Pitch(Step.c),
          ChordSymbolKind.none,
          offset: Fraction(1, 4),
        ),
        ChordSymbol(
          anchorId,
          const Pitch(Step.c),
          ChordSymbolKind.dominantSeventh,
          offset: Fraction(1, 2),
          duration: Fraction(1, 8),
          degrees: const [ChordDegree.add(9, alter: -1)],
        ),
      ];
      final chordPart = sourcePart.copyWith(
        measures: [repeatedMeasure],
        chordSymbols: chords,
      );
      final noChordPart = sourcePart.copyWith(
        measures: [repeatedMeasure],
        chordSymbols: const [],
      );
      final document = ScoreDocument(
        score: MultiPartScore([noChordPart, chordPart, chordPart]),
        staves: [
          for (var index = 0; index < 3; index++)
            ScoreStaff(index: index, partName: 'Fixture'),
        ],
        format: base.format,
      );
      final plan = ScorePerformancePlan.fromDocument(
        document,
        includeChordSymbols: true,
      );
      final sourceEvents = plan.events
          .where(
            (event) =>
                event.origin.staffIndex == 1 && event.chordPitches != null,
          )
          .toList();
      final allChordEvents = plan.events
          .where((event) => event.chordPitches != null)
          .toList();

      expect(plan.measureOccurrences.map((item) => item.measureIndex), [0, 0]);
      expect(sourceEvents.map((event) => event.start), [
        Fraction.zero,
        Fraction(1, 2),
        Fraction(1, 1),
        Fraction(3, 2),
      ]);
      expect(sourceEvents.map((event) => event.duration), [
        Fraction(1, 4),
        Fraction(1, 8),
        Fraction(1, 4),
        Fraction(1, 8),
      ]);
      expect(
        sourceEvents.map(
          (event) => event.chordPitches!.map((pitch) => pitch.midiNumber),
        ),
        [
          [67, 69, 72, 76],
          [60, 64, 67, 70, 73],
          [67, 69, 72, 76],
          [60, 64, 67, 70, 73],
        ],
      );
      expect(allChordEvents, hasLength(sourceEvents.length * 2));
      expect(
        () => buildScoreMidi(
          document,
          includeChordAccompaniment: true,
          performancePlan: ScorePerformancePlan.fromDocument(document),
        ),
        throwsArgumentError,
      );

      final disabled = _tracks(buildScoreMidi(document));
      final enabled = _tracks(
        buildScoreMidi(
          document,
          includeChordAccompaniment: true,
          performancePlan: plan,
        ),
      );
      expect(enabled, hasLength(disabled.length + 1));
      for (var index = 0; index < disabled.length; index++) {
        expect(enabled[index], orderedEquals(disabled[index]));
      }
      final accompaniment = _parseTrack(enabled.last);
      expect(
        accompaniment.notes,
        unorderedEquals(
          _expectedChordMessages(
            sourceEvents,
            channel: plan.chordRoute!.midiChannel,
          ),
        ),
      );
      expect(accompaniment.endTick, 3840);
      expect(
        accompaniment.notes.where((event) => event.tick == 480 && event.noteOn),
        isEmpty,
        reason: 'N.C. stops the preceding chord without another attack',
      );
    },
  );

  test('499 emits plan chords over rests once and preserves planned EOT', () {
    final document = parseScoreDocument(
      File('test/fixtures/scores/499.mscz').readAsBytesSync(),
    );
    final sourceStaffIndex = document.score.parts.indexed
        .firstWhere((entry) => entry.$2.chordSymbols.isNotEmpty)
        .$1;
    final plan = ScorePerformancePlan.fromDocument(
      document,
      includeChordSymbols: true,
    );
    final sourceEvents = plan.events
        .where(
          (event) =>
              event.origin.staffIndex == sourceStaffIndex &&
              event.chordPitches != null,
        )
        .toList();
    final sourceRestIds = plan.events
        .where(
          (event) =>
              event.origin.staffIndex == sourceStaffIndex && event.isRest,
        )
        .map((event) => event.origin.elementId)
        .toSet();
    expect(sourceEvents, isNotEmpty);
    expect(
      sourceEvents.any(
        (event) => sourceRestIds.contains(event.origin.elementId),
      ),
      isTrue,
      reason: 'at least one authored harmony is attached to a rest',
    );

    final disabled = _tracks(buildScoreMidi(document));
    final enabled = _tracks(
      buildScoreMidi(
        document,
        includeChordAccompaniment: true,
        performancePlan: plan,
      ),
    );
    expect(enabled, hasLength(disabled.length + 1));
    for (var index = 0; index < disabled.length; index++) {
      expect(enabled[index], orderedEquals(disabled[index]));
    }
    final accompaniment = _parseTrack(enabled.last);
    expect(
      accompaniment.notes,
      unorderedEquals(
        _expectedChordMessages(
          sourceEvents,
          channel: plan.chordRoute!.midiChannel,
        ),
      ),
    );
    expect(accompaniment.endTick, _fractionToTicks(plan.totalWholeNotes));
  });
}
