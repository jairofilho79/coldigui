import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:flutter_test/flutter_test.dart';

List<Uint8List> _tracks(Uint8List midi) {
  final bytes = ByteData.sublistView(midi);
  final tracks = <Uint8List>[];
  var offset = 14;
  while (offset < midi.length) {
    final length = bytes.getUint32(offset + 4);
    tracks.add(Uint8List.sublistView(midi, offset + 8, offset + 8 + length));
    offset += 8 + length;
  }
  return tracks;
}

void main() {
  late ScoreDocument document;
  setUpAll(() {
    document = parseScoreDocument(
      File('test/fixtures/scores/499.mscz').readAsBytesSync(),
    );
    expect(document.staves.length, greaterThanOrEqualTo(2));
  });

  test('program overrides preserve every other track and musical event', () {
    final original = buildScoreMidi(document);
    final before = _tracks(original);
    final after = _tracks(buildScoreMidi(document, programOverrides: {1: 127}));
    expect(after.length, before.length);
    expect(after[0], before[0]);
    expect(after[1].take(3), [0, 0xC0 | midiChannelForStaff(1), 127]);
    expect(after[1].skip(3), before[1].skip(3));
    expect(buildScoreMidi(document), original, reason: 'document is immutable');
  });

  test('zero and 127 are valid GM overrides', () {
    final tracks = _tracks(
      buildScoreMidi(document, programOverrides: {0: 0, 1: 127}),
    );
    expect(tracks[0].take(3), [0, 0xC0, 0]);
    expect(tracks[1].take(3), [0, 0xC1, 127]);
  });

  test(
    'invalid staff indices and programs are rejected, not silently clamped',
    () {
      for (final overrides in [
        {-1: 0},
        {document.staves.length: 0},
        {0: -1},
        {0: 128},
      ]) {
        expect(
          () => buildScoreMidi(document, programOverrides: overrides),
          throwsRangeError,
        );
      }
    },
  );
}
