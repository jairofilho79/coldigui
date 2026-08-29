import 'package:coldigui/features/chords/domain/usecases/transpose_chord.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('transposeChordLabel', () {
    test('deslocamento zero devolve o rotulo intacto', () {
      expect(transposeChordLabel('Bb7', 0, preferFlats: true), 'Bb7');
      expect(transposeChordLabel('F#m', 0, preferFlats: false), 'F#m');
    });

    test('sobe meio tom preservando o sufixo', () {
      expect(transposeChordLabel('C', 1, preferFlats: true), 'Db');
      expect(transposeChordLabel('Am7', 1, preferFlats: true), 'Bbm7');
      expect(transposeChordLabel('G', 1, preferFlats: false), 'G#');
    });

    test('desce meio tom', () {
      expect(transposeChordLabel('C', -1, preferFlats: false), 'B');
      expect(transposeChordLabel('D', -1, preferFlats: false), 'C#');
      expect(transposeChordLabel('D', -1, preferFlats: true), 'Db');
    });

    test('da a volta no ciclo de 12', () {
      expect(transposeChordLabel('B', 1, preferFlats: false), 'C');
      expect(transposeChordLabel('C', -1, preferFlats: true), 'B');
      expect(transposeChordLabel('D', 12, preferFlats: false), 'D');
    });

    test('transpoe tambem o baixo invertido', () {
      expect(transposeChordLabel('G/B', 2, preferFlats: false), 'A/C#');
      expect(transposeChordLabel('D7/F#', 1, preferFlats: true), 'Eb7/G');
    });

    test('preserva sufixos incomuns do corpus', () {
      expect(transposeChordLabel('Gm7(add9)', 2, preferFlats: false), 'Am7(add9)');
      expect(transposeChordLabel('A(sus4)', 1, preferFlats: true), 'Bb(sus4)');
      expect(transposeChordLabel('Cø', 2, preferFlats: false), 'Dø');
      expect(transposeChordLabel('Bb7M', 1, preferFlats: false), 'B7M');
      expect(transposeChordLabel('Em(b13)', 1, preferFlats: true), 'Fm(b13)');
    });

    test('nao mexe em marcadores que comecam com *', () {
      // O corpus usa [*2x] e [*Coro] como anotacoes, nao como acordes.
      expect(transposeChordLabel('*2x', 5, preferFlats: true), '*2x');
      expect(transposeChordLabel('*Coro', -3, preferFlats: false), '*Coro');
    });

    test('devolve intacto o que nao for acorde reconhecivel', () {
      expect(transposeChordLabel('', 2, preferFlats: true), '');
      expect(transposeChordLabel('Hm', 2, preferFlats: true), 'Hm');
      expect(transposeChordLabel('  ', 1, preferFlats: true), '  ');
    });

    test('enarmonia respeita a preferencia pedida', () {
      expect(transposeChordLabel('A', 1, preferFlats: true), 'Bb');
      expect(transposeChordLabel('A', 1, preferFlats: false), 'A#');
    });
  });

  group('preferFlatsForKey', () {
    test('tom de destino bemol pede bemois', () {
      expect(preferFlatsForKey('G', 1), isTrue); // G -> Ab
      expect(preferFlatsForKey('D', 1), isTrue); // D -> Eb
      expect(preferFlatsForKey('A', 1), isTrue); // A -> Bb
      expect(preferFlatsForKey('E', 1), isTrue); // E -> F
    });

    test('tom de destino sustenido pede sustenidos', () {
      expect(preferFlatsForKey('G', -1), isFalse); // G -> F#
      expect(preferFlatsForKey('C', 2), isFalse); // C -> D
      expect(preferFlatsForKey('Bb', 1), isFalse); // Bb -> B
    });

    test('descer de Re da Reb, nao Do# — Reb maior e o tom usual', () {
      expect(preferFlatsForKey('D', -1), isTrue);
      expect(transposeKeyLabel('D', -1), 'Db');
    });

    test('ignora o m de tom menor', () {
      expect(preferFlatsForKey('Dm', 1), isTrue); // Dm -> Ebm
      expect(preferFlatsForKey('Em', -1), isTrue); // Em -> Ebm
      expect(preferFlatsForKey('Am', 2), isFalse); // Am -> Bm
    });

    test('tom ausente ou invalido cai em bemois, convencao do hinario', () {
      expect(preferFlatsForKey('', 1), isTrue);
      expect(preferFlatsForKey('Hx', 1), isTrue);
    });
  });

  group('transposeKeyLabel', () {
    test('transpoe o tom exibido no cabecalho', () {
      expect(transposeKeyLabel('G', 1), 'Ab');
      expect(transposeKeyLabel('D', 2), 'E');
      expect(transposeKeyLabel('Dm', 1), 'Ebm');
      expect(transposeKeyLabel('G', -1), 'F#');
    });

    test('tom vazio continua vazio', () {
      expect(transposeKeyLabel('', 3), '');
    });

    test('deslocamento zero nao altera a grafia original', () {
      expect(transposeKeyLabel('Eb', 0), 'Eb');
      expect(transposeKeyLabel('F#m', 0), 'F#m');
    });
  });
}
