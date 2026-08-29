import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/url_sync_params.dart';
import '../../core/widgets/deferred_route_loader.dart';
import '../../core/widgets/storage_required_gate.dart';
import '../../features/app_shell/presentation/shell_scaffold.dart';
import '../../features/catalog/presentation/pages/home_screen.dart';
import '../../features/library/presentation/pages/library_screen.dart';
import '../../features/audio_player/presentation/pages/audio_player_screen.dart';
import '../../features/chords/presentation/pages/chord_reader_screen.dart';
import '../../features/pdf_reader/data/pdfrx_bootstrap.dart';
import '../../features/pdf_reader/presentation/pages/pdf_reader_screen.dart';
import '../../features/playlists/presentation/pages/playlists_screen.dart';
import 'route_paths.dart';

/// Navigator raiz do [GoRouter] — snackbars do [DeepLinkListener] (UC-14).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Rotas ocultas neste build de integração (deep links → home).
const _hiddenShellPaths = {
  RoutePaths.events,
  RoutePaths.social,
  RoutePaths.profile,
  RoutePaths.about,
  RoutePaths.offline,
};

/// Router principal do app — [StatefulShellRoute] com 3 destinos + leitor.
///
/// Abas: Biblioteca | Pesquisar | Listas.
/// `/leitor` e `/audio` são sub-rotas da branch Home.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.home,
    redirect: (context, state) {
      final path = state.uri.path;
      if (_hiddenShellPaths.contains(path)) {
        return RoutePaths.home;
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.library,
                builder: (context, state) => LibraryScreen(
                  initialFonte: state.uri.queryParameters[UrlSyncParams.fonte],
                  initialMateriais:
                      state.uri.queryParameters[UrlSyncParams.materiais],
                  initialArranjo:
                      state.uri.queryParameters[UrlSyncParams.arranjo],
                  initialArranjoEspecial:
                      state.uri.queryParameters[UrlSyncParams.arranjoEspecial],
                  initialTonality:
                      state.uri.queryParameters[UrlSyncParams.tonality],
                  initialRhythm:
                      state.uri.queryParameters[UrlSyncParams.rhythm],
                  initialCategory:
                      state.uri.queryParameters[UrlSyncParams.category],
                  initialTags: state.uri.queryParameters[UrlSyncParams.tags],
                  initialMaterialKinds:
                      state.uri.queryParameters[UrlSyncParams.materialKinds],
                  initialOrdenar:
                      state.uri.queryParameters[UrlSyncParams.ordenar],
                  initialItensPorPagina:
                      state.uri.queryParameters[UrlSyncParams.itensPorPagina],
                  initialPagina:
                      state.uri.queryParameters[UrlSyncParams.pagina],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (context, state) => HomeScreen(
                  initialSearchQuery:
                      state.uri.queryParameters[UrlSyncParams.pesquisa] ?? '',
                  initialMateriais:
                      state.uri.queryParameters[UrlSyncParams.materiais],
                  initialArranjo:
                      state.uri.queryParameters[UrlSyncParams.arranjo],
                ),
                routes: [
                  GoRoute(
                    path: 'leitor',
                    builder: (context, state) => DeferredRouteLoader(
                      loadingMessage: 'Carregando leitor…',
                      load: ensurePdfrxInitialized,
                      builder: () => PdfReaderScreen(
                        queryParams: state.uri.queryParameters,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'audio',
                    builder: (context, state) => AudioPlayerScreen(
                      queryParams: state.uri.queryParameters,
                    ),
                  ),
                  GoRoute(
                    path: 'cifra',
                    builder: (context, state) => ChordReaderScreen(
                      queryParams: state.uri.queryParameters,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.playlists,
                builder: (context, state) =>
                    const StorageRequiredGate(child: PlaylistsScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
