import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/url_sync_params.dart';
import '../../core/widgets/deferred_route_loader.dart';
import '../../core/widgets/storage_required_gate.dart';
import '../../features/app_shell/presentation/pages/about_screen.dart';
import '../../features/app_shell/presentation/pages/placeholder_tab_screen.dart';
import '../../features/app_shell/presentation/pages/profile_screen.dart';
import '../../features/app_shell/presentation/shell_scaffold.dart';
import '../../features/catalog/presentation/pages/home_screen.dart';
import '../../features/library/presentation/pages/library_screen.dart';
import '../../features/offline/presentation/pages/offline_settings_screen.dart';
import '../../features/audio_player/presentation/pages/audio_player_screen.dart';
import '../../features/pdf_reader/data/pdfrx_bootstrap.dart';
import '../../features/pdf_reader/presentation/pages/pdf_reader_screen.dart';
import '../../features/playlists/presentation/pages/playlists_screen.dart';
import '../../features/social/presentation/pages/social_screen.dart';
import 'route_paths.dart';

/// Navigator raiz do [GoRouter] — snackbars do [DeepLinkListener] (UC-14).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router principal do app — [StatefulShellRoute] com 5 destinos + leitor.
///
/// Rotas em [RoutePaths]. `/leitor` é sub-rota da branch Home para reutilizar o
/// mesmo header ([PlpcgPrimaryAppBar] + [CarouselChips]) e estado do carousel.
///
/// Branch Perfil (índice 4) também hospeda `/sobre`, `/offline` e `/listas`.
///
/// `/leitor` adia só a init do pdfrx; offline/leitor no bundle principal (WebKit
/// dart2js não registra `.part.js` via `<script>` — ver flutter_bootstrap webkit).
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
                path: RoutePaths.events,
                builder: (context, state) =>
                    const PlaceholderTabScreen(title: 'Eventos'),
              ),
            ],
          ),
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
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.social,
                builder: (context, state) => const SocialScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: RoutePaths.about,
                builder: (context, state) => const AboutScreen(),
              ),
              GoRoute(
                path: RoutePaths.offline,
                builder: (context, state) =>
                    const StorageRequiredGate(child: OfflineSettingsScreen()),
              ),
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
