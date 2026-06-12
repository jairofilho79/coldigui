import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/color_extensions.dart';

/// Disco de luz elíptico — gradiente radial com núcleo quente, borda dourada
/// e halo difuso (light-beam §6.2).
///
/// Consumidores: [LightBeam], [PlpcgAppBarTitle], [PlpcgBottomNavBar].
class LightBeamPainter extends CustomPainter {
  const LightBeamPainter();

  static const _warmWhite = Color(0xFFFFFBEA);
  static const _brightGold = Color(0xFFFFD96B);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + 1),
        width: size.width * 1.1,
        height: size.height * 0.9,
      ),
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    final radius = size.width / 2;
    final squash = (size.height * 0.46) / size.width;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(1, squash);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          radius,
          [
            _warmWhite.withValues(alpha: 0.95),
            _brightGold.withValues(alpha: 0.80),
            AppColors.gold.withValues(alpha: 0.45),
            AppColors.gold.withValues(alpha: 0.0),
          ],
          [0.0, 0.40, 0.78, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.restore();

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + size.height * 0.45),
        width: size.width * 0.7,
        height: size.height * 0.5,
      ),
      Paint()
        ..color = _brightGold.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Feixe de luz dourado dimensionável (light-beam §6.2).
///
/// Renderiza [LightBeamPainter] em [CustomPaint]. Largura tipicamente derivada
/// do rótulo (header ~170px; aba ativa da bottom bar ~36–96px).
class LightBeam extends StatelessWidget {
  const LightBeam({
    /// Largura horizontal do feixe (centro mais intenso).
    required this.width,

    /// Altura do feixe achatado em elipse. Default `16` (header PLPCG).
    this.height = 16,
    super.key,
  });

  /// Largura horizontal do feixe.
  final double width;

  /// Altura do feixe achatado em elipse.
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: const LightBeamPainter(),
    );
  }
}
