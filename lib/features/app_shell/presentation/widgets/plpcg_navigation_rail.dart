import 'package:flutter/material.dart';

import '../../../../core/theme/color_extensions.dart';
import 'nav_item.dart';

/// Rail de navegação do shell em telas largas (C6, `kRailBreakpoint`) —
/// substitui `PlpcgBottomNavBar` mantendo as mesmas
/// [PlpcgBottomNavDestination] e o mesmo índice posicional (derivado de
/// `appTabsFor`, ver `ShellScaffold`).
///
/// Mesma identidade visual da bottom bar: fundo [AppColors.background],
/// borda dourada de 4px separando o rail do corpo, e os mesmos
/// [PlpcgNavItem] — ícones SVG/Material próprios, rótulo em EB Garamond
/// quando ativo e o feixe [LightBeam] dourado sob o rótulo selecionado — só
/// dispostos verticalmente ([Axis.vertical]) em vez de numa `Row`. Nenhum
/// widget `NavigationRail` do Material é usado.
class PlpcgNavigationRail extends StatelessWidget {
  const PlpcgNavigationRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  /// Largura total do rail (itens + borda dourada), dentro da faixa 96–112px
  /// pedida para preservar o ritmo visual da bottom bar num layout vertical.
  static const double width = 104;

  static const double _itemWidth = width - 4;

  /// Índice da aba ativa — mesmo valor passado a [PlpcgBottomNavBar].
  final int selectedIndex;

  /// Callback ao selecionar uma aba; [ShellScaffold] mapeia para
  /// `navigationShell.goBranch`.
  final ValueChanged<int> onDestinationSelected;

  /// Mesma lista de destinos da [PlpcgBottomNavBar] (ordem de `appTabsFor`).
  final List<PlpcgBottomNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    // Scaffold zera `MediaQuery.padding` neste slot — usar viewPadding, como
    // a bottom bar faz para a safe area inferior (aqui, a lateral esquerda).
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return ColoredBox(
      color: AppColors.background,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // `stretch` garante que a coluna ocupe toda a altura disponível —
        // os itens ficam alinhados no topo (comportamento padrão de
        // `SingleChildScrollView` quando o conteúdo é menor que o viewport)
        // e a borda dourada acompanha a altura inteira do rail, como o
        // divisor horizontal da bottom bar acompanha a largura inteira.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _itemWidth + viewPadding.left,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(viewPadding.left, 12, 0, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                      child: RepaintBoundary(
                        child: PlpcgNavItem(
                          destination: destinations[i],
                          selected: i == selectedIndex,
                          onTap: () => onDestinationSelected(i),
                          axis: Axis.vertical,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 4, thickness: 4, color: AppColors.gold),
        ],
      ),
    );
  }
}
