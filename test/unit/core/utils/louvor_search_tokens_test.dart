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

    test('tokenize separa hífens', () {
      expect(
        LouvorSearchTokens.tokenize('Buscar-me-eis'),
        ['buscar', 'me', 'eis'],
      );
    });

    test('compact remove separadores', () {
      expect(LouvorSearchTokens.compact('Buscar-me-eis'), 'buscarmeeis');
    });

    test('matchesText por tokens com espaços', () {
      expect(
        LouvorSearchTokens.matchesText(
          contentTokens: ['buscar', 'me', 'eis'],
          compactContent: 'buscarmeeis',
          query: 'buscar me eis',
          queryTokens: ['buscar', 'me', 'eis'],
        ),
        isTrue,
      );
    });

    test('matchesText por forma compacta sem separadores', () {
      expect(
        LouvorSearchTokens.matchesText(
          contentTokens: ['buscar', 'me', 'eis'],
          compactContent: 'buscarmeeis',
          query: 'buscarmeeis',
          queryTokens: ['buscarmeeis'],
        ),
        isTrue,
      );
    });

    test('matchesText por hífens na query', () {
      expect(
        LouvorSearchTokens.matchesText(
          contentTokens: ['buscar', 'me', 'eis'],
          compactContent: 'buscarmeeis',
          query: 'buscar-me-eis',
          queryTokens: ['buscar', 'me', 'eis'],
        ),
        isTrue,
      );
    });
  });
}
