import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
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
/// Bottom bar: [PlpcgBottomNavBar] com fundo marrom, aba ativa ampliada e
/// feixe dourado; oculta em `/leitor`. Destino central: rótulo **Pesquisar**
/// (logo PLPCG, rota [RoutePaths.home]).
///
/// [child] é a rota ativa dentro do [ShellRoute] (home, biblioteca, leitor, etc.).
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({required this.child, super.key});

  /// Conteúdo da rota selecionada, injetado pelo GoRouter.
  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return switch (location) {
      RoutePaths.about => 0,
      RoutePaths.library => 1,
      RoutePaths.home => 2,
      RoutePaths.offline => 3,
      RoutePaths.playlists => 4,
      _ => 2,
    };
  }

  void _onTap(BuildContext context, int index) {
    final path = switch (index) {
      0 => RoutePaths.about,
      1 => RoutePaths.library,
      2 => RoutePaths.home,
      3 => RoutePaths.offline,
      4 => RoutePaths.playlists,
      _ => RoutePaths.home,
    };
    context.go(path);
  }

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
            ? child
            : SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                    const CarouselChips(),
                    Expanded(child: child),
                  ],
                ),
              ),
        bottomNavigationBar: isReader
            ? null
            : PlpcgBottomNavBar(
                selectedIndex: _selectedIndex(context),
                onDestinationSelected: (i) => _onTap(context, i),
                destinations: const [
                  PlpcgBottomNavDestination(
                    icon: Icons.info_outline,
                    label: 'Sobre',
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
                    icon: Icons.cloud_download,
                    label: 'Offline',
                  ),
                  PlpcgBottomNavDestination(
                    icon: Icons.playlist_play,
                    label: 'Listas',
                  ),
                ],
              ),
      ),
    );
  }
}
