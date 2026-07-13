import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
import '../../../core/widgets/degraded_storage_banner.dart';
import '../../../core/widgets/plpcg_primary_app_bar.dart';
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
///
/// [navigationShell] mantém o estado de cada aba via [StatefulShellRoute].
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({required this.navigationShell, super.key});

  /// Pilha indexada das branches do shell — preserva estado ao trocar aba.
  final StatefulNavigationShell navigationShell;

  bool _isReaderRoute(BuildContext context) {
    return GoRouterState.of(context).uri.path == RoutePaths.reader;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReader = _isReaderRoute(context);
    final isFullscreen = ref.watch(readerFullscreenProvider);

    if (!isReader && ref.read(readerFullscreenProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(readerFullscreenProvider.notifier).exit();
      });
    }

    final hideChrome = isReader && isFullscreen;

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
        bottomNavigationBar: isReader
            ? null
            : PlpcgBottomNavBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: navigationShell.goBranch,
                destinations: const [
                  PlpcgBottomNavDestination(
                    icon: Icons.event_outlined,
                    label: 'Eventos',
                  ),
                  PlpcgBottomNavDestination(
                    icon: Icons.library_books,
                    label: 'Biblioteca',
                  ),
                  PlpcgBottomNavDestination(
                    svgAsset:
                        'assets/branding/logo_colorido_no_bg_logo_only.svg',
                    label: 'Pesquisar',
                  ),
                  PlpcgBottomNavDestination(
                    icon: Icons.groups_outlined,
                    label: 'Social',
                  ),
                  PlpcgBottomNavDestination(
                    icon: Icons.person_outline,
                    label: 'Perfil',
                  ),
                ],
              ),
      ),
    );
  }
}
