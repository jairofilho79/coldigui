import 'package:coldigui/features/app_shell/presentation/utils/deep_link_initial_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveWebInitialDeepLinkUri', () {
    test('retorna fromAppLinks com params de share (sem plpcg://)', () {
      final fromAppLinks = Uri.parse('/?p=0a1-fff&n=Minha%20Lista');

      final resolved = resolveWebInitialDeepLinkUri(fromAppLinks);

      expect(resolved, fromAppLinks);
      expect(resolved?.queryParameters['p'], '0a1-fff');
      expect(resolved?.queryParameters['n'], 'Minha Lista');
      expect(resolved?.scheme, isNot('plpcg'));
    });

    test('retorna fromAppLinks para URL https com query params', () {
      final fromAppLinks = Uri.parse('https://v2.plpcg.com/?p=0a1&n=Teste');

      expect(resolveWebInitialDeepLinkUri(fromAppLinks), fromAppLinks);
    });

    test('retorna null quando fromAppLinks é null e base sem share', () {
      expect(resolveWebInitialDeepLinkUri(null), isNull);
    });

    test('retorna fromAppLinks sem share quando base também não tem', () {
      final fromAppLinks = Uri.parse('https://plpcjf.org/');
      expect(resolveWebInitialDeepLinkUri(fromAppLinks), fromAppLinks);
    });

    test('prefere a URL do browser com ?p=&n=', () {
      final browser = Uri.parse('/?p=0a1&n=Lista');
      final fromAppLinks = Uri.parse('/');

      expect(
        resolveWebInitialDeepLinkUri(fromAppLinks, browserUri: browser),
        browser,
      );
    });

    // Spec fim-fonte-plpcg §4.4: o link antigo ainda tem que chegar ao
    // listener, que avisa e limpa a URL — `sharepdfs` sozinho já conta.
    test('prefere a URL do browser com link antigo (para o aviso)', () {
      final browser = Uri.parse('/?sharepdfs=a');

      expect(resolveWebInitialDeepLinkUri(null, browserUri: browser), browser);
    });

    test('prefere a URL do browser com link curto antigo /l/<código>', () {
      final browser = Uri.parse('https://v2.plpcg.com/l/abc123');

      expect(resolveWebInitialDeepLinkUri(null, browserUri: browser), browser);
    });

    test(
      'recupera p/n quando um campo irrelevante da query base tem % malformado',
      () {
        final malformedBase = Uri.parse('/?p=0a1&n=Lista&junk=%E0%A4%A');

        final resolved = resolveWebInitialDeepLinkUri(
          null,
          browserUri: malformedBase,
        );

        expect(resolved, isNotNull);
        expect(resolved?.queryParameters['p'], '0a1');
        expect(resolved?.queryParameters['n'], 'Lista');
      },
    );

    test('cai para fromAppLinks sem lançar quando query base malformada não recupera share params', () {
      // `p` malformado sai; `n` sozinho não é link de lista.
      final malformedBase = Uri.parse('/?p=%E0%A4%A&n=Y');
      final fromAppLinks = Uri.parse('/?p=0a1&n=Y');

      expect(
        resolveWebInitialDeepLinkUri(fromAppLinks, browserUri: malformedBase),
        fromAppLinks,
      );
    });
  });
}
