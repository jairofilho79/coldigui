import 'package:coldigui/features/app_shell/presentation/utils/app_link_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appLinkUriForV2WebDeepLink', () {
    test('converts a praise link to the app domain and preserves its URI', () {
      final result = appLinkUriForV2WebDeepLink(
        Uri.parse('https://v2.plpcg.com/louvor/abc123?source=a%2Fb#details'),
      );

      expect(result?.origin, 'https://plpcg.com');
      expect(result?.path, '/louvor/abc123');
      expect(result?.query, 'source=a%2Fb');
      expect(result?.fragment, 'details');
    });

    test('converts a playlist link and preserves its query', () {
      final result = appLinkUriForV2WebDeepLink(
        Uri.parse('https://v2.plpcg.com/?p=0a1-fff&n=Ensaio%20e%20culto'),
      );

      expect(result?.origin, 'https://plpcg.com');
      expect(result?.path, '/');
      expect(result?.query, 'p=0a1-fff&n=Ensaio%20e%20culto');
    });

    test('removes user information from the redirected app link', () {
      final result = appLinkUriForV2WebDeepLink(
        Uri(
          scheme: 'https',
          userInfo: 'test',
          host: 'v2.plpcg.com',
          path: '/louvor/abc123',
        ),
      );

      expect(result?.userInfo, isEmpty);
      expect(result?.origin, 'https://plpcg.com');
    });

    test('does not convert links from other hosts or unrelated pages', () {
      expect(
        appLinkUriForV2WebDeepLink(
          Uri.parse('https://plpcg.com/louvor/abc123'),
        ),
        isNull,
      );
      expect(
        appLinkUriForV2WebDeepLink(Uri.parse('https://v2.plpcg.com/')),
        isNull,
      );
    });

    test('does not convert invalid or legacy playlist links', () {
      expect(
        appLinkUriForV2WebDeepLink(
          Uri.parse('https://v2.plpcg.com/?p=invalid&n=Ensaio'),
        ),
        isNull,
      );
      expect(
        appLinkUriForV2WebDeepLink(
          Uri.parse('https://v2.plpcg.com/?sharepdfs=a'),
        ),
        isNull,
      );
    });
  });
}
