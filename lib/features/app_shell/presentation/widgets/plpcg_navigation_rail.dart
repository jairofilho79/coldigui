import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/color_extensions.dart';
import 'plpcg_bottom_nav_bar.dart';

/// Rail de navegação do shell em telas largas (C6, `kRailBreakpoint`) —
/// substitui [PlpcgBottomNavBar] mantendo as mesmas
/// [PlpcgBottomNavDestination] e o mesmo índice posicional (derivado de
/// `appTabsFor`, ver [ShellScaffold]).
///
/// `extended: false` — só ícone + rótulo curto abaixo, sem o rail expandido
/// do Material. Fundo/tokens seguem [AppColors] (mesma identidade visual da
/// bottom bar).
class PlpcgNavigationRail extends StatelessWidget {
  const PlpcgNavigationRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  /// Índice da aba ativa — mesmo valor passado a [PlpcgBottomNavBar].
  final int selectedIndex;

  /// Callback ao selecionar uma aba; [ShellScaffold] mapeia para
  /// `navigationShell.goBranch`.
  final ValueChanged<int> onDestinationSelected;

  /// Mesma lista de destinos da [PlpcgBottomNavBar] (ordem de `appTabsFor`).
  final List<PlpcgBottomNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NavigationRail(
            backgroundColor: AppColors.background,
            extended: false,
            labelType: NavigationRailLabelType.all,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            selectedIconTheme: const IconThemeData(color: AppColors.gold),
            unselectedIconTheme: IconThemeData(
              color: AppColors.textLight.withValues(alpha: 0.72),
            ),
            selectedLabelTextStyle: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelTextStyle: const TextStyle(color: Color(0x8CFFFFFF)),
            destinations: [
              for (final destination in destinations)
                NavigationRailDestination(
                  icon: _PlpcgRailIcon(destination: destination),
                  label: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const VerticalDivider(width: 4, thickness: 4, color: AppColors.gold),
        ],
      ),
    );
  }
}

/// Ícone de uma [PlpcgBottomNavDestination] no rail — mesmas três variantes
/// da bottom bar (ícone Material, SVG da logo, avatar), sem a animação de
/// escala/feixe (o rail já é estático como o resto do Material `NavigationRail`).
class _PlpcgRailIcon extends StatelessWidget {
  const _PlpcgRailIcon({required this.destination});

  final PlpcgBottomNavDestination destination;

  @override
  Widget build(BuildContext context) {
    final svgAsset = destination.svgAsset;
    if (svgAsset != null) {
      return SvgPicture.asset(
        svgAsset,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      );
    }

    final avatar = destination.avatarImage;
    if (avatar != null) {
      return ClipOval(
        child: Image(
          image: avatar,
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.person, color: AppColors.textLight),
        ),
      );
    }

    // `Icon(Icons.xxx)` direto — mesmos literais já usados em
    // [PlpcgBottomNavBar] (tree-shake do Flutter Web).
    return switch (destination.icon) {
      Icons.event => const Icon(Icons.event, color: AppColors.textLight),
      Icons.library_books => const Icon(
        Icons.library_books,
        color: AppColors.textLight,
      ),
      Icons.groups => const Icon(Icons.groups, color: AppColors.textLight),
      Icons.person => const Icon(Icons.person, color: AppColors.textLight),
      Icons.playlist_play => const Icon(
        Icons.playlist_play,
        color: AppColors.textLight,
      ),
      final icon? => Icon(icon, color: AppColors.textLight),
      null => const Icon(Icons.circle, color: AppColors.textLight),
    };
  }
}
