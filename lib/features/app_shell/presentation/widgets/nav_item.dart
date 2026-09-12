import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/color_extensions.dart';
import '../../../../core/widgets/light_beam.dart';

/// Destino da navegação PLPCG — par ícone + rótulo.
///
/// Usado por [PlpcgBottomNavBar] e [PlpcgNavigationRail] (mesma lista,
/// mesmo índice posicional).
class PlpcgBottomNavDestination {
  const PlpcgBottomNavDestination({
    this.icon,
    this.svgAsset,
    this.avatarImage,
    required this.label,
  }) : assert(
         icon != null || svgAsset != null || avatarImage != null,
         'Informe icon, svgAsset ou avatarImage',
       );

  /// Ícone Material exibido acima do rótulo.
  final IconData? icon;

  /// SVG colorido (ex.: logo PLPCG na aba Pesquisar).
  final String? svgAsset;

  /// Foto de perfil (ex.: avatar Google na aba Perfil).
  final ImageProvider? avatarImage;

  /// Rótulo curto (ex.: `Pesquisar`, `Biblioteca`). Truncado com ellipsis se necessário.
  final String label;
}

/// Item de navegação PLPCG — ícone (SVG/Material/avatar) + rótulo em
/// EB Garamond quando ativo, com o feixe [LightBeam] dourado sob o rótulo e
/// transição de escala/opacidade ao selecionar.
///
/// Compartilhado entre [PlpcgBottomNavBar] (itens em [Axis.horizontal], numa
/// `Row`) e `PlpcgNavigationRail` (itens em [Axis.vertical], numa `Column`) —
/// mesmos ícones, tipografia e brilho nas duas orientações.
class PlpcgNavItem extends StatefulWidget {
  const PlpcgNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.axis = Axis.horizontal,
    super.key,
  });

  /// Duração da animação scale/feixe/texto ao trocar aba (200ms, [Curves.easeOut]).
  static const Duration animationDuration = Duration(milliseconds: 200);

  static const Curve animationCurve = Curves.easeOut;

  final PlpcgBottomNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  /// [Axis.horizontal] (bottom bar — item ancorado embaixo, escala a partir
  /// do centro-base) ou [Axis.vertical] (rail — item centralizado na coluna,
  /// escala a partir do centro).
  final Axis axis;

  @override
  State<PlpcgNavItem> createState() => _PlpcgNavItemState();
}

class _PlpcgNavItemState extends State<PlpcgNavItem>
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
      duration: PlpcgNavItem.animationDuration,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: PlpcgNavItem.animationCurve,
    );
    if (widget.selected) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant PlpcgNavItem oldWidget) {
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
    final vertical = widget.axis == Axis.vertical;
    final scaleAlignment = vertical ? Alignment.center : Alignment.bottomCenter;
    final padding = vertical
        ? const EdgeInsets.symmetric(vertical: 8, horizontal: 6)
        : const EdgeInsets.symmetric(vertical: 4);

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
                padding: padding,
                child: Transform.scale(
                  scale: scale,
                  alignment: scaleAlignment,
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

    final avatar = destination.avatarImage;
    if (avatar != null) {
      final size = lerpDouble(22, 28, progress)!;
      return ClipOval(
        child: Image(
          image: avatar,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            final color = Color.lerp(
              AppColors.textLight.withValues(alpha: 0.72),
              AppColors.placeholder,
              progress,
            )!;
            final sizeIcon = lerpDouble(20, 26, progress)!;
            return Icon(Icons.person, color: color, size: sizeIcon);
          },
        ),
      );
    }

    final color = Color.lerp(
      AppColors.textLight.withValues(alpha: 0.72),
      AppColors.placeholder,
      progress,
    )!;
    final size = lerpDouble(20, 26, progress)!;
    // `Icon(Icons.xxx)` direto — tree-shake do Flutter Web só inclui esses usos.
    return switch (destination.icon) {
      Icons.event => Icon(Icons.event, color: color, size: size),
      Icons.library_books => Icon(
        Icons.library_books,
        color: color,
        size: size,
      ),
      Icons.groups => Icon(Icons.groups, color: color, size: size),
      Icons.person => Icon(Icons.person, color: color, size: size),
      Icons.playlist_play => Icon(
        Icons.playlist_play,
        color: color,
        size: size,
      ),
      final icon? => Icon(icon, color: color, size: size),
      null => Icon(Icons.circle, color: color, size: size),
    };
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
  static double _computeBeamWidth(String label, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return (painter.width * 1.35).clamp(36.0, 96.0);
  }

  // A15: `TextPainter.layout()` só quando o rótulo muda de fato — nunca em
  // `build()`, que roda a cada frame da animação de troca de aba.
  late double _beamWidth;

  @override
  void initState() {
    super.initState();
    _beamWidth = _computeBeamWidth(widget.label, _NavLabel._activeStyle);
  }

  @override
  void didUpdateWidget(_NavLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.label != oldWidget.label) {
      _beamWidth = _computeBeamWidth(widget.label, _NavLabel._activeStyle);
    }
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
    final beamWidth = _beamWidth;

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
                child: LightBeam(width: beamWidth, height: 9),
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
