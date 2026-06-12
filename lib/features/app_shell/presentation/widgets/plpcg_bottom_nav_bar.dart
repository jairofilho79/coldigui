import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/light_beam.dart';

/// Destino da bottom bar PLPCG — par ícone + rótulo.
///
/// Usado em [PlpcgBottomNavBar.destinations].
class PlpcgBottomNavDestination {
  const PlpcgBottomNavDestination({
    required this.icon,
    required this.label,
  });

  /// Ícone Material exibido acima do rótulo.
  final IconData icon;

  /// Rótulo curto (ex.: `Pesquisar`, `Biblioteca`). Truncado com ellipsis se necessário.
  final String label;
}

/// Bottom bar customizada UC-14 — fundo [AppColors.background], divisor gold 4px,
/// aba ativa ampliada com [LightBeam] sob o rótulo e transição ease ao trocar.
///
/// Substitui `NavigationBar` Material 3 em [ShellScaffold]. Respeita
/// `MediaQuery.disableAnimationsOf` (reduce-motion).
class PlpcgBottomNavBar extends StatelessWidget {
  const PlpcgBottomNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  /// Duração da animação scale/feixe/texto ao trocar aba (380ms, [Curves.easeInOut]).
  static const Duration animationDuration = Duration(milliseconds: 380);

  static const Curve _animationCurve = Curves.easeInOut;

  /// Índice da aba selecionada: 0 Sobre, 1 Biblioteca, 2 Pesquisar (`/`), 3 Offline, 4 Listas.
  final int selectedIndex;

  /// Callback ao tocar uma aba; [ShellScaffold] mapeia para `context.go`.
  final ValueChanged<int> onDestinationSelected;

  /// Lista fixa de destinos (tipicamente 5 itens UC-14).
  final List<PlpcgBottomNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: AppColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(
            height: 4,
            thickness: 4,
            color: AppColors.gold,
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 4,
              right: 4,
              top: 6,
              bottom: bottomInset > 0 ? 4 : 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _PlpcgBottomNavItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onDestinationSelected(i),
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

class _PlpcgBottomNavItem extends StatelessWidget {
  const _PlpcgBottomNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final PlpcgBottomNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  static const _activeScale = 1.14;
  static const _inactiveScale = 0.86;

  Duration _duration(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : PlpcgBottomNavBar.animationDuration;
  }

  @override
  Widget build(BuildContext context) {
    final duration = _duration(context);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.gold.withValues(alpha: 0.18),
          highlightColor: AppColors.gold.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: AnimatedScale(
              scale: selected ? _activeScale : _inactiveScale,
              duration: duration,
              curve: PlpcgBottomNavBar._animationCurve,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: duration,
                    curve: PlpcgBottomNavBar._animationCurve,
                    width: selected ? 34 : 26,
                    height: selected ? 34 : 26,
                    alignment: Alignment.center,
                    child: AnimatedTheme(
                      duration: duration,
                      curve: PlpcgBottomNavBar._animationCurve,
                      data: Theme.of(context).copyWith(
                        iconTheme: IconThemeData(
                          color: selected
                              ? AppColors.placeholder
                              : AppColors.textLight.withValues(alpha: 0.52),
                          size: selected ? 26 : 20,
                        ),
                      ),
                      child: Icon(destination.icon),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _NavLabel(
                    label: destination.label,
                    selected: selected,
                    duration: duration,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel({
    required this.label,
    required this.selected,
    required this.duration,
  });

  final String label;
  final bool selected;
  final Duration duration;

  static const _activeStyle = TextStyle(
    fontFamily: AppTypography.garamondFamily,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    letterSpacing: 0.4,
    height: 1.1,
    color: AppColors.placeholder,
    shadows: [
      Shadow(
        color: Color(0x66D4AF37),
        blurRadius: 6,
        offset: Offset(0, 1),
      ),
    ],
  );

  static const _inactiveStyle = TextStyle(
    fontFamily: AppTypography.sansFamily,
    fontWeight: FontWeight.w500,
    fontSize: 10,
    height: 1.1,
    color: Color(0x8CFFFFFF),
  );

  double _beamWidth(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return (painter.width * 1.35).clamp(36.0, 96.0);
  }

  @override
  Widget build(BuildContext context) {
    final beamWidth = _beamWidth(_activeStyle);

    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 12,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: duration,
              curve: PlpcgBottomNavBar._animationCurve,
              child: AnimatedScale(
                scale: selected ? 1 : 0.6,
                duration: duration,
                curve: PlpcgBottomNavBar._animationCurve,
                alignment: Alignment.topCenter,
                child: LightBeam(width: beamWidth, height: 9),
              ),
            ),
          ),
          AnimatedDefaultTextStyle(
            duration: duration,
            curve: PlpcgBottomNavBar._animationCurve,
            style: selected ? _activeStyle : _inactiveStyle,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
