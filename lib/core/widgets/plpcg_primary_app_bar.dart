import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spotlight_guide/spotlight_guide.dart';

import '../routing/route_paths.dart';
import '../routing/shell_navigation.dart';
import '../theme/color_extensions.dart';
import '../tutorial/presentation/providers/tutorial_provider.dart';
import 'plpcg_app_bar_title.dart';

/// Barra superior PLPCG — título central e divisor dourado.
///
/// Usada como `appBar` do [ShellScaffold] — compartilhada por todas as rotas,
/// inclusive `/leitor`.
/// Ação de tutorial `(i)` à direita dispara o guia de uso da tela atual.
/// Toque no título → [RoutePaths.home] via `go` (limpa a pilha de `push`).
/// Em `/leitor`, `/audio`, `/cifra`, `/gestos`, `/letra`, `/listas/publicas`,
/// `/biblioteca`, `/offline`, `/sobre` e `/materiais-favoritos`, exibe voltar
/// (pop → raiz da aba dona) para padronizar.
class PlpcgPrimaryAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const PlpcgPrimaryAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final path = router == null ? null : GoRouterState.of(context).uri.path;
    // Rotas empilhadas sobre uma aba: seta volta com `pop`; sem pilha (deep
    // link direto), cai na raiz da aba dona.
    final backFallback = switch (path) {
      RoutePaths.reader ||
      RoutePaths.audio ||
      RoutePaths.chords ||
      RoutePaths.gestos ||
      RoutePaths.lyrics => RoutePaths.home,
      String p when p.startsWith('/louvor/') => RoutePaths.home,
      RoutePaths.publicPlaylists => RoutePaths.playlists,
      String p when p.startsWith('/ao-vivo/') => RoutePaths.playlists,
      RoutePaths.library ||
      RoutePaths.offline ||
      RoutePaths.about ||
      RoutePaths.contribute ||
      RoutePaths.myContributions ||
      RoutePaths.favoriteMaterialKinds => RoutePaths.profile,
      String p when p.startsWith('/contribuicoes/') =>
        RoutePaths.myContributions,
      _ => null,
    };

    final canPop =
        router != null ? router.canPop() : Navigator.of(context).canPop();

    return AppBar(
      automaticallyImplyLeading: false,
      leading: backFallback == null && !canPop
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar',
              onPressed: () {
                if (canPop) {
                  if (router != null) {
                    router.pop();
                  } else {
                    Navigator.of(context).pop();
                  }
                } else if (backFallback != null) {
                  goToShellDestination(context, backFallback);
                }
              },
            ),
      // ponytail: go (não push) — descarta /leitor, /audio e sub-rotas do shell
      title: Tooltip(
        message: 'Início',
        child: InkWell(
          onTap: () {
            if (GoRouter.maybeOf(context) != null) {
              goToShellDestination(context, RoutePaths.home);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: const PlpcgAppBarTitle(),
        ),
      ),
      actions: [
        SpotlightGuideTarget(
          id: 'app-info-button',
          child: IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Como usar esta tela',
            onPressed: () {
              try {
                final container =
                    ProviderScope.containerOf(context, listen: false);
                container
                    .read(tutorialControllerProvider)
                    .startTutorialForRoute(context, path);
              } catch (_) {
                // Em testes unitários sem ProviderScope, no-op seguro.
              }
            },
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(4),
        child: Divider(height: 4, thickness: 4, color: AppColors.gold),
      ),
    );
  }
}
