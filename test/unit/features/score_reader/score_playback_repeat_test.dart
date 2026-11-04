import 'dart:convert';
import 'dart:typed_data';

import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_playback_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('measure loop bounds use the same first repeat occurrence', () {
    final document = parseScoreDocument(
      Uint8List.fromList(utf8.encode(_repeatedScore)),
    );
    final map = ScorePlaybackMap.of(document.score);

    expect(map.duration, const Duration(seconds: 8));
    expect(map.startOfMeasure(0), Duration.zero);
    expect(map.endOfMeasure(0), const Duration(seconds: 2));
    expect(map.startOfMeasure(1), const Duration(seconds: 2));
    expect(map.endOfMeasure(1), const Duration(seconds: 4));
    expect(map.measureAt(const Duration(seconds: 5)), 0);
    expect(map.measureAt(const Duration(seconds: 7)), 1);
    expect(
      map.soundingAt(const Duration(seconds: 5)),
      map.soundingAt(const Duration(seconds: 1)),
    );
  });

  test('a single repeated measure also has first-occurrence bounds', () {
    final document = parseScoreDocument(
      Uint8List.fromList(utf8.encode(_singleRepeatedScore)),
    );
    final map = ScorePlaybackMap.of(document.score);
    expect(map.duration, const Duration(seconds: 4));
    expect(map.startOfMeasure(0), Duration.zero);
    expect(map.endOfMeasure(0), const Duration(seconds: 2));
  });
}

const _singleRepeatedScore = '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Demo</part-name></score-part></part-list>
  <part id="P1"><measure number="1">
    <attributes><divisions>1</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
    <barline location="left"><repeat direction="forward"/></barline>
    <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note>
    <barline location="right"><repeat direction="backward"/></barline>
  </measure></part>
</score-partwise>
''';

const _repeatedScore = '''
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Demo</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>1</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <barline location="left"><repeat direction="forward"/></barline>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note>
    </measure>
    <measure number="2">
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note>
      <barline location="right"><repeat direction="backward"/></barline>
    </measure>
  </part>
</score-partwise>
''';
