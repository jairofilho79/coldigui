import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// `router.go(location)` sem criar entrada no histórico do navegador.
///
/// Uso: espelhar estado de UI na URL (texto da busca, filtros, página da
/// Biblioteca). O go_router reporta `go` como navegação normal e, na web,
/// isso vira `history.pushState` — cada termo digitado virava uma entrada e
/// o botão voltar percorria `sangue` → `sangue de` → `sangue de jesus`
/// (auditoria P4). [Router.neglect] marca o report como `neglect`, que o
/// engine traduz em `replaceState`.
///
/// [context] precisa estar abaixo do [Router] (qualquer tela do app serve).
void goReplacingUrl(BuildContext context, GoRouter router, String location) {
  Router.neglect(context, () => router.go(location));
}
