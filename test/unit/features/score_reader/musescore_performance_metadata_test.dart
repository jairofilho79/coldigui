import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/score_reader/domain/entities/musescore_performance_metadata.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(String xml) => Uint8List.fromList(utf8.encode(xml));

String _measure(String contents) => '<Measure>$contents$_rest</Measure>';

const _rest =
    '<voice><TimeSig><sigN>4</sigN><sigD>4</sigD></TimeSig>'
    '<Rest><durationType>whole</durationType></Rest></voice>';

String _mscx({String scoreSettings = '', required List<String> measures}) =>
    '''
<museScore version="4.20">
  <Score>
    <Division>480</Division>
    $scoreSettings
    <Part id="1"><trackName>Test</trackName><Instrument><midiProgram>0</midiProgram></Instrument><Staff id="1"/></Part>
    <Staff id="1">${measures.join()}</Staff>
  </Score>
</museScore>
''';

void main() {
  test('imports real MSCZ labels and resolves its D.S. al Coda jump', () {
    final bytes = File('test/fixtures/scores/499.mscz').readAsBytesSync();
    final metadata = parseScoreDocument(bytes).museScorePerformance!;

    expect(
      metadata.markers.map((marker) => marker.label),
      containsAll(<String>['segno', 'coda', 'codab']),
    );
    final jump = metadata.jumps.single;
    expect(jump.jumpTo, 'segno');
    expect(jump.playUntil, 'coda');
    expect(jump.continueAt, 'codab');
    expect(jump.text, 'D.S. al Coda');
    expect(jump.style, 'repeat_right');
    expect(
      jump.jumpToDestination?.measureIndex,
      metadata.markers
          .singleWhere((marker) => marker.label == 'segno')
          .origin
          .measureIndex,
    );
    expect(jump.playUntilDestination?.measureIndex, isNotNull);
    expect(jump.continueAtDestination?.measureIndex, isNotNull);
    expect(jump.origin.elementId, isNotEmpty);
    expect(metadata.diagnostics, isEmpty);
  });

  test(
    'preserves authored jump parameters, origins, passages, and settings',
    () {
      final document = parseScoreDocument(
        _bytes(
          _mscx(
            scoreSettings: '<playRepeats>1</playRepeats>',
            measures: [
              _measure(
                '<Marker><eid>segno-id</eid><label>segno</label>'
                '<markerType>segno</markerType><text>Segno</text></Marker>'
                '<Spanner type="Volta"><Volta><endings>1, 3</endings>'
                '<text>1. / 3.</text><endHookType>1</endHookType></Volta>'
                '<next><location><measures>2</measures></location></next>'
                '</Spanner>',
              ),
              _measure(''),
              _measure(
                '<Marker><eid>coda-id</eid><label>coda</label>'
                '<markerType>coda</markerType><text>Coda</text></Marker>',
              ),
              _measure(
                '<Jump><eid>jump-id</eid><jumpTo>segno</jumpTo>'
                '<playUntil>coda</playUntil><continueAt>end</continueAt>'
                '<playRepeats>0</playRepeats></Jump>',
              ),
            ],
          ),
        ),
      );
      final metadata = document.museScorePerformance!;
      final jump = metadata.jumps.single;
      final passage = metadata.passages.single;
      final playRepeats = metadata.playRepeatsDeclarations.single;

      expect(metadata.playRepeats, isTrue);
      expect(playRepeats.origin.elementName, 'playRepeats');
      expect(jump.origin.measureIndex, 3);
      expect(jump.origin.elementId, 'jump-id');
      expect(jump.playRepeats, isFalse);
      expect(jump.playRepeatsDeclaration?.origin.elementName, 'playRepeats');
      expect(jump.jumpToDestination?.measureIndex, 0);
      expect(jump.playUntilDestination?.measureIndex, 2);
      expect(jump.continueAtDestination?.measureIndex, 3);
      expect(passage.startMeasureIndex, 0);
      expect(passage.endMeasureIndexExclusive, 2);
      expect(passage.passNumbers, [1, 3]);
      expect(passage.text, '1. / 3.');
      expect(document.museScorePerformance!.diagnostics, isEmpty);
    },
  );

  test('diagnoses duplicate labels, unresolved destinations, and setting conflicts', () {
    final metadata = parseScoreDocument(
      _bytes(
        _mscx(
          scoreSettings:
              '<playRepeats>1</playRepeats>'
              '<playRepeats>0</playRepeats>',
          measures: [
            _measure('<Marker><eid>first</eid><label>segno</label></Marker>'),
            _measure(
              '<Marker><eid>second</eid><label>segno</label></Marker>'
              '<Jump><eid>jump</eid><jumpTo>segno</jumpTo>'
              '<playUntil>missing</playUntil></Jump>',
            ),
          ],
        ),
      ),
    ).museScorePerformance!;
    final jump = metadata.jumps.single;

    expect(jump.jumpToDestination, isNull);
    expect(jump.playUntilDestination, isNull);
    expect(
      metadata.diagnostics.map((diagnostic) => diagnostic.code),
      containsAll([
        MuseScorePerformanceDiagnosticCode.duplicateMarkerLabel,
        MuseScorePerformanceDiagnosticCode.ambiguousDestination,
        MuseScorePerformanceDiagnosticCode.unresolvedDestination,
        MuseScorePerformanceDiagnosticCode.conflictingPlayRepeats,
      ]),
    );
    expect(metadata.playRepeats, isNull);
  });
}
