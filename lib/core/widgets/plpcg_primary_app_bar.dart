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
/// Em Sobre/Listas/Offline, exibe voltar para [RoutePaths.profile].
class PlpcgPrimaryAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const PlpcgPrimaryAppBar({super.key});

  static const _profileSubRoutes = {
    RoutePaths.about,
    RoutePaths.offline,
    RoutePaths.playlists,
  };

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final showBack = _profileSubRoutes.contains(path);

    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar',
              onPressed: () =>
                  goToShellDestination(context, RoutePaths.profile),
            )
          : null,
      title: const PlpcgAppBarTitle(),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(4),
        child: Divider(height: 4, thickness: 4, color: AppColors.gold),
      ),
    );
  }
}
