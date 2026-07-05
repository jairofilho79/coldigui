import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/url_sync_params.dart';
import '../../core/widgets/deferred_route_loader.dart';
import '../../deferred/offline_bulk_deferred.dart' deferred as offline_bulk;
import '../../deferred/pdf_reader_deferred.dart' deferred as pdf_reader;
import '../../features/app_shell/presentation/pages/about_screen.dart';
import '../../features/app_shell/presentation/shell_scaffold.dart';
import '../../features/catalog/presentation/pages/home_screen.dart';
import '../../features/library/presentation/pages/library_screen.dart';
import '../../features/playlists/presentation/pages/playlists_screen.dart';
import 'route_paths.dart';

/// Navigator raiz do [GoRouter] — snackbars do [DeepLinkListener] (UC-14).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router principal do app — [StatefulShellRoute] com 5 destinos + leitor.
///
/// Rotas em [RoutePaths]. `/leitor` é sub-rota da branch Home para reutilizar o
/// mesmo header ([PlpcgPrimaryAppBar] + [CarouselChips]) e estado do carousel.
///
/// `/leitor` e `/offline` carregam chunks deferred (Fase F — code splitting).
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
                    pageBuilder: (context, state) => MaterialPage<void>(
                      child: DeferredRouteLoader(
                        loadingMessage: 'Carregando leitor…',
                        load: () => pdf_reader.preparePdfReaderModule(
                          pdf_reader.loadLibrary,
                        ),
                        builder: () => pdf_reader.PdfReaderScreen(
                          queryParams: state.uri.queryParameters,
                        ),
                      ),
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
                pageBuilder: (context, state) => MaterialPage<void>(
                  child: DeferredRouteLoader(
                    loadingMessage: 'Carregando offline…',
                    load: offline_bulk.loadLibrary,
                    builder: () => offline_bulk.OfflineSettingsScreen(),
                  ),
                ),
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
