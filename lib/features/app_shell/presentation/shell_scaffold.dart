import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
import '../../../core/widgets/degraded_storage_banner.dart';
import '../../../core/widgets/plpcg_primary_app_bar.dart';
import '../../auth/presentation/providers/auth_state_provider.dart';
import '../../carousel/presentation/widgets/carousel_chips.dart';
import '../../offline/presentation/widgets/offline_lifecycle_listener.dart';
import '../../pdf_reader/presentation/providers/reader_fullscreen_provider.dart';
import 'widgets/plpcg_bottom_nav_bar.dart';

/// UC-14 — Shell com bottom bar customizada de 5 destinos.
///
/// Header compartilhado: [PlpcgPrimaryAppBar] + [CarouselChips] em todas as
/// rotas do shell, inclusive `/leitor` (barra 3 do PDF fica no [PdfReaderScreen]).
/// Em fullscreen ([readerFullscreenProvider]), oculta barras 1–2 mantendo
/// `Expanded(child)` para o PDF não perder constraints.
///
/// Bottom bar: Eventos, Biblioteca, Pesquisar, Social, Perfil. Oculta em
/// `/leitor`. Destino central: **Pesquisar** (logo PLPCG, [RoutePaths.home]).
/// Aba Perfil: avatar + nome quando autenticado.
///
/// [navigationShell] mantém o estado de cada aba via [StatefulShellRoute].
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  /// Pilha indexada das branches do shell — preserva estado ao trocar aba.
  final StatefulNavigationShell navigationShell;

  bool _isImmersiveMediaRoute(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return path == RoutePaths.reader || path == RoutePaths.audio;
  }

  List<PlpcgBottomNavDestination> _destinations(WidgetRef ref) {
    final user = ref.watch(authStateProvider).asData?.value;
    final profileLabel = user?.displayFirstName ?? 'Perfil';
    final profileAvatar = user?.pictureUrl != null
        ? NetworkImage(user!.pictureUrl!)
        : null;

    return [
      const PlpcgBottomNavDestination(icon: Icons.event, label: 'Eventos'),
      const PlpcgBottomNavDestination(
        icon: Icons.library_books,
        label: 'Biblioteca',
      ),
      const PlpcgBottomNavDestination(
        svgAsset: 'assets/branding/logo_colorido_no_bg_logo_only.svg',
        label: 'Pesquisar',
      ),
      const PlpcgBottomNavDestination(icon: Icons.groups, label: 'Social'),
      PlpcgBottomNavDestination(
        icon: profileAvatar == null ? Icons.person : null,
        avatarImage: profileAvatar,
        label: profileLabel,
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isImmersive = _isImmersiveMediaRoute(context);
    final isFullscreen = ref.watch(readerFullscreenProvider);

    if (!isImmersive && ref.read(readerFullscreenProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(readerFullscreenProvider.notifier).exit();
      });
    }

    final hideChrome = isImmersive && isFullscreen;

    return OfflineLifecycleListener(
      child: Scaffold(
        appBar: hideChrome ? null : const PlpcgPrimaryAppBar(),
        body: hideChrome
            ? navigationShell
            : SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                    const DegradedStorageBanner(),
                    const CarouselChips(),
                    Expanded(child: navigationShell),
                  ],
                ),
              ),
        bottomNavigationBar: isImmersive
            ? null
            : PlpcgBottomNavBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: navigationShell.goBranch,
                destinations: _destinations(ref),
              ),
      ),
    );
  }
}
