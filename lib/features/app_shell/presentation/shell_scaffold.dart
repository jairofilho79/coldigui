import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_tabs.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/providers/feature_flags_provider.dart';
import '../../../core/routing/route_paths.dart';
import '../../../core/widgets/degraded_storage_banner.dart';
import '../../../core/widgets/plpcg_primary_app_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../audio_player/domain/entities/audio_track.dart';
import '../../audio_player/presentation/providers/audio_player_session_provider.dart';
import '../../audio_player/presentation/widgets/mini_player_bar.dart';
import '../../audio_player/presentation/widgets/mini_player_bar_metrics.dart';
import '../../auth/presentation/providers/auth_state_provider.dart';
import '../../playlists/presentation/providers/playlist_media_face_provider.dart';
import '../../playlists/presentation/providers/playlist_sync_provider.dart';
import '../../carousel/presentation/providers/carousel_items_provider.dart';
import '../../carousel/presentation/widgets/carousel_chips.dart';
import '../../offline/presentation/widgets/offline_lifecycle_listener.dart';
import '../../pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import '../../pdf_reader/presentation/providers/reader_route_params_provider.dart';
import 'utils/browser_title.dart';
import 'widgets/app_shortcuts.dart';
import 'widgets/plpcg_bottom_nav_bar.dart';
import 'widgets/plpcg_navigation_rail.dart';
import 'widgets/stage_wakelock.dart';

