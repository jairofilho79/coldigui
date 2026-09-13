import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_tabs.dart';
import '../../core/constants/feature_flags.dart';
import '../../core/providers/feature_flags_provider.dart';
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
import '../../features/material_kind_prefs/presentation/pages/favorite_material_kinds_screen.dart';
import '../../features/offline/presentation/pages/offline_settings_screen.dart';
import '../../features/audio_player/presentation/pages/audio_player_screen.dart';
import '../../features/pdf_reader/data/pdfrx_bootstrap.dart';
import '../../features/pdf_reader/presentation/pages/pdf_reader_screen.dart';
import '../../features/playlists/presentation/pages/playlists_screen.dart';
import '../../features/social/presentation/pages/public_playlists_screen.dart';
import 'route_paths.dart';

/// Navigator raiz do [GoRouter] — snackbars do [DeepLinkListener] (UC-14).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router principal do app — [StatefulShellRoute] com as abas de
/// [appTabsFor] (E6) + leitor.
///
/// Rotas em [RoutePaths]. `/leitor` é sub-rota da branch Home para reutilizar o
/// mesmo header ([PlpcgPrimaryAppBar] + [CarouselChips]) e estado do carousel.
/// `/audio` e `/cifra` são irmãs de `/leitor` na mesma branch.
///
/// Branch Listas: `/listas` + sub-rota `/listas/publicas` (só com
/// `FF_SOCIAL`). Branch Perfil: `/perfil`, `/biblioteca`, `/offline`, `/sobre`.
/// `/social` (aba antiga) redireciona para `/listas/publicas`.
///
/// As `StatefulShellBranch` são montadas a partir de [appTabsFor] — com
/// `FF_EVENTS=false` (padrão) a rota `/eventos` não é registrada; navegar
/// para ela (ou qualquer caminho desconhecido) não lança nem fica na página
/// de erro padrão do [GoRouter] — o `redirect` de nível superior manda pra
/// Home. Índices de branch (`selectedIndex`/`goBranch`) são sempre a posição
/// do item na mesma lista — nunca hardcoded.
///
/// `/leitor` adia só a init do pdfrx; offline/leitor no bundle principal (WebKit
/// dart2js não registra `.part.js` via `<script>` — ver flutter_bootstrap webkit).
final appRouterProvider = Provider<GoRouter>((ref) {
  final flags = ref.read(featureFlagsProvider);
  final tabs = appTabsFor(flags);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.home,
    // `/social` era aba própria; hoje é sub-rota de Listas — links antigos
    // seguem funcionando. Com `FF_SOCIAL` desligada `/listas/publicas` não é
    // registrada, então `/social` manda direto pra Home: o go_router não
    // reaplica o `redirect` de nível superior sobre o novo match de erro
    // que resultaria de mandar pra uma rota inexistente. Qualquer outra rota
    // desconhecida/escondida (`/eventos` com a flag off não registra a rota
    // — comentário acima) não pode parar na página de erro padrão do
    // GoRouter: manda pra Home.
    redirect: (context, state) {
      if (state.uri.path == RoutePaths.social) {
        return flags.social ? RoutePaths.publicPlaylists : RoutePaths.home;
      }
      return state.error != null ? RoutePaths.home : null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [for (final tab in tabs) _branchFor(tab, flags)],
      ),
    ],
  );
});

/// `StatefulShellBranch` de [tab] — mesma ordem/rotas usadas quando todas as
/// flags estavam sempre ligadas; ver [appRouterProvider].
StatefulShellBranch _branchFor(AppTab tab, FeatureFlags flags) {
  return switch (tab) {
    AppTab.events => StatefulShellBranch(
      routes: [
        GoRoute(
          path: RoutePaths.events,
          builder: (context, state) =>
              const PlaceholderTabScreen(title: 'Eventos'),
        ),
      ],
    ),
    AppTab.playlists => StatefulShellBranch(
      routes: [
        GoRoute(
          path: RoutePaths.playlists,
          builder: (context, state) =>
              const StorageRequiredGate(child: PlaylistsScreen()),
          routes: [
            if (flags.social)
              GoRoute(
                path: 'publicas',
                builder: (context, state) => const PublicPlaylistsScreen(),
              ),
          ],
        ),
      ],
    ),
    AppTab.home => StatefulShellBranch(
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
    AppTab.profile => StatefulShellBranch(
      routes: [
        GoRoute(
          path: RoutePaths.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: RoutePaths.library,
          builder: (context, state) {
            final params = safeQueryParameters(state.uri);
            return LibraryScreen(
              initialFonte: params[UrlSyncParams.fonte],
              initialMateriais: params[UrlSyncParams.materiais],
              initialArranjo: params[UrlSyncParams.arranjo],
              initialArranjoEspecial: params[UrlSyncParams.arranjoEspecial],
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
        GoRoute(
          path: RoutePaths.about,
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: RoutePaths.favoriteMaterialKinds,
          builder: (context, state) => const FavoriteMaterialKindsScreen(),
        ),
        GoRoute(
          path: RoutePaths.offline,
          builder: (context, state) =>
              const StorageRequiredGate(child: OfflineSettingsScreen()),
        ),
      ],
    ),
  };
}
