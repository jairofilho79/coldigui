import 'oidc_browser.dart';

/// Nativo/testes sem override: nunca deve ser chamado — o botão nativo usa o
/// plugin `google_sign_in`. Lançar deixa um uso indevido evidente.
OidcBrowser createOidcBrowser() => const _UnsupportedOidcBrowser();

class _UnsupportedOidcBrowser implements OidcBrowser {
  const _UnsupportedOidcBrowser();

  Never _unsupported() =>
      throw UnsupportedError('OIDC redirect só existe na web');

  @override
  Uri get origin => _unsupported();
  @override
  String get fragment => '';
  @override
  bool get isStandaloneDisplay => false;
  @override
  String? readRequest() => null;
  @override
  void writeRequest(String json) => _unsupported();
  @override
  void clearRequest() {}
  @override
  void navigate(Uri uri) => _unsupported();
  @override
  void replaceHash(String path) {}
}
