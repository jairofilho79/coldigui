import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_palette.dart';
import 'package:coldigui/features/gestures/presentation/widgets/lyric_line_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RichText> _pump(WidgetTester tester, LyricLine line, {double width = 400}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(width: width, child: LyricLineText(line: line, fontSize: 18)),
      ),
    ),
  );
  return tester.widget<RichText>(find.byType(RichText));
}

/// `Text.rich` envolve o span dado num `TextSpan` raiz (com o estilo do
/// `DefaultTextStyle`); os spans do gatilho/leitura estão um nível abaixo.
List<TextSpan> _spans(RichText rich) {
  final root = rich.text as TextSpan;
  final ours = root.children!.single as TextSpan;
  return ours.children!.cast<TextSpan>();
}

void main() {
  testWidgets('gatilho vermelho negrito + espaço + leitura preta', (tester) async {
    final rich = await _pump(tester, const LyricLine(trigger: 'Quero', text: 'viver'));
    final spans = _spans(rich);
    expect(spans[0].text, 'Quero');
    expect(spans[0].style?.color, GestureReaderPalette.trigger);
    expect(spans[0].style?.fontWeight, FontWeight.bold);
    expect(spans[1].text, ' viver');
    expect(spans[1].style?.color, GestureReaderPalette.lyric);
    expect(spans[1].style?.fontWeight, isNot(FontWeight.bold));
  });

  testWidgets('sem espaço quando a leitura começa com pontuação', (tester) async {
    for (final punct in [',', '.', ';', ':', '!', '?', ')', ']']) {
      final rich = await _pump(tester, LyricLine(trigger: 'a', text: '${punct}b'));
      expect(_spans(rich)[1].text, '${punct}b', reason: punct);
    }
  });

  testWidgets('gatilho vazio → só a leitura, sem espaço na frente', (tester) async {
    final rich = await _pump(tester, const LyricLine(trigger: '', text: 'só leitura'));
    final spans = _spans(rich);
    expect(spans, hasLength(1));
    expect(spans.single.text, 'só leitura');
  });

  testWidgets('leitura vazia → só o gatilho', (tester) async {
    final rich = await _pump(tester, const LyricLine(trigger: 'Amém', text: ''));
    expect(_spans(rich).single.text, 'Amém');
  });

  test('nonBreaking troca espaço por NBSP', () {
    expect(nonBreaking('É certeza'), 'É\u00A0certeza');
  });

  testWidgets('gatilho de duas palavras nunca quebra linha', (tester) async {
    // Largura pequena força quebra; a linha 1 tem que conter o gatilho inteiro.
    final rich = await _pump(
      tester,
      const LyricLine(trigger: 'É certeza', text: 'que Jesus me prometeu'),
      width: 120,
    );
    expect(_spans(rich)[0].text, 'É\u00A0certeza');
  });
}
