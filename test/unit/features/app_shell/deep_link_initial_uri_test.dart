import 'package:coldigui/features/app_shell/presentation/utils/deep_link_initial_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveWebInitialDeepLinkUri', () {
    test('retorna fromAppLinks com params de share (sem plpcg://)', () {
      final fromAppLinks = Uri.parse(
        '/?sharepdfs=id1,id2&sharename=Minha%20Lista',
      );

      final resolved = resolveWebInitialDeepLinkUri(fromAppLinks);

      expect(resolved, fromAppLinks);
      expect(resolved?.queryParameters['sharepdfs'], 'id1,id2');
      expect(resolved?.queryParameters['sharename'], 'Minha Lista');
      expect(resolved?.scheme, isNot('plpcg'));
    });

    test('retorna fromAppLinks para URL https com query params', () {
      final fromAppLinks = Uri.parse(
        'https://plpcjf.org/?sharepdfs=a&sharename=Teste',
      );

      expect(resolveWebInitialDeepLinkUri(fromAppLinks), fromAppLinks);
    });

    test('retorna null quando fromAppLinks é null e base sem share', () {
      expect(resolveWebInitialDeepLinkUri(null), isNull);
    });

    test('retorna fromAppLinks sem share quando base também não tem', () {
      final fromAppLinks = Uri.parse('https://plpcjf.org/');
      expect(resolveWebInitialDeepLinkUri(fromAppLinks), fromAppLinks);
    });

    test(
      'recupera sharepdfs/sharename quando um campo irrelevante da query base tem % malformado',
      () {
        final malformedBase = Uri.parse(
          '/?sharepdfs=a&sharename=Lista&junk=%E0%A4%A',
        );

        final resolved = resolveWebInitialDeepLinkUri(
          null,
          browserUri: malformedBase,
        );

        expect(resolved, isNotNull);
        expect(resolved?.queryParameters['sharepdfs'], 'a');
        expect(resolved?.queryParameters['sharename'], 'Lista');
      },
    );

    test(
      'cai para fromAppLinks sem lançar quando query base malformada não recupera share params',
      () {
        final malformedBase = Uri.parse('/?sharename=%E0%A4%A&sharepdfs=a');
        final fromAppLinks = Uri.parse('/?sharepdfs=x&sharename=Y');

        expect(
          resolveWebInitialDeepLinkUri(fromAppLinks, browserUri: malformedBase),
          fromAppLinks,
        );
      },
    );
  });
}
