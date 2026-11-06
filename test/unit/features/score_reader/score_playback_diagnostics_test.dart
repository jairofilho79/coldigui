import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coldigui/features/score_reader/domain/entities/musescore_performance_metadata.dart';
import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/entities/score_playback_diagnostic.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_performance_plan.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnoses unsupported playback marks at their source location', () {
    final document = _document(
      Score(
        clef: Clef.treble,
        timeSignature: const TimeSignature(4, 4),
        measures: [
          Measure([
            NoteElement.note(
              const Pitch(Step.c, octave: 4),
              NoteDuration.quarter,
              articulations: {Articulation.breath},
              tremolo: 6,
              id: 'unsupported-marks',
            ),
          ]),
        ],
        hairpins: [
          const Hairpin(
            'unsupported-marks',
            'missing-endpoint',
            HairpinType.crescendo,
          ),
        ],
      ),
      musicXmlPerformance: const MusicXmlPerformanceMetadata(
        directions: [
          MusicXmlDirectionMetadata(
            origin: MusicXmlPerformanceOrigin(
              partIndex: 0,
              measureIndex: 0,
              staffIndex: 0,
            ),
            dynamicMarks: ['other-dynamics'],
          ),
        ],
      ),
    );

    final plan = ScorePerformancePlan.fromDocument(document);

    expect(
      plan.diagnostics,
      containsAll([
        isA<ScorePlaybackDiagnostic>()
            .having(
              (diagnostic) => diagnostic.code,
              'code',
              ScorePlaybackDiagnosticCode.unsupportedArticulation,
            )
            .having((diagnostic) => diagnostic.staffIndex, 'staffIndex', 0)
            .having((diagnostic) => diagnostic.measureIndex, 'measureIndex', 0),
        isA<ScorePlaybackDiagnostic>()
            .having(
              (diagnostic) => diagnostic.code,
              'code',
              ScorePlaybackDiagnosticCode.unsupportedTremoloStrokes,
            )
            .having((diagnostic) => diagnostic.staffIndex, 'staffIndex', 0)
            .having((diagnostic) => diagnostic.measureIndex, 'measureIndex', 0),
        isA<ScorePlaybackDiagnostic>()
            .having(
              (diagnostic) => diagnostic.code,
              'code',
              ScorePlaybackDiagnosticCode.unrecognizedDynamic,
            )
            .having((diagnostic) => diagnostic.staffIndex, 'staffIndex', 0)
            .having((diagnostic) => diagnostic.measureIndex, 'measureIndex', 0),
        isA<ScorePlaybackDiagnostic>()
            .having(
              (diagnostic) => diagnostic.code,
              'code',
              ScorePlaybackDiagnosticCode.incompleteHairpin,
            )
            .having((diagnostic) => diagnostic.staffIndex, 'staffIndex', 0)
            .having((diagnostic) => diagnostic.measureIndex, 'measureIndex', 0),
      ]),
    );

    final event = plan.events.single;
    expect(
      event.pitchDurations.where((duration) => duration.attack),
      hasLength(1),
      reason: 'unsupported tremolo counts must not silently use the default',
    );
  });

  test('retains and diagnoses unsupported MusicXML ornament variants', () {
    final source = File(
      'test/fixtures/scores/musicxml_tremolo_default.musicxml',
    ).readAsStringSync();
    final xml = source.replaceFirst(
      '<tremolo type="single"/>',
      '<tremolo type="start">6</tremolo><schleifer/>',
    );
    final document = parseScoreDocument(Uint8List.fromList(utf8.encode(xml)));
    final metadata = document.musicXmlPerformance!;
    final plan = ScorePerformancePlan.fromDocument(document);

    expect(metadata.tremolos.single.rawType, 'start');
    expect(metadata.ornaments.single.ornamentNames, contains('schleifer'));
    expect(
      plan.diagnostics,
      containsAll([
        isA<ScorePlaybackDiagnostic>()
            .having(
              (diagnostic) => diagnostic.code,
              'code',
              ScorePlaybackDiagnosticCode.unsupportedTremoloType,
            )
            .having((diagnostic) => diagnostic.staffIndex, 'staffIndex', 0)
            .having((diagnostic) => diagnostic.measureIndex, 'measureIndex', 0),
        isA<ScorePlaybackDiagnostic>()
            .having(
              (diagnostic) => diagnostic.code,
              'code',
              ScorePlaybackDiagnosticCode.unsupportedOrnament,
            )
            .having((diagnostic) => diagnostic.signal, 'signal', 'schleifer')
            .having((diagnostic) => diagnostic.measureIndex, 'measureIndex', 0),
      ]),
    );
    expect(plan.events.first.tremoloStrokes, isNull);
  });

  test('diagnoses unrecognized dynamics and invalid MusicXML tempo', () {
    final metadataOrigin = const MusicXmlPerformanceOrigin(
      partIndex: 0,
      measureIndex: 0,
      staffIndex: 0,
    );
    final document = _document(
      Score(
        clef: Clef.treble,
        timeSignature: const TimeSignature(4, 4),
        measures: [
          Measure([
            NoteElement.note(
              const Pitch(Step.c, octave: 4),
              NoteDuration.quarter,
              id: 'tempo-and-dynamics',
            ),
          ]),
        ],
      ),
      musicXmlPerformance: MusicXmlPerformanceMetadata(
        directions: [
          MusicXmlDirectionMetadata(
            origin: metadataOrigin,
            dynamicMarks: const ['other-dynamics'],
          ),
        ],
        sounds: [
          MusicXmlSoundMetadata(origin: metadataOrigin, rawTempo: 'fast'),
        ],
      ),
    );

    final plan = ScorePerformancePlan.fromDocument(document);

    expect(
      plan.diagnostics,
      containsAll([
        isA<ScorePlaybackDiagnostic>()
            .having(
              (diagnostic) => diagnostic.code,
              'code',
              ScorePlaybackDiagnosticCode.unrecognizedDynamic,
            )
            .having(
              (diagnostic) => diagnostic.signal,
              'signal',
              'other-dynamics',
            )
            .having((diagnostic) => diagnostic.staffIndex, 'staffIndex', 0)
            .having((diagnostic) => diagnostic.measureIndex, 'measureIndex', 0),
        isA<ScorePlaybackDiagnostic>()
            .having(
              (diagnostic) => diagnostic.code,
              'code',
              ScorePlaybackDiagnosticCode.invalidTempo,
            )
            .having((diagnostic) => diagnostic.signal, 'signal', 'fast')
            .having((diagnostic) => diagnostic.staffIndex, 'staffIndex', 0)
            .having((diagnostic) => diagnostic.measureIndex, 'measureIndex', 0),
      ]),
    );
  });

  test('diagnoses a valid MusicXML sound tempo not applied to playback', () {
    final document = parseScoreDocument(
      File('test/fixtures/scores/musicxml_performance.musicxml')
          .readAsBytesSync(),
    );
    final sound = document.musicXmlPerformance!.sounds.singleWhere(
      (item) => item.tempo != null,
    );

    final plan = ScorePerformancePlan.fromDocument(document);

    expect(
      plan.diagnostics,
      contains(
        isA<ScorePlaybackDiagnostic>()
            .having(
              (diagnostic) => diagnostic.code,
              'code',
              ScorePlaybackDiagnosticCode.unsupportedTempo,
            )
            .having((diagnostic) => diagnostic.signal, 'signal', sound.rawTempo)
            .having(
              (diagnostic) => diagnostic.measureIndex,
              'measureIndex',
              sound.origin.measureIndex,
            ),
      ),
    );
  });
}

ScoreDocument _document(
  Score score, {
  MusicXmlPerformanceMetadata? musicXmlPerformance,
}) => ScoreDocument(
  score: MultiPartScore([score]),
  staves: const [ScoreStaff(index: 0, partName: 'Violin')],
  format: ScoreSourceFormat.musicXml,
  musicXmlPerformance: musicXmlPerformance,
);
