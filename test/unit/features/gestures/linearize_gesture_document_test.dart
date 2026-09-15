import 'dart:io';

import 'package:coldigui/features/gestures/domain/entities/gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/linearize_gesture_document.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_document.dart';
import 'package:coldigui/features/gestures/domain/utils/flatten_gesture_cards.dart';
import 'package:flutter_test/flutter_test.dart';

GestureDocument _fixture(String name) => parseGestureDocument(
  File('test/fixtures/gestures/$name').readAsStringSync(),
);

GestureDocument _doc(List<GestureItem> items) =>
    GestureDocument(schemaMajor: 1, title: 't', dictionaryVersion: 1, items: items);

GestureCard _g(String trigger) =>
    GestureCard(gestureId: 'c687580e7682', lyrics: [LyricLine(trigger: trigger, text: '')]);

/// Forma legível da árvore: `g:<trigger>`, `coro`, `2ª`, `!kind`, `link[...]`,
/// `final[...]`, `~texto`. Cartões e blocos não têm `==`, então comparar
/// strings é o jeito estável de comparar estrutura.
String _shape(List<GestureItem> items) => items.map(_shapeOf).join(' ');

String _shapeOf(GestureItem item) => switch (item) {
  GestureCard(:final lyrics) => 'g:${lyrics.first.trigger}',
  SectionLabel(:final pass) => pass == null ? 'coro' : '$passª',
  InstructionCard(:final kind) => '!${kind.name}',
  TextLine(:final text) => '~$text',
  LinkBlock(:final children) => 'link[${_shape(children)}]',
  FinalBlock(:final children) => 'final[${_shape(children)}]',
  RepeatBlock(:final count, :final children) => '${count}x[${_shape(children)}]',
  ChorusBlock(:final children) => 'CORO[${_shape(children)}]',
};

