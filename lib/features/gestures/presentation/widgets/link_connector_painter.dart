import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/gesture_reader_palette.dart';

const Key gestureLinkConnectorKey = ValueKey('gesture-link-connector');

/// Conector arqueado 3D ("Pin Bridge") à esquerda de um bloco de ligação:
/// nasce de uma esfera 3D na altura do primeiro gesto, faz um arco cilíndrico
/// com brilho especular e sombra projetada suave, e aponta com seta facetada 3D
/// para o último gesto ligado.
class LinkConnectorPainter extends CustomPainter {
  const LinkConnectorPainter({
    required this.palette,
    this.childCount = 2,
  });

  final GestureReaderPalette palette;

  /// Quantidade de filhos no bloco de ligação (normalmente 2 ou 3), usada para
  /// alinhar a esfera de origem ao centro do 1º filho e a ponta ao último filho.
  final int childCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final hsl = HSLColor.fromColor(palette.orange);
    final lightColor = hsl
        .withLightness((hsl.lightness + 0.24).clamp(0.0, 1.0))
        .toColor();
    final midLightColor = hsl
        .withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0))
        .toColor();
    final darkColor = hsl
        .withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0))
        .toColor();

    // Escala suavemente caso a altura seja muito compacta (ex.: testes ou fontes mínimas).
    final double scale = (size.height / 140.0).clamp(0.65, 1.0);
    final effectiveCount = math.max(2, childCount);

    // Posiciona a esfera no centro aproximado do 1º filho e a seta no centro do último,
    // respeitando limites seguros para blocos muito baixos ou muito altos.
    final slotHeight = size.height / effectiveCount;
    final maxAnchor = math.max(
      12.0 * scale,
      math.min(54.0, size.height * 0.30),
    );
    final double anchorPadding = (slotHeight * 0.5).clamp(
      12.0 * scale,
      maxAnchor,
    );
    final double topY = anchorPadding;
    final double bottomY = math.max(
      topY + 12.0 * scale,
      size.height - anchorPadding,
    );
    final spanY = bottomY - topY;

    final startX = size.width - 6.0 * scale;
    final tip = Offset(size.width - 1.0 * scale, bottomY);
    final headLength = 12.5 * scale;
    final headWidth = 11.0 * scale;

    // Tangente final apontando levemente para baixo e para a direita (~18 graus).
    const approachAngle = 18.0 * math.pi / 180.0;
    final cosA = math.cos(approachAngle);
    final sinA = math.sin(approachAngle);

    // O tubo termina no encaixe traseiro da cabeça da seta para não vazar na ponta.
    final neckOffset = headLength * 0.62;
    final end = Offset(
      tip.dx - neckOffset * cosA,
      tip.dy - neckOffset * sinA,
    );
    final start = Offset(startX, topY);

    final double leftApexX = (3.5 * scale).clamp(
      2.0,
      math.max(2.0, size.width * 0.35),
    );
    final ctrl1 = Offset(leftApexX, topY + spanY * 0.14);
    final ctrl2 = Offset(leftApexX, bottomY - spanY * 0.16);

    final arcPath = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, end.dx, end.dy);

    final sphereRadius = 4.6 * scale;
    final outerStroke = 4.8 * scale;
    final mainStroke = 3.7 * scale;
    final highlightStroke = 1.2 * scale;

    // 1. Sombra projetada suave (funciona em Skia, Impeller e CanvasKit Web)
    final shadowPaint = Paint()
      ..color = const Color(0x3D000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);

    canvas.save();
    canvas.translate(1.2 * scale, 2.2 * scale);
    canvas.drawPath(arcPath, shadowPaint);
    canvas.drawCircle(
      start,
      sphereRadius,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
    canvas.restore();

    // 2. Borda escura externa para dar profundidade cilíndrica 3D
    canvas.drawPath(
      arcPath,
      Paint()
        ..color = darkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStroke
        ..strokeCap = StrokeCap.round,
    );

    // 3. Corpo cilíndrico com gradiente âmbar/laranja
    canvas.drawPath(
      arcPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(leftApexX, topY),
          Offset(size.width, bottomY),
          [lightColor, midLightColor, palette.orange, darkColor],
          const [0.0, 0.35, 0.72, 1.0],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = mainStroke
        ..strokeCap = StrokeCap.round,
    );

    // 4. Filete de brilho especular no topo/esquerda da curva
    canvas.save();
    canvas.translate(-0.45 * scale, -0.45 * scale);
    canvas.drawPath(
      arcPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlightStroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // 5. Esfera 3D de ancoragem no 1º gesto
    canvas.drawCircle(
      start,
      sphereRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          start - Offset(sphereRadius * 0.35, sphereRadius * 0.35),
          sphereRadius * 1.35,
          [Colors.white, lightColor, palette.orange, darkColor],
          const [0.0, 0.25, 0.68, 1.0],
        ),
    );
    canvas.drawCircle(
      start,
      sphereRadius,
      Paint()
        ..color = darkColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.65 * scale,
    );
    canvas.drawCircle(
      start - Offset(sphereRadius * 0.32, sphereRadius * 0.32),
      sphereRadius * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // 6. Ponta de seta facetada em 3D (duas águas com luz e sombra)
    _paint3DArrowHead(
      canvas,
      tip: tip,
      cosA: cosA,
      sinA: sinA,
      headLength: headLength,
      headWidth: headWidth,
      lightColor: lightColor,
      darkColor: darkColor,
      scale: scale,
    );
  }

  void _paint3DArrowHead(
    Canvas canvas, {
    required Offset tip,
    required double cosA,
    required double sinA,
    required double headLength,
    required double headWidth,
    required Color lightColor,
    required Color darkColor,
    required double scale,
  }) {
    Offset rot(double lx, double ly) => Offset(
      tip.dx + lx * cosA - ly * sinA,
      tip.dy + lx * sinA + ly * cosA,
    );

    final backCenter = rot(-headLength * 0.70, 0);
    final topWing = rot(-headLength, -headWidth / 2);
    final bottomWing = rot(-headLength, headWidth / 2);

    final fullHead = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(topWing.dx, topWing.dy)
      ..lineTo(backCenter.dx, backCenter.dy)
      ..lineTo(bottomWing.dx, bottomWing.dy)
      ..close();

    // Sombra projetada da ponta
    canvas.save();
    canvas.translate(1.0 * scale, 1.8 * scale);
    canvas.drawPath(
      fullHead,
      Paint()
        ..color = const Color(0x3D000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.restore();

    // Faceta superior iluminada
    final topFacet = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(topWing.dx, topWing.dy)
      ..lineTo(backCenter.dx, backCenter.dy)
      ..close();

    // Faceta inferior sombreada
    final bottomFacet = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(backCenter.dx, backCenter.dy)
      ..lineTo(bottomWing.dx, bottomWing.dy)
      ..close();

    canvas.drawPath(topFacet, Paint()..color = lightColor);
    canvas.drawPath(bottomFacet, Paint()..color = darkColor);

    // Aresta central iluminada
    canvas.drawLine(
      tip,
      backCenter,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.70)
        ..strokeWidth = 0.9 * scale
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(LinkConnectorPainter old) =>
      old.palette != palette || old.childCount != childCount;
}
