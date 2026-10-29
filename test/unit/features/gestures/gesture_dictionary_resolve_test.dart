import 'dart:io';

import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';

GestureEntry _entry(String id, {String? replacedBy}) => GestureEntry(
  id: id,
  name: id,
  description: '',
  exampleTriggers: const [],
  image: 'assets/cia/gestures/$id.png',
  gif: null,
  status: replacedBy == null ? GestureStatus.active : GestureStatus.deprecated,
  replacedBy: replacedBy,
  updatedAt: null,
);

void main() {
  late GestureDictionary dict;

  setUp(() {
    dict = parseGestureDictionary(
      File('test/fixtures/gestures/dictionary.json').readAsStringSync(),
    );
  });

  test('id ativo resolve para si mesmo', () {
    expect(dict.resolve('c687580e7682')?.id, 'c687580e7682');
  });

  test('deprecated segue replacedBy até a entrada ativa', () {
    expect(dict.resolve('a1b2c3d4e5f6')?.id, 'c687580e7682');
  });

  test('id ausente devolve null', () {
    expect(dict.resolve('000000000000'), isNull);
    expect(dict.resolve(''), isNull);
  });

  test('ciclo não trava: devolve a última entrada visitada', () {
    final resolved = dict.resolve('b2c3d4e5f6a7');
    expect(resolved, isNotNull);
    expect(['b2c3d4e5f6a7', 'c3d4e5f6a7b8'], contains(resolved!.id));
  });

  test('cadeia maior que kGestureAliasMaxHops para no teto', () {
    // a0 → a1 → … → a7 (ativo): 7 saltos, teto 5 → para em a5.
    final entries = <String, GestureEntry>{};
    for (var i = 0; i <= 7; i++) {
      final id = 'a$i'.padRight(12, '0');
      final next = i == 7 ? null : 'a${i + 1}'.padRight(12, '0');
      entries[id] = _entry(id, replacedBy: next);
    }
    final chain = GestureDictionary(version: 1, generatedAt: null, byId: entries);

    expect(chain.resolve('a0'.padRight(12, '0'))?.id, 'a5'.padRight(12, '0'));
  });

  test('replacedBy apontando para id ausente devolve a própria deprecated', () {
    final dict = GestureDictionary(
      version: 1,
      generatedAt: null,
      byId: {'aaaaaaaaaaaa': _entry('aaaaaaaaaaaa', replacedBy: 'zzzzzzzzzzzz')},
    );
    expect(dict.resolve('aaaaaaaaaaaa')?.id, 'aaaaaaaaaaaa');
  });

  test('empty não tem entradas', () {
    expect(GestureDictionary.empty.byId, isEmpty);
    expect(GestureDictionary.empty.resolve('c687580e7682'), isNull);
  });
}
