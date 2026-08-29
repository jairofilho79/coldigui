import 'package:coldigui/features/chords/domain/usecases/parse_chordpro.dart';
import 'package:coldigui/features/chords/presentation/theme/chord_reader_theme.dart';
import 'package:coldigui/features/chords/presentation/widgets/chordpro_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, String source,
    {ChordReaderMode mode = ChordReaderMode.light}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChordProView(
          song: parseChordPro(source),
          palette: mode.palette,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('desenha barra na celula encostada', (tester) async {
    await _pump(tester, 'ha[Cm]bi\n');

    expect(find.byKey(chordBarKey(0, 1)), findsOneWidget);
    expect(find.text('Cm'), findsOneWidget);
    expect(find.text('bi'), findsOneWidget);
  });

  testWidgets('nao desenha barra na celula solta', (tester) async {
    await _pump(tester, 'Deus e Amor [C]\n');

    expect(find.byKey(chordBarKey(0, 1)), findsNothing);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('preserva espacamento multiplo no texto', (tester) async {
    await _pump(tester, 'Deus e Amor   [C]\n');

    expect(find.text('Deus e Amor   '), findsOneWidget);
  });

  testWidgets('um espaco e tres espacos renderizam textos diferentes',
      (tester) async {
    await _pump(tester, 'Deus e Amor [C]\n');
    expect(find.text('Deus e Amor '), findsOneWidget);
    expect(find.text('Deus e Amor   '), findsNothing);
  });

  testWidgets('tres espacos ocupam mais largura que um espaco',
      (tester) async {
    // find.text casa por Text.data, entao um softWrap/overflow que engula os
    // espacos passaria verde. So a largura renderizada prova a promessa.
    await _pump(tester, 'Deus e Amor [C]\nDeus e Amor   [C]\n');

    expect(
      tester.getSize(find.text('Deus e Amor   ')).width,
      greaterThan(tester.getSize(find.text('Deus e Amor ')).width),
    );
  });

  testWidgets('celula sem acorde quebra em vez de ser cortada',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const long = 'Quando eu contemplo a cruz gloriosa em que ';
    await _pump(tester, '$long[C]morreu\n');

    final size = tester.getSize(find.text(long));
    expect(size.width, lessThanOrEqualTo(360));
    // Quebrou em duas linhas: sem softWrap seria uma linha so, cortada.
    expect(size.height, greaterThan(20));
  });

  testWidgets('renderiza comentario de diretiva', (tester) async {
    await _pump(tester, '{comment: Instrumentos: C Am}\nletra\n');

    expect(find.text('Instrumentos: C Am'), findsOneWidget);
  });

  testWidgets('nao renderiza comentario de autoria ;', (tester) async {
    await _pump(tester, '; recado de pipeline\nletra\n');

    expect(find.textContaining('recado de pipeline'), findsNothing);
  });

  testWidgets('paleta escura muda a cor da letra', (tester) async {
    await _pump(tester, 'letra\n', mode: ChordReaderMode.dark);

    final text = tester.widget<Text>(find.text('letra'));
    expect(text.style?.color, ChordReaderMode.dark.palette.lyric);
    expect(text.style?.color, isNot(ChordReaderMode.light.palette.lyric));
  });

  group('melhorias de leitura', () {
    testWidgets('zebra listra linhas de letra alternadas', (tester) async {
      await _pump(tester, 'linha um\nlinha dois\nlinha tres\nlinha quatro\n');

      // Índice par sem faixa, ímpar com faixa.
      expect(find.byKey(chordStripeKey(0)), findsNothing);
      expect(find.byKey(chordStripeKey(1)), findsOneWidget);
      expect(find.byKey(chordStripeKey(2)), findsNothing);
      expect(find.byKey(chordStripeKey(3)), findsOneWidget);
    });

    testWidgets('estrofe nao desloca a alternancia da zebra', (tester) async {
      // Sem contar só linhas de letra, a quebra entre estrofes faria a listra
      // "pular" e duas linhas seguidas ficariam com o mesmo fundo.
      await _pump(tester, 'um\ndois\n\n\ntres\nquatro\n');

      expect(find.byKey(chordStripeKey(1)), findsOneWidget);
      expect(find.byKey(chordStripeKey(2)), findsNothing);
      expect(find.byKey(chordStripeKey(3)), findsOneWidget);
    });

    testWidgets('fontSize escala letra e acorde juntos', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChordProView(
              song: parseChordPro('ha[Cm]bi\n'),
              palette: ChordReaderMode.light.palette,
              fontSize: 24,
            ),
          ),
        ),
      );

      final lyric = tester.widget<Text>(find.text('bi'));
      final chord = tester.widget<Text>(find.text('Cm'));
      expect(lyric.style?.fontSize, 24);
      // Proporção 13/16 preservada para o rótulo não descolar da sílaba.
      expect(chord.style?.fontSize, closeTo(24 * 13 / 16, 0.01));
    });

    testWidgets('transposicao muda os acordes e nao a letra', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChordProView(
              song: parseChordPro('{key: G}\n\nha[G]bi [Am]ta [D7/F#]la\n'),
              palette: ChordReaderMode.light.palette,
              semitones: 2,
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('Bm'), findsOneWidget);
      expect(find.text('E7/G#'), findsOneWidget);
      // A letra segue intacta.
      expect(find.text('bi '), findsOneWidget);
      expect(find.text('ta '), findsOneWidget);
      // E os rótulos originais sumiram.
      expect(find.text('G'), findsNothing);
      expect(find.text('Am'), findsNothing);
    });

    testWidgets('transposicao respeita a grafia do tom de destino',
        (tester) async {
      // G subindo um vira Lab (bemois), nao Sol# (oito sustenidos).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChordProView(
              song: parseChordPro('{key: G}\n\nca[G]sa [C]la\n'),
              palette: ChordReaderMode.light.palette,
              semitones: 1,
            ),
          ),
        ),
      );

      expect(find.text('Ab'), findsOneWidget);
      expect(find.text('Db'), findsOneWidget);
      expect(find.text('G#'), findsNothing);
    });

    testWidgets('transposicao nao mexe em marcadores como [*2x]',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChordProView(
              song: parseChordPro('{key: G}\n\nca[*2x]sa\n'),
              palette: ChordReaderMode.light.palette,
              semitones: 3,
            ),
          ),
        ),
      );

      expect(find.text('*2x'), findsOneWidget);
    });
  });
}
