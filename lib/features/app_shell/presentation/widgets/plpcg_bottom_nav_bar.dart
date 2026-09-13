import 'package:flutter/material.dart';

import '../../../../core/theme/color_extensions.dart';
import 'nav_item.dart';

export 'nav_item.dart' show PlpcgBottomNavDestination;

/// Bottom bar customizada UC-14 — fundo [AppColors.background], divisor gold 4px,
/// aba ativa ampliada com [LightBeam] sob o rótulo e transição ease ao trocar.
///
/// Substitui `NavigationBar` Material 3 em [ShellScaffold]. Respeita
/// `MediaQuery.disableAnimationsOf` (reduce-motion) e a safe area inferior via
/// [MediaQuery.viewPaddingOf] (Scaffold zera `padding.bottom` neste slot).
///
/// Itens ([PlpcgNavItem]) são compartilhados com `PlpcgNavigationRail`
/// (mesmos ícones, tipografia e brilho — só a orientação muda).
class PlpcgBottomNavBar extends StatelessWidget {
  const PlpcgBottomNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  /// Índice: 0 Eventos, 1 Biblioteca, 2 Pesquisar (`/`), 3 Social, 4 Perfil.
  final int selectedIndex;

  /// Callback ao tocar uma aba; [ShellScaffold] mapeia para `navigationShell.goBranch`.
  final ValueChanged<int> onDestinationSelected;

  /// Lista fixa de destinos (tipicamente 5 itens UC-14).
  final List<PlpcgBottomNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    // Scaffold zera `MediaQuery.padding` neste slot — usar viewPadding.
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return ColoredBox(
      color: AppColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 4, thickness: 4, color: AppColors.gold),
          Padding(
            padding: EdgeInsets.fromLTRB(
              4 + viewPadding.left,
              4,
              4 + viewPadding.right,
              viewPadding.bottom > 0 ? viewPadding.bottom + 2 : 4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: RepaintBoundary(
                      child: PlpcgNavItem(
                        destination: destinations[i],
                        selected: i == selectedIndex,
                        onTap: () => onDestinationSelected(i),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
