import 'dart:math' as math;

import 'package:flutter/material.dart';

/// «G» do Google em quatro cores, desenhado — sem asset nem dependência.
/// Substitui o logo que vinha embutido no botão GIS (spec §3.7).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    void arc(Color color, double startDeg, double sweepDeg) {
      canvas.drawArc(
        ring,
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        paint..color = color,
      );
    }

    arc(_red, -150, 105); // topo/esquerda
    arc(_yellow, 150, 60); // esquerda/baixo
    arc(_green, 45, 105); // baixo/direita
    arc(_blue, 0, 45); // direita, até a abertura do G

    // Barra horizontal do G: do centro até a borda direita.
    final barTop = size.height / 2 - stroke / 2;
    canvas.drawRect(
      Rect.fromLTRB(size.width / 2, barTop, size.width, barTop + stroke),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
