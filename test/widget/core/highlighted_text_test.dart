// test/widget/core/highlighted_text_test.dart
//
// C5: `HighlightedText` destaca as ocorrências (acento-insensíveis) do termo
// buscado — mesma normalização do índice de busca (UC-01).
import 'package:coldigui/core/presentation/widgets/highlighted_text.dart';
import 'package:coldigui/core/theme/color_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  List<TextSpan> spansOf(WidgetTester tester) {
    final richText = tester.widget<Text>(find.byType(Text));
    return (richText.textSpan! as TextSpan).children!.cast<TextSpan>();
  }

  testWidgets('acento-insensível: "acao" destaca "Ação" em "Ação de Graças"', (
    tester,
  ) async {
    await pump(
      tester,
      const HighlightedText(text: 'Ação de Graças', query: 'acao'),
    );

    expect(find.text('Ação de Graças'), findsOneWidget);

    final highlighted = spansOf(
      tester,
    ).where((span) => span.style?.color == AppColors.gold).toList();
    expect(highlighted, hasLength(1));
    expect(highlighted.single.text, 'Ação');
  });

  testWidgets('query vazia não destaca nada', (tester) async {
    await pump(
      tester,
      const HighlightedText(text: 'Ação de Graças', query: ''),
    );

    expect(find.text('Ação de Graças'), findsOneWidget);
    final widget = tester.widget<Text>(find.byType(Text));
    // Sem match, o texto sai como `Text` simples (sem spans coloridos).
    expect(widget.data, 'Ação de Graças');
  });

  testWidgets('múltiplas ocorrências são todas destacadas', (tester) async {
    await pump(
      tester,
      const HighlightedText(text: 'Bendito seja o Bendito', query: 'bendito'),
    );

    expect(find.text('Bendito seja o Bendito'), findsOneWidget);

    final highlighted = spansOf(
      tester,
    ).where((span) => span.style?.color == AppColors.gold).toList();
    expect(highlighted, hasLength(2));
    expect(highlighted[0].text, 'Bendito');
    expect(highlighted[1].text, 'Bendito');
  });

  testWidgets(
    'vírgula no texto entre as palavras da query não impede o destaque',
    (tester) async {
      // Regressão: _matches fazia indexOf literal da query normalizada — só
      // acento/caixa, sem tolerar pontuação. "A Ti, pertence" (vírgula colada
      // em "Ti") não destacava nada pra query "a ti pertence", mesmo a frase
      // existindo ali (mesma causa do card sem trecho na busca de letra).
      await pump(
        tester,
        const HighlightedText(
          text: 'Graças, pois a Ti, pertence todo o louvor',
          query: 'a ti pertence',
        ),
      );

      final highlighted = spansOf(
        tester,
      ).where((span) => span.style?.color == AppColors.gold).toList();
      expect(highlighted, hasLength(1));
      expect(highlighted.single.text, 'a Ti, pertence');
    },
  );

  testWidgets(
    'vírgula na query entre as palavras do texto não impede o destaque',
    (tester) async {
      await pump(
        tester,
        const HighlightedText(
          text: 'a ti pertence todo o louvor',
          query: 'a ti, pertence',
        ),
      );

      final highlighted = spansOf(
        tester,
      ).where((span) => span.style?.color == AppColors.gold).toList();
      expect(highlighted, hasLength(1));
      expect(highlighted.single.text, 'a ti pertence');
    },
  );

  testWidgets('estilo de destaque customizado sobrepõe o padrão', (
    tester,
  ) async {
    await pump(
      tester,
      const HighlightedText(
        text: 'Aleluia',
        query: 'ale',
        highlightStyle: TextStyle(color: Colors.blue),
      ),
    );

    final highlighted = spansOf(
      tester,
    ).where((span) => span.style?.color == Colors.blue).toList();
    expect(highlighted, hasLength(1));
    expect(highlighted.single.text, 'Ale');
  });
}
