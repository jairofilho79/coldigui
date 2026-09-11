import 'package:coldigui/features/chords/presentation/utils/transpose_label_memo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransposeLabelMemo', () {
    test('mesma chave nao invoca a funcao injetada de novo', () {
      var calls = 0;
      final memo = TransposeLabelMemo(
        transpose: (chord, semitones, {required bool preferFlats}) {
          calls++;
          return '$chord+$semitones';
        },
      );

      final first = memo.label('C', 2, preferFlats: false);
      final second = memo.label('C', 2, preferFlats: false);

      expect(first, 'C+2');
      expect(second, 'C+2');
      expect(calls, 1);
    });

    test('chaves diferentes invocam a funcao de novo cada uma', () {
      var calls = 0;
      final memo = TransposeLabelMemo(
        transpose: (chord, semitones, {required bool preferFlats}) {
          calls++;
          return chord;
        },
      );

      memo.label('C', 1, preferFlats: false);
      memo.label('C', 2, preferFlats: false);
      memo.label('D', 1, preferFlats: false);
      memo.label('C', 1, preferFlats: true);

      expect(calls, 4);
    });

    test('limpa tudo ao estourar o teto de entradas', () {
      final memo = TransposeLabelMemo(
        maxEntries: 512,
        transpose: (chord, semitones, {required bool preferFlats}) => chord,
      );

      for (var i = 0; i < 513; i++) {
        memo.label('C$i', 0, preferFlats: false);
      }

      expect(memo.size, lessThanOrEqualTo(512));
    });

    test('usa transposeChordLabel por padrao', () {
      final memo = TransposeLabelMemo();

      expect(memo.label('C', 2, preferFlats: false), 'D');
    });
  });
}
