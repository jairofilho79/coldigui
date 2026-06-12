import 'package:flutter/material.dart';

import '../theme/color_extensions.dart';
import 'plpcg_app_bar_title.dart';

/// Barra superior PLPCG — título central e divisor dourado.
///
/// Usada como `appBar` do [ShellScaffold] — compartilhada por todas as rotas,
/// inclusive `/leitor`. Sem `actions` (badge offline removido).
class PlpcgPrimaryAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const PlpcgPrimaryAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 4);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: const PlpcgAppBarTitle(),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(4),
        child: Divider(
          height: 4,
          thickness: 4,
          color: AppColors.gold,
        ),
      ),
    );
  }
}
