import 'package:coldigui/core/utils/louvor_search_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LouvorSearchTokens', () {
    test('normalize remove acentos', () {
      expect(LouvorSearchTokens.normalize('São João'), 'sao joao');
    });

    test('tokenize remove stop words', () {
      final tokens = LouvorSearchTokens.tokenize('O Senhor é a minha luz');
      expect(tokens, contains('senhor'));
      expect(tokens, contains('luz'));
      expect(tokens, isNot(contains('o')));
      expect(tokens, isNot(contains('a')));
    });
  });
}