/// UC-14 — Shell com navegação (bottom bar ou rail) para as abas de
/// [appTabsFor] (E6).
///
/// Header compartilhado: [PlpcgPrimaryAppBar] + [CarouselChips] em todas as
/// rotas do shell, inclusive `/leitor` (barra 3 do PDF fica no [PdfReaderScreen]).
/// Em fullscreen ([readerFullscreenProvider]), oculta barras 1–2 mantendo
/// `Expanded(child)` para o PDF não perder constraints.
///
/// Navegação: Eventos (se [FeatureFlags.events]), Biblioteca, Pesquisar,
/// Social (se [FeatureFlags.social]), Perfil — mesma lista de [appTabsFor]
/// usada pelo router, então os índices de [StatefulNavigationShell] sempre
/// batem com a posição na lista. Em largura ≥ [kRailBreakpoint] (C6), usa
/// [PlpcgNavigationRail] à esquerda do corpo em vez de [PlpcgBottomNavBar].
/// Ambas ocultas em `/leitor`, `/audio` e `/cifra`. Destino central:
/// **Pesquisar** (logo PLPCG, [RoutePaths.home]). Aba Perfil: avatar + nome
/// quando autenticado.
///
/// [navigationShell] mantém o estado de cada aba via [StatefulShellRoute].
///
/// Mini-player persistente (D5, [MiniPlayerBar]): entre a barra de chips e o
/// corpo sempre que há faixa tocando **e** a face de áudio não está visível
/// (ela já mostra esses controles — [shouldShowCarouselAudioFace]); em
/// fullscreen, sobrevive como overlay translúcido sobre o `navigationShell`.
/// No layout com rail, mini-player e chips ficam na coluna à direita do rail.
///
/// Título da aba (C14, [browserTitle]): o corpo do `Scaffold` fica dentro de
/// um [Title] — mecanismo do Flutter para o `<title>` da aba no web
/// (inofensivo no nativo).
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  /// Pilha indexada das branches do shell — preserva estado ao trocar aba.
  final StatefulNavigationShell navigationShell;

  bool _isImmersiveMediaRoute(String path) {
    return path == RoutePaths.reader ||
        path == RoutePaths.audio ||
        path == RoutePaths.chords ||
        path == RoutePaths.gestos;
  }

  /// Destinos na mesma ordem/índices de [tabs] (por sua vez, [appTabsFor]) —
  /// consumidos tanto por [PlpcgBottomNavBar] quanto por
  /// [PlpcgNavigationRail].
  List<PlpcgBottomNavDestination> _destinations(
    WidgetRef ref,
    List<AppTab> tabs,
  ) {
    final user = ref.watch(authStateProvider).asData?.value;
    final profileLabel = user?.displayFirstName ?? 'Perfil';
    final profileAvatar = user?.pictureUrl != null
        ? NetworkImage(user!.pictureUrl!)
        : null;

    return [
      for (final tab in tabs)
        switch (tab) {
          AppTab.events => const PlpcgBottomNavDestination(
            icon: Icons.event,
            label: 'Eventos',
          ),
          AppTab.library => const PlpcgBottomNavDestination(
            icon: Icons.library_books,
            label: 'Biblioteca',
          ),
          AppTab.home => const PlpcgBottomNavDestination(
            svgAsset: 'assets/branding/logo_colorido_no_bg_logo_only.svg',
            label: 'Pesquisar',
          ),
          AppTab.social => const PlpcgBottomNavDestination(
            icon: Icons.groups,
            label: 'Social',
          ),
          AppTab.profile => PlpcgBottomNavDestination(
            icon: profileAvatar == null ? Icons.person : null,
            avatarImage: profileAvatar,
            label: profileLabel,
          ),
        },
    ];
  }

  /// Rótulo da aba corrente para [browserTitle] — mesmos nomes de
  /// [_destinations] fora do leitor/cifra/áudio (que têm rótulo próprio).
  String _tabLabel(String path) {
    return switch (path) {
      RoutePaths.events => 'Eventos',
      RoutePaths.library => 'Biblioteca',
      RoutePaths.home => 'Pesquisar',
      RoutePaths.social => 'Social',
      RoutePaths.profile => 'Perfil',
      RoutePaths.about => 'Sobre',
      RoutePaths.offline => 'Offline',
      RoutePaths.playlists => 'Listas',
      RoutePaths.audio => 'Áudio',
      _ => 'PLPCG',
    };
  }

  /// Params do leitor/cifra para [browserTitle] — URL primeiro (atualização
  /// imediata após `context.replace`), [readerRouteParamsProvider] como
  /// fallback (mesma prioridade de [CarouselChips]).
  Map<String, String> _readerParams(
    BuildContext context,
    WidgetRef ref,
    bool isReaderRoute,
  ) {
    if (!isReaderRoute) return const {};
    final fromRouter = GoRouterState.of(context).uri.queryParameters;
    if (fromRouter.isNotEmpty) return fromRouter;
    return ref.watch(readerRouteParamsProvider);
  }

  String? _trackTitleLabel(AudioTrack? track) {
    if (track == null) return null;
    return track.numero.isNotEmpty
        ? '${track.numero} — ${track.nome}'
        : track.nome;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playlistSyncProvider);
    final path = GoRouterState.of(context).uri.path;
    final isImmersive = _isImmersiveMediaRoute(path);
    final isFullscreen = ref.watch(readerFullscreenProvider);

    if (!isImmersive && ref.read(readerFullscreenProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(readerFullscreenProvider.notifier).exit();
      });
    }

    final hideChrome = isImmersive && isFullscreen;

    final currentTrack = ref.watch(
      audioPlayerSessionProvider.select((s) => s.currentTrack),
    );

    final isReaderRoute =
        path == RoutePaths.reader || path == RoutePaths.chords;
    final l10n = AppLocalizations.of(context)!;
    final title = browserTitle(
      l10n: l10n,
      readerParams: _readerParams(context, ref, isReaderRoute),
      trackTitle: path == RoutePaths.audio
          ? _trackTitleLabel(currentTrack)
          : null,
      tabLabel: _tabLabel(path),
    );

    final showMiniPlayer =
        !hideChrome &&
        currentTrack != null &&
        !shouldShowCarouselAudioFace(
          face: ref.watch(playlistMediaFaceProvider),
          hasPdf: ref.watch(carouselItemsProvider).isNotEmpty,
          hasAudio:
              ref.watch(audioFaceItemsProvider).isNotEmpty ||
              ref.watch(
                audioPlayerSessionProvider.select((s) => s.queue.isNotEmpty),
              ),
        );

    final tabs = appTabsFor(ref.read(featureFlagsProvider));
    final destinations = _destinations(ref, tabs);
    // C6: rail substitui a bottom bar ≥ kRailBreakpoint; nenhuma das duas em
    // rotas imersivas (leitor/áudio/cifra têm navegação própria).
    final showRail =
        !isImmersive && MediaQuery.sizeOf(context).width >= kRailBreakpoint;

    final bodyColumn = Column(
      children: [
        const DegradedStorageBanner(),
        const CarouselChips(),
        if (showMiniPlayer) const MiniPlayerBar(),
        Expanded(child: navigationShell),
      ],
    );

    return OfflineLifecycleListener(
      child: StageWakelockListener(
        path: path,
        child: AppShortcuts(
          path: path,
          child: Title(
            color: Theme.of(context).colorScheme.primary,
            title: title,
            child: Scaffold(
              appBar: hideChrome ? null : const PlpcgPrimaryAppBar(),
              body: hideChrome
                  ? Stack(
                      children: [
                        navigationShell,
                        if (currentTrack != null)
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: kMiniPlayerBarHeight,
                            child: MiniPlayerBar(overlay: true),
                          ),
                      ],
                    )
                  : SafeArea(
                      top: false,
                      bottom: false,
                      child: showRail
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PlpcgNavigationRail(
                                  selectedIndex: navigationShell.currentIndex,
                                  onDestinationSelected:
                                      navigationShell.goBranch,
                                  destinations: destinations,
                                ),
                                Expanded(child: bodyColumn),
                              ],
                            )
                          : bodyColumn,
                    ),
              bottomNavigationBar: (isImmersive || showRail)
                  ? null
                  : PlpcgBottomNavBar(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: navigationShell.goBranch,
                      destinations: destinations,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
