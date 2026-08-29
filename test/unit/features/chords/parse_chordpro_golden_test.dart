import 'dart:io';

import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture(String name) =>
    File('test/fixtures/chordpro/$name').readAsStringSync();

void main() {
  test('comigo habita: cabecalho e primeira linha de letra', () {
    final song = parseChordPro(_fixture('comigo_habita.chord'));

    expect(song.title, 'Comigo Habita, Ó Deus');
    expect(song.key, 'Eb');
    expect(song.hasLyrics, isTrue);

    final first = song.lines.whereType<ChordProLyricLine>().first;
    expect(first.cells.map((c) => c.chord).toList(), [
      'Eb',
      'Bb',
      'Cm',
      'Gm',
      'Ab',
    ]);
    // "[Eb]Co - [Bb]migo ha[Cm]bi - [Gm]ta, ó [Ab]Deus!" — todos encostam.
    expect(first.cells.every((c) => c.attached), isTrue);
  });

  test('confio em deus: intro solta com espacamento preservado', () {
    final song = parseChordPro(_fixture('confio_em_deus.chord'));

    final intro = song.lines
        .whereType<ChordProLyricLine>()
        .firstWhere((l) => l.cells.first.text.startsWith('   '));

    expect(intro.cells.first.chord, 'E');
    expect(intro.cells.first.attached, isFalse);
    expect(intro.cells.first.text, startsWith('   A linda'));
  });

  test('tombstone: 200 mas sem letra nenhuma', () {
    final song = parseChordPro(_fixture('tombstone.chord'));

    expect(song.title, isNotEmpty);
    expect(song.hasLyrics, isFalse);
  });
}
