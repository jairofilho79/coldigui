import 'package:coldigui/features/auth/data/oidc/oidc_browser.dart';

/// Navegador de mentira para o fluxo OIDC: registra navegações e
/// `replaceState`, guarda o request em memória.
class FakeOidcBrowser implements OidcBrowser {
  FakeOidcBrowser({
    Uri? origin,
    this.fragment = '',
    this.storedRequest,
    bool standalone = false,
    this.throwOnRead = false,
  }) : origin = origin ?? Uri.parse('https://v2.plpcg.com'),
       isStandaloneDisplay = standalone;

  @override
  final Uri origin;
  @override
  String fragment;
  @override
  final bool isStandaloneDisplay;

  String? storedRequest;
  final List<Uri> navigated = [];
  final List<String> replacedHashes = [];
  int clearRequestCalls = 0;

  /// Simula `sessionStorage` bloqueado (Safari "block all cookies"): até a
  /// leitura lança, não só a escrita.
  final bool throwOnRead;

  @override
  String? readRequest() {
    if (throwOnRead) throw StateError('sessionStorage bloqueado');
    return storedRequest;
  }

  @override
  void writeRequest(String json) => storedRequest = json;
  @override
  void clearRequest() {
    clearRequestCalls++;
    storedRequest = null;
  }

  @override
  void navigate(Uri uri) => navigated.add(uri);
  @override
  void replaceHash(String path) => replacedHashes.add(path);
}
