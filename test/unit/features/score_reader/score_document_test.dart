import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/parse_score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_playback_map.dart';
import 'package:coldigui/features/score_reader/domain/usecases/transpose_score.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart' hide Interval;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundfont_kit/soundfont_kit.dart' as sk;

Uint8List _fixture(String name) =>
    File('test/fixtures/scores/$name').readAsBytesSync();

void main() {
  group('parseScoreDocument', () {
    test('mscz MuseScore 4.6+ keeps chord symbols, lyrics and voices', () {
      final doc = parseScoreDocument(_fixture('vozes_masc.mscz'));

      expect(doc.format, ScoreSourceFormat.mscz);
      expect(doc.staves, isNotEmpty);
      expect(doc.chordSymbolCount, greaterThanOrEqualTo(61));
      expect(doc.lyricCount, greaterThanOrEqualTo(184));
      final verses = {
        for (final part in doc.score.parts)
          for (final lyric in part.lyrics) lyric.verse,
      };
      expect(verses, containsAll(<int>[1, 2, 3]));
      expect(doc.quarterBpm, closeTo(100, 0.01));
    });

    test('full score (Grade) reads every staff with part names', () {
      final doc = parseScoreDocument(_fixture('grade.mscz'));

      expect(doc.score.parts.length, doc.staves.length);
      expect(doc.staves.length, greaterThan(4));
      expect(
        doc.staves.where((s) => s.partName.startsWith('Pauta ')),
        isEmpty,
        reason: 'nomes vêm de <Part>',
      );
      expect(doc.chordSymbolCount, greaterThanOrEqualTo(183));
      expect(doc.lyricCount, greaterThanOrEqualTo(192));
    });

    test('mscz and mxl of the same score agree', () {
      final mscz = parseScoreDocument(_fixture('499.mscz'));
      final xml = _fixture('499.musicxml');
      const container =
          '<?xml version="1.0"?><container><rootfiles>'
          '<rootfile full-path="score/499.musicxml"/></rootfiles></container>';
      final zip = ZipEncoder().encodeBytes(
        Archive()
          ..add(
            ArchiveFile.bytes(
              'mimetype',
              'application/vnd.recordare.musicxml'.codeUnits,
            ),
          )
          ..add(
            ArchiveFile.bytes('META-INF/container.xml', container.codeUnits),
          )
          ..add(ArchiveFile.bytes('score/499.musicxml', xml)),
      );
      final mxl = parseScoreDocument(zip);

      expect(mxl.format, ScoreSourceFormat.mxl);
      expect(mxl.measureCount, mscz.measureCount);
      expect(mxl.lyricCount, mscz.lyricCount);
      expect(mxl.staves.length, mscz.staves.length);
    });

    test('real-world mxl from the catalog opens', () {
      final doc = parseScoreDocument(_fixture('499.mxl'));

      expect(doc.format, ScoreSourceFormat.mxl);
      expect(doc.measureCount, greaterThan(0));
      expect(doc.lyricCount, greaterThan(0));
    });

    test('uncompressed MusicXML is detected by content', () {
      final doc = parseScoreDocument(_fixture('vozes_masc.musicxml'));

      expect(doc.format, ScoreSourceFormat.musicXml);
      expect(doc.chordSymbolCount, greaterThan(0));
      expect(doc.lyricCount, greaterThan(0));
    });

    test('rejects unknown content', () {
      expect(
        () => parseScoreDocument(Uint8List.fromList('olá'.codeUnits)),
        throwsA(isA<ScoreDocumentParseException>()),
      );
      expect(
        () => parseScoreDocument(Uint8List(0)),
        throwsA(isA<ScoreDocumentParseException>()),
      );
    });

    test('unwraps MuseScore 4.6 harmonyInfo', () {
      const mscx =
          '<Harmony><harmonyInfo><root>14</root><name>m</name></harmonyInfo>'
          '</Harmony>';
      expect(
        unwrapMuseScoreHarmonyInfo(mscx),
        '<Harmony><root>14</root><name>m</name></Harmony>',
      );
      expect(
        unwrapMuseScoreHarmonyInfo(
          '<Harmony><harmonyInfo><root>17</root><bass>15</bass>'
          '</harmonyInfo></Harmony>',
        ),
        '<Harmony><root>17</root><base>15</base></Harmony>',
      );
    });
  });

  group('chord symbols', () {
    test('every MuseScore harmony survives, including over rests', () {
      // Contagem de <Harmony> no .mscx principal de cada fixture.
      expect(parseScoreDocument(_fixture('499.mscz')).chordSymbolCount, 72);
      expect(parseScoreDocument(_fixture('grade.mscz')).chordSymbolCount, 242);
      expect(
        parseScoreDocument(_fixture('vozes_masc.mscz')).chordSymbolCount,
        61,
      );
    });

    test('a chord over a rest is anchored on that rest', () {
      final doc = parseScoreDocument(_fixture('499.mscz'));
      final part = doc.score.parts.first;
      final rests = {
        for (final n in playbackTimeline(part, expandRepeats: false))
          if (n.isRest) n.elementId,
      };
      expect(
        part.chordSymbols.where((c) => rests.contains(c.elementId)),
        isNotEmpty,
      );
    });

    test('mscz and MusicXML of the same piece place the same chords', () {
      for (final name in ['499', 'vozes_masc']) {
        final mscz = _chordPlaces(parseScoreDocument(_fixture('$name.mscz')));
        final xml = _chordPlaces(
          parseScoreDocument(_fixture('$name.musicxml')),
        );
        expect(mscz, xml, reason: name);
      }
    });

    test('slash chords keep their bass', () {
      final doc = parseScoreDocument(_fixture('499.mscz'));
      final texts = doc.score.parts.first.chordSymbols.map((c) => c.text);
      expect(texts, contains('Am/G'));
    });
  });

  group('buildScoreMidi', () {
    test('one track per staff, each on its own channel', () async {
      final doc = parseScoreDocument(_fixture('vozes_masc.mscz'));
      final midi = sk.MidiReader.fromBytes(buildScoreMidi(doc));

      expect(midi.tracks.length, doc.staves.length);
      final map = ScorePlaybackMap.of(doc.score);
      final player = map.duration.inMilliseconds;
      expect(player, greaterThan(10000));
    });

    test('channel map skips percussion channel 9', () {
      final channels = [for (var i = 0; i < 16; i++) midiChannelForStaff(i)];
      expect(channels, isNot(contains(9)));
      expect(channels.take(15).toSet().length, 15);
    });
  });

  group('ScorePlaybackMap', () {
    test('maps positions to sounding notes and measures', () {
      final doc = parseScoreDocument(_fixture('vozes_masc.mscz'));
      final map = ScorePlaybackMap.of(doc.score);

      final firstNote = map.timelines.first.firstWhere((n) => !n.isRest);
      final at = map.startOfElement(firstNote.elementId)!;
      expect(map.soundingAt(at), contains(firstNote.elementId));
      expect(map.measureOfElement(firstNote.elementId), firstNote.measureIndex);
      expect(map.startOfMeasure(firstNote.measureIndex), lessThanOrEqualTo(at));
      expect(
        map.soundingAt(map.duration + const Duration(seconds: 1)),
        isEmpty,
      );
    });

    test('at 100 bpm a quarter note lasts 600 ms', () {
      final doc = parseScoreDocument(_fixture('vozes_masc.mscz'));
      final map = ScorePlaybackMap.of(doc.score);

      expect(map.durationAt(Fraction(1, 4)).inMilliseconds, 600);
    });
  });

  group('transposeScore', () {
    test('keeps ids, moves pitches and chord roots', () {
      final doc = parseScoreDocument(_fixture('vozes_masc.mscz'));
      final up = transposeScore(doc.score, 2);

      final before = doc.score.parts.first.chordSymbols.first;
      final after = up.parts.first.chordSymbols.first;
      expect(after.elementId, before.elementId);
      expect(after.root.midiNumber - before.root.midiNumber, anyOf(2, -10));
      expect(up.parts.first.lyrics.length, doc.score.parts.first.lyrics.length);
    });

    test('zero returns the same score', () {
      final doc = parseScoreDocument(_fixture('499.mscz'));
      expect(identical(transposeScore(doc.score, 0), doc.score), isTrue);
    });

    test('descending intervals for negative semitones', () {
      final doc = parseScoreDocument(_fixture('499.mscz'));
      final down = transposeScore(doc.score, -12);
      final note = doc.score.parts.first.chordSymbols.first;
      final moved = down.parts.first.chordSymbols.first;
      expect(moved.root.midiNumber, note.root.midiNumber - 12);
    });
  });
}

/// (pauta, compasso, tempo no compasso, texto) de cada cifra — independe dos
/// ids, que mudam entre leitores.
List<String> _chordPlaces(ScoreDocument doc) {
  final out = <String>[];
  for (final (staff, part) in doc.score.parts.indexed) {
    final first = <String, PlaybackNote>{};
    final measureStart = <int, Fraction>{};
    for (final n in playbackTimeline(part, expandRepeats: false)) {
      first.putIfAbsent(n.elementId, () => n);
      final s = measureStart[n.measureIndex];
      if (s == null || n.start < s) measureStart[n.measureIndex] = n.start;
    }
    for (final c in part.chordSymbols) {
      final n = first[c.elementId]!;
      final at = n.start - measureStart[n.measureIndex]! + c.offset;
      out.add('$staff m${n.measureIndex} $at ${c.text}');
    }
  }
  return out..sort();
}
