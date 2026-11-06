import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _fixture(String name) =>
    File('test/fixtures/scores/$name').readAsBytesSync();

void main() {
  test('imports sound, dynamics, offsets, repeats, and grace origins', () {
    final document = parseScoreDocument(
      _fixture('musicxml_performance.musicxml'),
    );
    final metadata = document.musicXmlPerformance!;
    final dalSegno = metadata.sounds.singleWhere(
      (sound) => sound.dalSegno != null,
    );
    final direction = metadata.directions.first;

    expect(dalSegno.dalSegno, 'Segno');
    expect(dalSegno.daCapo, isNull);
    expect(dalSegno.rawDynamics, '73.5');
    expect(dalSegno.dynamics, 73.5);
    expect(dalSegno.timeOnlyPasses, [1, 3]);
    expect(dalSegno.rawOffsetDivisions, '1');
    expect(dalSegno.offset?.quarterNotes, 0.125);
    expect(dalSegno.origin.onset?.quarterNotes, 0.125);
    expect(dalSegno.divisions, 8);
    expect(dalSegno.origin.partId, 'P1');
    expect(dalSegno.origin.partIndex, 0);
    expect(dalSegno.origin.measureIndex, 0);
    expect(dalSegno.origin.measureNumber, '1');
    expect(dalSegno.origin.staffNumber, 2);
    expect(dalSegno.origin.staffIndex, 1);
    expect(dalSegno.origin.voice, '2');

    expect(direction.displayText, 'Da Capo');
    expect(direction.dynamicMarks, ['pp']);
    expect(direction.rawOffsetSound, 'yes');
    expect(direction.offsetAffectsSound, isTrue);
    expect(direction.offset?.quarterNotes, 0.5);
    expect(direction.origin.onset?.quarterNotes, 0.5);
    expect(direction.origin.voice, '2');
    expect(direction.origin.staffNumber, 2);

    final toCoda = metadata.sounds.singleWhere((sound) => sound.toCoda != null);
    expect(toCoda.tempo, 72.5);
    expect(toCoda.toCoda, 'Coda');
    expect(toCoda.origin.onset?.quarterNotes, 3.5);

    final visualOnlyDirection = metadata.directions.singleWhere(
      (item) => item.rawOffsetSound == 'no',
    );
    final fine = metadata.sounds.singleWhere((sound) => sound.fine != null);
    expect(visualOnlyDirection.origin.onset?.quarterNotes, 4.25);
    expect(visualOnlyDirection.offsetAffectsSound, isFalse);
    expect(fine.fine, 'Fine');
    expect(fine.origin.onset?.quarterNotes, 4);

    final repeat = metadata.repeats.single;
    expect(repeat.direction, 'backward');
    expect(repeat.rawTimes, '3');
    expect(repeat.times, 3);
    expect(repeat.origin.onset?.quarterNotes, 4);

    final grace = metadata.graceNotes.single;
    expect(grace.slash, isTrue);
    expect(grace.rawMakeTime, '2');
    expect(grace.makeTime, 2);
    expect(grace.rawStealTimePrevious, '25');
    expect(grace.stealTimePrevious, 25);
    expect(grace.rawStealTimeFollowing, '10');
    expect(grace.stealTimeFollowing, 10);
    expect(grace.origin.partId, 'P1');
    expect(grace.origin.partIndex, 0);
    expect(grace.origin.measureNumber, '1');
    expect(grace.origin.staffNumber, 2);
    expect(grace.origin.voice, '2');
    expect(grace.origin.onset?.quarterNotes, 0);

    final forwardRepeat = metadata.sounds.singleWhere(
      (sound) => sound.forwardRepeat == true,
    );
    expect(forwardRepeat.origin.partId, 'P2');
    expect(forwardRepeat.origin.partIndex, 1);
    expect(forwardRepeat.origin.onset?.quarterNotes, 0.5);
    expect(forwardRepeat.origin.staffNumber, isNull);
    expect(forwardRepeat.origin.voice, isNull);
  });

  test('regresses 499 sound navigation and MXL sound metadata', () {
    final musicXml = parseScoreDocument(_fixture('499.musicxml'));
    final mxl = parseScoreDocument(_fixture('499.mxl'));
    final metadata = musicXml.musicXmlPerformance!;
    expect(
      metadata.sounds.map((sound) => sound.segno).whereType<String>(),
      contains('segno'),
    );
    expect(
      metadata.sounds.map((sound) => sound.toCoda).whereType<String>(),
      contains('codab'),
    );
    expect(
      metadata.sounds.map((sound) => sound.dalSegno).whereType<String>(),
      contains('segno'),
    );
    expect(
      metadata.sounds.map((sound) => sound.coda).whereType<String>(),
      contains('codab'),
    );
    expect(metadata.sounds.any((sound) => sound.tempo == 65), isTrue);
    final jump = metadata.sounds.singleWhere((sound) => sound.dalSegno != null);
    expect(jump.origin.partId, 'P1');
    expect(jump.origin.partIndex, 0);
    expect(jump.origin.measureNumber, '73');
    expect(jump.origin.onset, isNotNull);
    expect(
      mxl.musicXmlPerformance!.sounds.any((sound) => sound.tempo == 65),
      isTrue,
    );
    expect(mxl.musicXmlPerformance, isNotNull);

    expect(musicXml.chordSymbolCount, greaterThan(0));
    expect(musicXml.lyricCount, greaterThan(0));
    expect(mxl.chordSymbolCount, greaterThan(0));
    expect(mxl.lyricCount, greaterThan(0));
  });
}
