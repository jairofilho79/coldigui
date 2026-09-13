import 'dart:io';

import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture(String name) =>
    File('test/fixtures/gestures/$name').readAsStringSync();

void main() {
  group('fixtures reais', () {
    test('182: coro com 5 cartões, gestos soltos e duas instruções', () {
      final doc = parseGestureDocument(_fixture('182_quero_viver.json'));

      expect(doc.schemaMajor, 1);
      expect(doc.isNewerSchema, isFalse);
      expect(doc.title, '182 - QUERO VIVER PRA SEMPRE COM JESUS');
      expect(doc.dictionaryVersion, 1);
      // 12 itens de raiz: coro(5) + 5 gestos + instrução + 4 gestos + instrução.
      expect(doc.items, hasLength(12));
      expect(doc.hasGestures, isTrue);

      final coro = doc.items.first as ChorusBlock;
      expect(coro.children, hasLength(5));
      final first = coro.children.first as GestureCard;
      expect(first.gestureId, 'c687580e7682');
      expect(first.lyrics.single.trigger, 'Quero');
      expect(first.lyrics.single.text, 'viver para sempre');

      expect(
        doc.items[6],
        isA<InstructionCard>().having(
          (i) => i.kind,
          'kind',
          InstructionKind.backToChorus,
        ),
      );
      expect(
        doc.items.last,
        isA<InstructionCard>().having(
          (i) => i.kind,
          'kind',
          InstructionKind.backToChorusAndFinish,
        ),
      );
    });

    test('181: cinco na raiz e repeat 2 com quatro filhos', () {
      final doc = parseGestureDocument(_fixture('181_jerusalem.json'));

      expect(doc.items, hasLength(6));
      final repeat = doc.items.last as RepeatBlock;
      expect(repeat.count, 2);
      expect(repeat.children, hasLength(4));
      final twoLines = doc.items[4] as GestureCard;
      expect(twoLines.lyrics, hasLength(2));
      expect(twoLines.lyrics[1].trigger, '');
    });

    test('sintético: final, link dentro de repeat, instrução e desconhecido', () {
      final doc = parseGestureDocument(_fixture('sintetico_final_link.json'));

      expect(doc.items.first, isA<InstructionCard>());
      final repeat = doc.items[1] as RepeatBlock;
      expect(repeat.count, 3);
      expect(repeat.children[1], isA<LinkBlock>());
      expect((repeat.children[1] as LinkBlock).children, hasLength(2));
      final coro = doc.items[2] as ChorusBlock;
      expect(coro.children.single, isA<RepeatBlock>());
      // Tipo desconhecido vira texto com o JSON compactado.
      expect(
        doc.items[3],
        isA<TextLine>().having(
          (t) => t.text,
          'text',
          '{"type":"hologram","foo":1}',
        ),
      );
      expect(doc.items[4], isA<TextLine>().having((t) => t.text, 'text', 'linha livre'));
      expect(doc.items.last, isA<FinalBlock>());
    });

    test('schema v2 marca isNewerSchema e ainda parseia', () {
      final doc = parseGestureDocument(_fixture('schema_v2.json'));

      expect(doc.schemaMajor, 2);
      expect(doc.isNewerSchema, isTrue);
      expect(doc.items.single, isA<GestureCard>());
    });
  });

  group('falhas conclusivas', () {
    test('JSON inválido lança GestureDocumentParseException', () {
      expect(
        () => parseGestureDocument('{nope'),
        throwsA(isA<GestureDocumentParseException>()),
      );
    });

    test('raiz que não é objeto lança', () {
      expect(
        () => parseGestureDocument('[1, 2]'),
        throwsA(isA<GestureDocumentParseException>()),
      );
    });
  });

  group('tolerância item a item', () {
    test('items ausente vira documento vazio, sem gestos', () {
      final doc = parseGestureDocument('{"schema":"coldigom.gestures/1","title":"X"}');
      expect(doc.items, isEmpty);
      expect(doc.hasGestures, isFalse);
    });

    test('count ausente ou menor que 2 cai para 2', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"repeat","children":[{"type":"gesture","gestureId":"c687580e7682"}]},'
        '{"type":"repeat","count":1,"children":[{"type":"gesture","gestureId":"c687580e7682"}]},'
        '{"type":"repeat","count":"4","children":[{"type":"gesture","gestureId":"c687580e7682"}]}]}',
      );
      expect((doc.items[0] as RepeatBlock).count, 2);
      expect((doc.items[1] as RepeatBlock).count, 2);
      expect((doc.items[2] as RepeatBlock).count, 4);
    });

    test('bloco sem filhos válidos é descartado', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"coro","children":[]},{"type":"link"},{"type":"final","children":[42]}]}',
      );
      expect(doc.items, isEmpty);
    });

    test('lyrics ausente vira uma linha vazia; mais de 3 é truncado', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"gesture","gestureId":"c687580e7682"},'
        '{"type":"gesture","gestureId":"c687580e7682","lyrics":['
        '{"trigger":"a"},{"trigger":"b"},{"trigger":"c"},{"trigger":"d"}]}]}',
      );
      final empty = doc.items[0] as GestureCard;
      expect(empty.lyrics.single.trigger, '');
      expect(empty.lyrics.single.text, '');
      expect((doc.items[1] as GestureCard).lyrics, hasLength(3));
    });

    test('gestureId inválido é mantido cru (placeholder decide na tela)', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"gesture","gestureId":"XYZ","lyrics":[{"trigger":"a","text":"b"}]}]}',
      );
      expect((doc.items.single as GestureCard).gestureId, 'XYZ');
    });

    test('instruction com kind desconhecido vira texto', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"instruction","kind":"dance"}]}',
      );
      expect(doc.items.single, isA<TextLine>());
    });

    test('text vazio é descartado; campos desconhecidos são ignorados', () {
      final doc = parseGestureDocument(
        '{"items":[{"type":"text","text":"  "},{"type":"text","text":"ok","extra":true}]}',
      );
      expect(doc.items, hasLength(1));
      expect((doc.items.single as TextLine).text, 'ok');
    });

    test('item que não é objeto é ignorado', () {
      final doc = parseGestureDocument('{"items":[1,"x",null,{"type":"text","text":"a"}]}');
      expect(doc.items, hasLength(1));
    });
  });

  group('parseSchemaMajor', () {
    test('lê o major depois da barra', () {
      expect(parseSchemaMajor('coldigom.gestures/1'), 1);
      expect(parseSchemaMajor('coldigom.gestures/2'), 2);
      expect(parseSchemaMajor('coldigom.gestures/3.1'), 3);
    });

    test('ausente ou inválido assume 1', () {
      expect(parseSchemaMajor(null), 1);
      expect(parseSchemaMajor(7), 1);
      expect(parseSchemaMajor('sem-barra'), 1);
      expect(parseSchemaMajor('x/abc'), 1);
    });
  });
}
