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
}
