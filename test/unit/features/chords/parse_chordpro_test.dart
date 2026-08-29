import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:flutter_test/flutter_test.dart';

List<ChordCell> _cellsOf(String line) {
  final song = parseChordPro(line);
  return (song.lines.whereType<ChordProLyricLine>().first).cells;
}

void main() {
  group('cabecalho', () {
    test('le as cinco diretivas conhecidas', () {
      final song = parseChordPro(
        '{title: Comigo Habita}\n'
        '{subtitle: 692}\n'
        '{key: Eb}\n'
        '{rhythm: Cancao}\n'
        '{artist: J.G.R}\n'
        '\n'
        'A [Bb]noite [Eb]vem,\n',
      );
      expect(song.title, 'Comigo Habita');
      expect(song.subtitle, '692');
      expect(song.key, 'Eb');
      expect(song.rhythm, 'Cancao');
      expect(song.artist, 'J.G.R');
    });

    test('trata valor vazio e "?" como ausente', () {
      final song = parseChordPro('{key: }\n{subtitle: ?}\nletra\n');
      expect(song.key, '');
      expect(song.subtitle, '');
    });

    test('ignora diretiva desconhecida em silencio', () {
      final song = parseChordPro('{meta: column left}\nletra\n');
      expect(song.lines.whereType<ChordProLyricLine>(), hasLength(1));
    });

    test('diretiva comment vira linha de comentario', () {
      final song = parseChordPro('{comment: Instrumentos: C Am}\nletra\n');
      expect(
        song.lines.whereType<ChordProCommentLine>().single.text,
        'Instrumentos: C Am',
      );
    });
  });

  group('linhas nao-letra', () {
    test('linha iniciada por ; nao e renderizada', () {
      final song = parseChordPro('; recado de pipeline\nletra\n');
      expect(song.lines.whereType<ChordProCommentLine>(), isEmpty);
      expect(song.lines.whereType<ChordProLyricLine>(), hasLength(1));
    });

    test('brancos consecutivos colapsam em um separador', () {
      final song = parseChordPro('a\n\n\n\nb\n');
      expect(song.lines.whereType<ChordProStanzaBreak>(), hasLength(1));
    });

    test('hasLyrics e falso quando so ha diretivas e comentarios ;', () {
      final song = parseChordPro(
        '{title: Clama, o igreja}\n{key: }\n\n; a cifra errada foi removida.\n',
      );
      expect(song.hasLyrics, isFalse);
    });

    test('hasLyrics e verdadeiro com ao menos uma linha de letra', () {
      expect(parseChordPro('{title: X}\n\nletra\n').hasLyrics, isTrue);
    });
  });

  group('adjacencia — encostado', () {
    test('texto a esquerda e a direita', () {
      final cells = _cellsOf('ha[Cm]bi');
      expect(cells.map((c) => c.chord), [null, 'Cm']);
      expect(cells[1].attached, isTrue);
      expect(cells[1].text, 'bi');
    });

    test('espaco a esquerda, texto a direita', () {
      final cells = _cellsOf('o [Ab]Deus');
      expect(cells[0].text, 'o ');
      expect(cells[1].chord, 'Ab');
      expect(cells[1].attached, isTrue);
    });

    test('inicio de linha, texto a direita', () {
      final cells = _cellsOf('[Eb]Comigo');
      expect(cells, hasLength(1));
      expect(cells.single.chord, 'Eb');
      expect(cells.single.attached, isTrue);
      expect(cells.single.text, 'Comigo');
    });

    test('texto a esquerda, fim de linha a direita', () {
      final cells = _cellsOf('monte Sinai[C#m7]');
      expect(cells.last.chord, 'C#m7');
      expect(cells.last.attached, isTrue);
      expect(cells.last.text, isEmpty);
    });

    test('texto a esquerda, espaco a direita', () {
      final cells = _cellsOf('a[Am]bri -[D]   [G]go.');
      final d = cells.firstWhere((c) => c.chord == 'D');
      expect(d.attached, isTrue);
      expect(d.text, '   ');
    });
  });

  group('adjacencia — solto', () {
    test('espaco dos dois lados', () {
      final cells = _cellsOf('fim [C] outro');
      final c = cells.firstWhere((c) => c.chord == 'C');
      expect(c.attached, isFalse);
    });

    test('espaco a esquerda, fim de linha a direita', () {
      final cells = _cellsOf('Deus e Amor [C]');
      expect(cells.last.chord, 'C');
      expect(cells.last.attached, isFalse);
    });

    test('inicio de linha, espaco a direita', () {
      final cells = _cellsOf('[E]   A linda');
      expect(cells.single.chord, 'E');
      expect(cells.single.attached, isFalse);
    });
  });

  group('espacamento preservado', () {
    test('um espaco e tres espacos produzem textos diferentes', () {
      final um = _cellsOf('Deus e Amor [C]');
      final tres = _cellsOf('Deus e Amor   [C]');
      expect(um.first.text, 'Deus e Amor ');
      expect(tres.first.text, 'Deus e Amor   ');
    });

    test('nao faz trim da linha', () {
      final cells = _cellsOf('   recuado');
      expect(cells.single.text, '   recuado');
    });
  });

  group('defensivo', () {
    test('colchete escapado vira texto literal', () {
      final cells = _cellsOf(r'a\[b\]c');
      expect(cells.single.chord, isNull);
      expect(cells.single.text, 'a[b]c');
    });

    test('colchete vazio vira texto literal', () {
      final cells = _cellsOf('a[]b');
      expect(cells.single.chord, isNull);
      expect(cells.single.text, 'a[]b');
    });

    test('colchete sem fechamento vira texto literal', () {
      final cells = _cellsOf('a[Cm b');
      expect(cells.single.chord, isNull);
      expect(cells.single.text, 'a[Cm b');
    });
  });
}