void main() {
  test('cartões, texto e «instrumentos» passam inalterados; título e schema também', () {
    final doc = GestureDocument(
      schemaMajor: 2,
      title: 'X',
      dictionaryVersion: 7,
      items: [_g('a'), const TextLine('livre'), const InstructionCard(InstructionKind.instruments)],
    );
    final out = linearizeGestureDocument(doc);
    expect(_shape(out.items), 'g:a ~livre !instruments');
    expect(out.schemaMajor, 2);
    expect(out.title, 'X');
    expect(out.dictionaryVersion, 7);
  });

  test('Nx repete os filhos N vezes com «kª vez» antes de cada passagem a partir da 2ª', () {
    final out = linearizeGestureDocument(_doc([
      RepeatBlock(count: 3, children: [_g('a'), _g('b')]),
    ]));
    expect(_shape(out.items), 'g:a g:b 2ª g:a g:b 3ª g:a g:b');
  });

  test('CORO vira rótulo + filhos, sem chave', () {
    final out = linearizeGestureDocument(_doc([
      ChorusBlock(children: [_g('a')]),
      _g('b'),
    ]));
    expect(_shape(out.items), 'coro g:a g:b');
  });

  test('«voltar ao coro» repete o último coro visto, com rótulo', () {
    final out = linearizeGestureDocument(_doc([
      ChorusBlock(children: [_g('c1'), _g('c2')]),
      _g('v'),
      const InstructionCard(InstructionKind.backToChorus),
      _g('w'),
      const InstructionCard(InstructionKind.backToChorusAndFinish),
      FinalBlock(children: [_g('f')]),
    ]));
    expect(_shape(out.items), 'coro g:c1 g:c2 g:v coro g:c1 g:c2 g:w coro g:c1 g:c2 final[g:f]');
  });

  test('«voltar ao coro» sem coro mantém a instrução', () {
    final out = linearizeGestureDocument(_doc([
      _g('a'),
      const InstructionCard(InstructionKind.backToChorus),
    ]));
    expect(_shape(out.items), 'g:a !backToChorus');
  });

  test('coro dentro de Nx conta como último coro', () {
    final out = linearizeGestureDocument(_doc([
      RepeatBlock(count: 2, children: [ChorusBlock(children: [_g('c')])]),
      const InstructionCard(InstructionKind.backToChorus),
    ]));
    expect(_shape(out.items), 'coro g:c 2ª coro g:c coro g:c');
  });

  test('«repetir o louvor» duplica tudo que a raiz já emitiu, com «2ª vez»', () {
    final out = linearizeGestureDocument(_doc([
      _g('a'),
      RepeatBlock(count: 2, children: [_g('b')]),
      const InstructionCard(InstructionKind.repeatPraise),
      _g('z'),
    ]));
    expect(_shape(out.items), 'g:a g:b 2ª g:b 2ª g:a g:b 2ª g:b g:z');
  });

  test('«repetir o louvor» sem nada antes mantém a instrução', () {
    final out = linearizeGestureDocument(_doc([
      const InstructionCard(InstructionKind.repeatPraise),
      _g('a'),
    ]));
    expect(_shape(out.items), '!repeatPraise g:a');
  });

  test('«repetir o louvor» dentro de bloco copia só o que a raiz emitiu antes do bloco', () {
    final out = linearizeGestureDocument(_doc([
      _g('a'),
      FinalBlock(children: [_g('f'), const InstructionCard(InstructionKind.repeatPraise)]),
    ]));
    expect(_shape(out.items), 'g:a final[g:f 2ª g:a]');
  });

  test('link e final são mantidos com os filhos linearizados', () {
    final out = linearizeGestureDocument(_doc([
      LinkBlock(children: [_g('a'), RepeatBlock(count: 2, children: [_g('b')])]),
      FinalBlock(children: [RepeatBlock(count: 2, children: [_g('c')])]),
    ]));
    expect(_shape(out.items), 'link[g:a g:b 2ª g:b] final[g:c 2ª g:c]');
  });

  test('181: o 2x da raiz rende 4 + 4 cartões com «2ª vez» no meio', () {
    final out = linearizeGestureDocument(_fixture('181_jerusalem.json'));
    expect(flattenGestureCards(out), hasLength(13));
    expect(_shape(out.items).split(' ').where((s) => s == '2ª').length, 1);
    expect(_shape(out.items), endsWith('g:Jesus 2ª g:Aleluia, g:glória g:Aleluia, g:Jesus'));
  });

  test('182: o coro reaparece nos dois «voltar ao coro»; sem chip de contexto no flatten', () {
    final out = linearizeGestureDocument(_fixture('182_quero_viver.json'));
    // 5 (coro) + 5 + 5 (coro) + 4 + 5 (coro) = 24
    final flat = flattenGestureCards(out);
    expect(flat, hasLength(24));
    expect(flat.every((f) => f.contexts.isEmpty), isTrue);
    expect(_shape(out.items).split(' ').where((s) => s == 'coro').length, 3);
    expect(out.items.whereType<InstructionCard>(), isEmpty);
  });

  test('sintético: 3x com link dentro, coro{2x}, item desconhecido, final', () {
    final out = linearizeGestureDocument(_fixture('sintetico_final_link.json'));
    expect(
      _shape(out.items),
      '!instruments '
      'g:Um link[g:Ligado g:seguinte] 2ª g:Um link[g:Ligado g:seguinte] 3ª g:Um link[g:Ligado g:seguinte] '
      'coro g:Coro 2ª g:Coro '
      '~{"type":"hologram","foo":1} ~linha livre g:Id '
      'final[g:Fim]',
    );
  });

  test('é idempotente: linearizar o já linear não muda nada', () {
    for (final name in ['181_jerusalem.json', '182_quero_viver.json', 'sintetico_final_link.json']) {
      final once = linearizeGestureDocument(_fixture(name));
      final twice = linearizeGestureDocument(once);
      expect(_shape(twice.items), _shape(once.items), reason: name);
    }
  });
}
