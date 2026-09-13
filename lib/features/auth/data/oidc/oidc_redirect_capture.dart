import 'oidc_browser.dart';
import 'oidc_callback.dart';
import 'oidc_redirect_request.dart';

/// Chamado no início de `main()`, **antes** de o go_router existir (spec D5):
/// se o hash é um callback do Google, consome o request pendente, tira o
/// token da URL e devolve o resultado. Hash de rota normal → `null`, sem
/// tocar em nada.
OidcCallbackResult? captureOidcRedirectCallback(OidcBrowser browser) {
  // Roda antes de existir qualquer UI (splash) — um `sessionStorage`
  // bloqueado (Safari "block all cookies" lança `SecurityError` até para
  // leitura) ou qualquer outra surpresa aqui não pode derrubar o app nesse
  // ponto; melhor cair para o fluxo normal (sessão armazenada / login) do
  // que travar a inicialização.
  try {
    final fragment = browser.fragment;
    if (fragment.isEmpty || fragment.startsWith('/')) return null;

    final request = OidcRedirectRequest.fromJson(browser.readRequest());
    final result = OidcCallbackParser.parse(
      fragment: fragment,
      request: request,
    );
    if (result == null) return null;

    browser.clearRequest();
    browser.replaceHash(result.returnTo);
    return result;
  } on Object catch (_) {
    return null;
  }
}
