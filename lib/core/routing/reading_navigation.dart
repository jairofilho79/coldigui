import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_paths.dart';

/// Rotas de leitura — as «faces» de um louvor (partitura, áudio, cifra,
/// gestos, letra), todas irmãs na branch Home.
///
/// Mais amplo que o `isReaderRoute` do áudio (que decide se o leitor segue a
/// faixa e deixa `/audio` e `/letra` de fora de propósito): aqui a pergunta é
/// só «já estou lendo um louvor?».
const Set<String> readingRoutePaths = {
  RoutePaths.reader,
  RoutePaths.audio,
  RoutePaths.chords,
  RoutePaths.gestos,
  RoutePaths.lyrics,
};

/// `true` quando a rota atual é uma de [readingRoutePaths].
bool isReadingRoute(BuildContext context) {
  if (GoRouter.maybeOf(context) == null) return false;
  return readingRoutePaths.contains(GoRouterState.of(context).uri.path);
}

/// Abre [location] (uma rota de leitura) sem empilhar leitores.
///
/// Só a entrada na leitura empilha (Pesquisa/Biblioteca/Listas → leitor):
/// é o `push` que a seta de voltar desfaz. Já lendo, trocar de face
/// (partitura → áudio → cifra …) ou de louvor substitui a rota — voltar
/// sempre cai de onde se entrou, não percorre cada troca.
void openReadingLocation(BuildContext context, String location) {
  if (isReadingRoute(context)) {
    replaceReadingLocation(context, location);
  } else {
    unawaited(context.push(location));
  }
}

/// `context.replace` que também substitui a entrada do histórico do
/// navegador.
///
/// Com `optionURLReflectsImperativeAPIs` o go_router reporta o `replace` como
/// navegação normal (`pushState` na web): a pilha do app não crescia, mas o
/// voltar do sistema (Android/PWA) percorria cada troca. [Router.neglect]
/// vira `replaceState` — mesma premissa de redirect síncrono de
/// `goReplacingUrl`.
void replaceReadingLocation(BuildContext context, String location) {
  Router.neglect(context, () => context.replace(location));
}
