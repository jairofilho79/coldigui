import 'package:coldigui/features/chords/domain/entities/chordpro_song.dart';
import 'package:coldigui/features/chords/presentation/utils/split_lines_for_columns.dart';
import 'package:flutter_test/flutter_test.dart';

ChordProLyricLine _lyric(String text) =>
    ChordProLyricLine([ChordCell(text: text)]);

void main() {
  group('splitLinesForColumns', () {
    test('lista curta (abaixo do minimo) nao divide', () {
      final lines = List.generate(10, (i) => _lyric('linha $i'));

      final result = splitLinesForColumns(lines);

      expect(result.left, lines);
      expect(result.right, isEmpty);
    });

    test('corta no limite de secao mais proximo do meio', () {
      final lines = [
        for (var i = 0; i < 30; i++)
          if (i == 14) const ChordProStanzaBreak() else _lyric('linha $i'),
      ];

      final result = splitLinesForColumns(lines);

      expect(result.left.length, 14);
      expect(result.right.length, 16);
      expect(result.right.first, isA<ChordProStanzaBreak>());
      // Nenhuma linha se perde nem se repete no corte.
      expect(result.left.length + result.right.length, lines.length);
    });

    test('sem secao corta exatamente na metade', () {
      final lines = List.generate(30, (i) => _lyric('linha $i'));

      final result = splitLinesForColumns(lines);

      expect(result.left.length, 15);
      expect(result.right.length, 15);
    });

    test('respeita minLines customizado', () {
      final lines = List.generate(20, (i) => _lyric('linha $i'));

      expect(splitLinesForColumns(lines).right, isEmpty);
      expect(splitLinesForColumns(lines, minLines: 16).right, isNotEmpty);
    });
  });
}
