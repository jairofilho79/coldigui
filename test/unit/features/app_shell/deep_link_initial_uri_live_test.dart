import 'package:coldigui/features/app_shell/presentation/utils/deep_link_initial_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('URL inicial com ?live= é preferida ao app_links', () {
    final base = Uri.parse('https://v2.plpcg.com/?live=k7x2m9q');
    expect(resolveWebInitialDeepLinkUri(null, browserUri: base), base);
    expect(
      resolveWebInitialDeepLinkUri(Uri.parse('plpcg:///x'), browserUri: base),
      base,
    );
  });

  test('sem live nem share cai para o app_links', () {
    final fallback = Uri.parse('plpcg:///x');
    expect(
      resolveWebInitialDeepLinkUri(
        fallback,
        browserUri: Uri.parse('https://v2.plpcg.com/'),
      ),
      fallback,
    );
  });
}
