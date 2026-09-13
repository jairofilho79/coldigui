/// Tudo que o fluxo OIDC precisa do navegador (spec §3.4). Implementação web
/// em `oidc_browser_web.dart`; nativo lança — o botão nativo usa o plugin.
abstract interface class OidcBrowser {
  /// `window.location.origin`.
  Uri get origin;

  /// `window.location.hash` sem o `#`.
  String get fragment;

  /// PWA instalado (`display-mode: standalone` ou `navigator.standalone`) —
  /// só para a dica de D15.
  bool get isStandaloneDisplay;

  String? readRequest();
  void writeRequest(String json);
  void clearRequest();

  /// `window.location.assign` — a página inteira vai para o Google.
  void navigate(Uri uri);

  /// `history.replaceState(null, '', '#$path')` — tira o token da URL antes
  /// de o go_router ler o hash.
  void replaceHash(String path);
}
