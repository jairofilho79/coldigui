import 'dart:io';

import 'package:coldigui/features/gestures/domain/entities/gesture_dictionary.dart';
import 'package:coldigui/features/gestures/domain/usecases/parse_gesture_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture() =>
    File('test/fixtures/gestures/dictionary.json').readAsStringSync();

void main() {
  test('parseia versão, data e entradas indexadas por id', () {
    final dict = parseGestureDictionary(_fixture());

    expect(dict.version, 3);
    expect(dict.generatedAt, DateTime.utc(2026, 9, 10, 12));
    expect(dict.byId, hasLength(13));
    final entry = dict.byId['e7b821c9041a']!;
    expect(entry.name, 'Apontar para cima');
    expect(entry.image, 'assets/cia/gestures/e7b821c9041a.png');
    expect(entry.gif, 'assets/cia/gestures/e7b821c9041a.gif');
    expect(entry.status, GestureStatus.active);
    expect(entry.exampleTriggers, ['com', 'Jesus']);
    expect(dict.byId['a1b2c3d4e5f6']!.status, GestureStatus.deprecated);
    expect(dict.byId['a1b2c3d4e5f6']!.replacedBy, 'c687580e7682');
  });

  test('entrada sem id ou sem image é descartada; status desconhecido é active', () {
    final dict = parseGestureDictionary(
      '{"version":1,"gestures":[{"id":"","image":"x.png"},{"id":"aaaaaaaaaaaa"},'
      '{"id":"bbbbbbbbbbbb","image":"b.png","status":"weird"}]}',
    );
    expect(dict.byId.keys, ['bbbbbbbbbbbb']);
    expect(dict.byId['bbbbbbbbbbbb']!.status, GestureStatus.active);
    expect(dict.byId['bbbbbbbbbbbb']!.gif, isNull);
    expect(dict.byId['bbbbbbbbbbbb']!.exampleTriggers, isEmpty);
  });

  test('version ausente vira 0; generatedAt ilegível vira null', () {
    final dict = parseGestureDictionary('{"gestures":[],"generatedAt":"ontem"}');
    expect(dict.version, 0);
    expect(dict.generatedAt, isNull);
    expect(dict.byId, isEmpty);
  });

  test('JSON inválido ou raiz não objeto lança', () {
    expect(
      () => parseGestureDictionary('nope'),
      throwsA(isA<GestureDictionaryParseException>()),
    );
    expect(
      () => parseGestureDictionary('[]'),
      throwsA(isA<GestureDictionaryParseException>()),
    );
  });
}
