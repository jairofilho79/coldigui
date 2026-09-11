import 'dart:io';

import 'package:coldigui/features/gestures/domain/entities/flat_gesture_card.dart';
import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/domain/utils/flatten_gesture_cards.dart';
import 'package:flutter_test/flutter_test.dart';

GestureDocument _fixture(String name) => parseGestureDocument(
  File('test/fixtures/gestures/$name').readAsStringSync(),
);

void main() {
  test('182: 14 cartões em ordem de documento; os 5 do coro têm ChorusContext', () {
    final flat = flattenGestureCards(_fixture('182_quero_viver.json'));

    expect(flat, hasLength(14));
    expect([for (final f in flat) f.index], List.generate(14, (i) => i));
    for (final f in flat.take(5)) {
      expect(f.contexts, [isA<ChorusContext>()]);
    }
    expect(flat[5].contexts, isEmpty);
    expect(flat[5].card.lyrics.single.trigger, 'Vou');
    // Instruções não entram na lista.
    expect(flat.last.card.lyrics.single.trigger, 'Viver');
  });

  test('181: os 4 do repeat carregam RepeatContext(2)', () {
    final flat = flattenGestureCards(_fixture('181_jerusalem.json'));

    expect(flat, hasLength(9));
    expect(flat[4].contexts, isEmpty);
    for (final f in flat.skip(5)) {
      expect(f.contexts, [isA<RepeatContext>().having((c) => c.count, 'count', 2)]);
    }
  });

  test('sintético: contextos aninhados do mais externo ao mais interno', () {
    final flat = flattenGestureCards(_fixture('sintetico_final_link.json'));

    // repeat3 > gesto solto
    expect(flat[0].contexts, [isA<RepeatContext>().having((c) => c.count, 'count', 3)]);
    // repeat3 > link > gesto
    expect(flat[1].contexts, [isA<RepeatContext>(), isA<LinkContext>()]);
    expect(flat[2].contexts, [isA<RepeatContext>(), isA<LinkContext>()]);
    // coro > repeat2 > gesto
    expect(flat[3].contexts, [isA<ChorusContext>(), isA<RepeatContext>()]);
    // gesto de id inexistente também entra
    expect(flat[4].card.gestureId, '000000000000');
    expect(flat[4].contexts, isEmpty);
    // final > gesto
    expect(flat[5].contexts, [isA<FinalContext>()]);
    expect(flat, hasLength(6));
  });

  test('documento sem gestos devolve lista vazia', () {
    final doc = parseGestureDocument('{"items":[{"type":"text","text":"x"}]}');
    expect(flattenGestureCards(doc), isEmpty);
  });
}
