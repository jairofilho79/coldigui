import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/light_beam.dart';

/// Destino da bottom bar PLPCG — par ícone + rótulo.
///
/// Usado em [PlpcgBottomNavBar.destinations].
class PlpcgBottomNavDestination {
  const PlpcgBottomNavDestination({
    this.icon,
    this.svgAsset,
    required this.label,
  }) : assert(icon != null || svgAsset != null, 'Informe icon ou svgAsset');

  /// Ícone Material exibido acima do rótulo.
  final IconData? icon;

  /// SVG colorido (ex.: logo PLPCG na aba Pesquisar).
  final String? svgAsset;

  /// Rótulo curto (ex.: `Pesquisar`, `Biblioteca`). Truncado com ellipsis se necessário.
  final String label;
}

/// Bottom bar customizada UC-14 — fundo [AppColors.background], divisor gold 4px,
/// aba ativa ampliada com [LightBeam] sob o rótulo e transição ease ao trocar.
///
/// Substitui `NavigationBar` Material 3 em [ShellScaffold]. Respeita
/// `MediaQuery.disableAnimationsOf` (reduce-motion) e a safe area inferior via
/// [MediaQuery.viewPaddingOf] (Scaffold zera `padding.bottom` neste slot).
class PlpcgBottomNavBar extends StatelessWidget {
  const PlpcgBottomNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  /// Duração da animação scale/feixe/texto ao trocar aba (200ms, [Curves.easeOut]).
  static const Duration animationDuration = Duration(milliseconds: 200);

  static const Curve _animationCurve = Curves.easeOut;

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
                      child: _PlpcgBottomNavItem(
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

class _PlpcgBottomNavItem extends StatefulWidget {
  const _PlpcgBottomNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final PlpcgBottomNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PlpcgBottomNavItem> createState() => _PlpcgBottomNavItemState();
}

class _PlpcgBottomNavItemState extends State<_PlpcgBottomNavItem>
    with SingleTickerProviderStateMixin {
  static const _activeScale = 1.14;
  static const _inactiveScale = 0.86;

  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PlpcgBottomNavBar.animationDuration,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: PlpcgBottomNavBar._animationCurve,
    );
    if (widget.selected) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _PlpcgBottomNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected == widget.selected) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.selected ? 1 : 0;
      return;
    }

    if (widget.selected) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: AppColors.gold.withValues(alpha: 0.18),
          highlightColor: AppColors.gold.withValues(alpha: 0.08),
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, _) {
              final t = _progress.value;
              final scale = lerpDouble(_inactiveScale, _activeScale, t)!;
              final iconBoxSize = lerpDouble(26, 34, t)!;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: iconBoxSize,
                        height: iconBoxSize,
                        child: Center(
                          child: _NavIcon(
                            destination: widget.destination,
                            progress: t,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      _NavLabel(label: widget.destination.label, progress: t),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.destination, required this.progress});

  final PlpcgBottomNavDestination destination;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final svgAsset = destination.svgAsset;
    if (svgAsset != null) {
      final size = lerpDouble(24, 32, progress)!;
      final opacity = lerpDouble(0.52, 1, progress)!;
      return Opacity(
        opacity: opacity,
        child: SvgPicture.asset(
          svgAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
        ),
      );
    }

    final color = Color.lerp(
      AppColors.textLight.withValues(alpha: 0.52),
      AppColors.placeholder,
      progress,
    )!;
    final size = lerpDouble(20, 26, progress)!;
    return Icon(destination.icon, color: color, size: size);
  }
}

class _NavLabel extends StatefulWidget {
  const _NavLabel({required this.label, required this.progress});

  final String label;
  final double progress;

  static const _activeStyle = TextStyle(
    fontFamily: AppTypography.garamondFamily,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    letterSpacing: 0.4,
    height: 1.1,
    color: AppColors.placeholder,
    shadows: [
      Shadow(color: Color(0x66D4AF37), blurRadius: 6, offset: Offset(0, 1)),
    ],
  );

  static const _inactiveStyle = TextStyle(
    fontFamily: AppTypography.sansFamily,
    fontWeight: FontWeight.w500,
    fontSize: 10,
    height: 1.1,
    color: Color(0x8CFFFFFF),
  );

  @override
  State<_NavLabel> createState() => _NavLabelState();
}

class _NavLabelState extends State<_NavLabel> {
  late final double _beamWidth;

  @override
  void initState() {
    super.initState();
    _beamWidth = _computeBeamWidth(widget.label, _NavLabel._activeStyle);
  }

  static double _computeBeamWidth(String label, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return (painter.width * 1.35).clamp(36.0, 96.0);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.progress;
    final beamOpacity = t;
    final beamScale = lerpDouble(0.6, 1, t)!;
    final style = TextStyle.lerp(
      _NavLabel._inactiveStyle,
      _NavLabel._activeStyle,
      t,
    )!;

    return SizedBox(
      height: 20,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 12,
            child: Opacity(
              opacity: beamOpacity,
              child: Transform.scale(
                scale: beamScale,
                alignment: Alignment.topCenter,
                child: LightBeam(width: _beamWidth, height: 9),
              ),
            ),
          ),
          Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: style,
          ),
        ],
      ),
    );
  }
}
