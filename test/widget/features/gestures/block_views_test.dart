import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/presentation/theme/gesture_reader_palette.dart';
import 'package:coldigui/features/gestures/presentation/widgets/brace_painter.dart';
import 'package:coldigui/features/gestures/presentation/widgets/chorus_block_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/final_section_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/instruction_card_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/link_block_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/link_connector_painter.dart';
import 'package:coldigui/features/gestures/presentation/widgets/repeat_block_view.dart';
import 'package:coldigui/features/gestures/presentation/widgets/text_line_view.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _child(String label, double height) =>
    SizedBox(key: ValueKey(label), height: height, child: Text(label));

Future<void> _pump(WidgetTester tester, Widget body, {Locale locale = const Locale('pt')}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      // Altura ilimitada, como no corpo rolável do leitor.
      home: Scaffold(
        body: SingleChildScrollView(
          // Align solta a largura: sem ele o scroll view força 800 no SizedBox.
          child: Align(alignment: Alignment.topLeft, child: SizedBox(width: 360, child: body)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('RepeatBlockView', () {
    testWidgets('chave cobre exatamente a altura dos filhos e mostra Nx', (tester) async {
      await _pump(tester, RepeatBlockView(count: 2, children: [_child('a', 40), _child('b', 60)]));

      final brace = tester.getRect(find.byKey(gestureBraceKey));
      final first = tester.getRect(find.byKey(const ValueKey('a')));
      final last = tester.getRect(find.byKey(const ValueKey('b')));
      expect(brace.top, first.top);
      expect(brace.bottom, last.bottom);
      expect(brace.width, kGestureBraceWidth);
      expect(brace.right, 360);
      final painter = tester.widget<CustomPaint>(find.byKey(gestureBraceKey)).painter as BracePainter;
      expect(painter.label, '2x');
      expect(painter.dashed, isFalse);
    });

    testWidgets('aninhado: a chave externa envolve a interna (recuo por nível)', (tester) async {
      await _pump(
        tester,
        RepeatBlockView(count: 3, children: [
          RepeatBlockView(count: 2, children: [_child('a', 40)]),
        ]),
      );
      final braces = find.byKey(gestureBraceKey);
      expect(braces, findsNWidgets(2));
      // Ordem de árvore: a chave interna (dentro do Padding) vem antes da
      // externa (Positioned irmão); não dependa dela, ordene pela posição.
      final a = tester.getRect(braces.first);
      final b = tester.getRect(braces.last);
      final inner = a.left < b.left ? a : b;
      final outer = a.left < b.left ? b : a;
      expect(inner.right, lessThanOrEqualTo(outer.left));
    });
  });

  group('ChorusBlockView', () {
    testWidgets('rótulo CORO azul acima e chave tracejada cobrindo os filhos', (tester) async {
      await _pump(tester, ChorusBlockView(children: [_child('a', 40), _child('b', 40)]));

      final label = tester.widget<Text>(find.text('CORO'));
      expect(label.style?.color, GestureReaderPalette.blue);
      expect(label.style?.fontWeight, FontWeight.bold);
      final brace = tester.getRect(find.byKey(gestureBraceKey));
      expect(brace.top, tester.getRect(find.byKey(const ValueKey('a'))).top);
      expect(brace.bottom, tester.getRect(find.byKey(const ValueKey('b'))).bottom);
      expect(tester.getRect(find.text('CORO')).bottom, lessThanOrEqualTo(brace.top));
      final painter = tester.widget<CustomPaint>(find.byKey(gestureBraceKey)).painter as BracePainter;
      expect(painter.dashed, isTrue);
      expect(painter.label, isNull);
    });

    testWidgets('em inglês o rótulo é CHORUS', (tester) async {
      await _pump(tester, ChorusBlockView(children: [_child('a', 40)]), locale: const Locale('en'));
      expect(find.text('CHORUS'), findsOneWidget);
    });
  });

  group('LinkBlockView', () {
    testWidgets('conector laranja à esquerda, filhos sem espaço entre si', (tester) async {
      await _pump(tester, LinkBlockView(children: [_child('a', 40), _child('b', 40)]));
      final connector = tester.getRect(find.byKey(gestureLinkConnectorKey));
      expect(connector.left, 0);
      expect(connector.width, kGestureLinkWidth);
      final a = tester.getRect(find.byKey(const ValueKey('a')));
      final b = tester.getRect(find.byKey(const ValueKey('b')));
      expect(b.top, a.bottom);
      expect(connector.top, a.top);
      expect(connector.bottom, b.bottom);
      expect(tester.widget<CustomPaint>(find.byKey(gestureLinkConnectorKey)).painter, isA<LinkConnectorPainter>());
    });
  });

  group('FinalSectionView', () {
    testWidgets('divisor + rótulo FINAL antes dos filhos', (tester) async {
      await _pump(tester, FinalSectionView(children: [_child('a', 40)]));
      expect(find.byKey(gestureFinalDividerKey), findsOneWidget);
      final label = tester.widget<Text>(find.text('FINAL'));
      expect(label.style?.color, GestureReaderPalette.wine);
      expect(tester.getRect(find.text('FINAL')).bottom, lessThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('a'))).top));
    });
  });

  group('InstructionCardView', () {
    testWidgets('quatro rótulos em pt', (tester) async {
      for (final (kind, label) in [
        (InstructionKind.instruments, 'Instrumentos'),
        (InstructionKind.repeatPraise, 'Repetir o louvor'),
        (InstructionKind.backToChorus, 'Voltar ao coro'),
        (InstructionKind.backToChorusAndFinish, 'Voltar ao coro e finalizar'),
      ]) {
        await _pump(tester, InstructionCardView(kind: kind));
        expect(find.text(label), findsOneWidget, reason: kind.name);
      }
    });

    testWidgets('quatro rótulos em en', (tester) async {
      for (final (kind, label) in [
        (InstructionKind.instruments, 'Instruments'),
        (InstructionKind.repeatPraise, 'Repeat the hymn'),
        (InstructionKind.backToChorus, 'Back to chorus'),
        (InstructionKind.backToChorusAndFinish, 'Back to chorus and finish'),
      ]) {
        await _pump(tester, InstructionCardView(kind: kind), locale: const Locale('en'));
        expect(find.text(label), findsOneWidget, reason: kind.name);
      }
    });

    testWidgets('ocupa a largura toda com fundo cinza', (tester) async {
      await _pump(tester, const InstructionCardView(kind: InstructionKind.instruments));
      expect(tester.getSize(find.byType(InstructionCardView)).width, 360);
    });
  });

  testWidgets('TextLineView é cinza e itálico', (tester) async {
    await _pump(tester, const TextLineView(text: 'linha livre', fontSize: 18));
    final text = tester.widget<Text>(find.text('linha livre'));
    expect(text.style?.color, GestureReaderPalette.freeText);
    expect(text.style?.fontStyle, FontStyle.italic);
  });
}
