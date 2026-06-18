import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/url_sync_params.dart';
import '../../features/app_shell/presentation/pages/about_screen.dart';
import '../../features/app_shell/presentation/shell_scaffold.dart';
import '../../features/catalog/presentation/pages/home_screen.dart';
import '../../features/library/presentation/pages/library_screen.dart';
import '../../features/offline/presentation/pages/offline_settings_screen.dart';
import '../../features/pdf_reader/presentation/pages/pdf_reader_screen.dart';
import '../../features/playlists/presentation/pages/playlists_screen.dart';
import 'route_paths.dart';

/// Navigator raiz do [GoRouter] — snackbars do [DeepLinkListener] (UC-14).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router principal do app — [StatefulShellRoute] com 5 destinos + leitor.
///
/// Rotas em [RoutePaths]. `/leitor` é sub-rota da branch Home para reutilizar o
/// mesmo header ([PlpcgPrimaryAppBar] + [CarouselChips]) e estado do carousel.
///
/// A Home hidrata busca e filtros a partir de [UrlSyncParams.pesquisa],
/// [UrlSyncParams.materiais] e [UrlSyncParams.arranjo]; a escrita é feita
/// pela tela via [buildHomeLocation] + GoRouter.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.about,
                builder: (context, state) => const AboutScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.library,
                builder: (context, state) => LibraryScreen(
                  initialMateriais:
                      state.uri.queryParameters[UrlSyncParams.materiais],
                  initialArranjo:
                      state.uri.queryParameters[UrlSyncParams.arranjo],
                  initialArranjoEspecial:
                      state.uri.queryParameters[UrlSyncParams.arranjoEspecial],
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
                    builder: (context, state) => PdfReaderScreen(
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
                path: RoutePaths.offline,
                builder: (context, state) => const OfflineSettingsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.playlists,
                builder: (context, state) => const PlaylistsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
