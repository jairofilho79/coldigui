import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/route_paths.dart';
import '../routing/shell_navigation.dart';
import '../theme/color_extensions.dart';
import 'plpcg_app_bar_title.dart';

/// Barra superior PLPCG — título central e divisor dourado.
///
/// Usada como `appBar` do [ShellScaffold] — compartilhada por todas as rotas,
/// inclusive `/leitor`. Sem `actions` (badge offline removido).
/// Toque no título → [RoutePaths.home] via `go` (limpa a pilha de `push`).
/// Em `/leitor`, `/audio`, `/cifra` e `/gestos`, exibe voltar (pop → home)
/// para padronizar.
class PlpcgPrimaryAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const PlpcgPrimaryAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final isImmersiveMedia =
        path == RoutePaths.reader ||
        path == RoutePaths.audio ||
        path == RoutePaths.chords ||
        path == RoutePaths.gestos;

    return AppBar(
      automaticallyImplyLeading: false,
      leading: isImmersiveMedia
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  goToShellDestination(context, RoutePaths.home);
                }
              },
            )
          : null,
      // ponytail: go (não push) — descarta /leitor, /audio e sub-rotas do shell
      title: Tooltip(
        message: 'Início',
        child: InkWell(
          onTap: () => goToShellDestination(context, RoutePaths.home),
          borderRadius: BorderRadius.circular(8),
          child: const PlpcgAppBarTitle(),
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(4),
        child: Divider(height: 4, thickness: 4, color: AppColors.gold),
      ),
    );
  }
}
