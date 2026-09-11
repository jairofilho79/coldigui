import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/safe_query_parameters.dart';
import '../../core/utils/url_sync_params.dart';
import '../../core/widgets/deferred_route_loader.dart';
import '../../core/widgets/storage_required_gate.dart';
import '../../features/app_shell/presentation/pages/about_screen.dart';
import '../../features/app_shell/presentation/pages/placeholder_tab_screen.dart';
import '../../features/app_shell/presentation/pages/profile_screen.dart';
import '../../features/app_shell/presentation/shell_scaffold.dart';
import '../../features/catalog/presentation/pages/home_screen.dart';
import '../../features/chords/presentation/pages/chord_reader_screen.dart';
import '../../features/gestures/presentation/pages/gesture_reader_screen.dart';
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
/// `/audio` e `/cifra` são irmãs de `/leitor` na mesma branch.
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
                builder: (context, state) {
                  final params = safeQueryParameters(state.uri);
                  return LibraryScreen(
                    initialFonte: params[UrlSyncParams.fonte],
                    initialMateriais: params[UrlSyncParams.materiais],
                    initialArranjo: params[UrlSyncParams.arranjo],
                    initialArranjoEspecial:
                        params[UrlSyncParams.arranjoEspecial],
                    initialTonality: params[UrlSyncParams.tonality],
                    initialRhythm: params[UrlSyncParams.rhythm],
                    initialCategory: params[UrlSyncParams.category],
                    initialTags: params[UrlSyncParams.tags],
                    initialMaterialKinds: params[UrlSyncParams.materialKinds],
                    initialOrdenar: params[UrlSyncParams.ordenar],
                    initialItensPorPagina: params[UrlSyncParams.itensPorPagina],
                    initialPagina: params[UrlSyncParams.pagina],
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                builder: (context, state) {
                  final params = safeQueryParameters(state.uri);
                  return HomeScreen(
                    initialSearchQuery: params[UrlSyncParams.pesquisa] ?? '',
                    initialMateriais: params[UrlSyncParams.materiais],
                    initialArranjo: params[UrlSyncParams.arranjo],
                  );
                },
                routes: [
                  GoRoute(
                    path: 'leitor',
                    builder: (context, state) => DeferredRouteLoader(
                      load: ensurePdfrxInitialized,
                      builder: () => PdfReaderScreen(
                        queryParams: safeQueryParameters(state.uri),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'audio',
                    builder: (context, state) => AudioPlayerScreen(
                      queryParams: safeQueryParameters(state.uri),
                    ),
                  ),
                  GoRoute(
                    path: 'cifra',
                    builder: (context, state) => ChordReaderScreen(
                      queryParams: safeQueryParameters(state.uri),
                    ),
                  ),
                  GoRoute(
                    path: 'gestos',
                    builder: (context, state) => GestureReaderScreen(
                      queryParams: safeQueryParameters(state.uri),
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
