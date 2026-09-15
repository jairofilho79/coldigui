import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/gesture_reader_palette.dart';

/// Chave do `CustomPaint` da chave de bloco (repeat/coro) — para testes.
const Key gestureBraceKey = ValueKey('gesture-brace');

/// Chave vertical à direita de um bloco: `}` espelhada, altura = altura dos
/// filhos (o `Positioned.fill` que a hospeda garante isso).
///
/// [label] (`Nx`) é pintado centralizado verticalmente, à esquerda da chave.
/// [dashed] é a variante do `coro`.
class BracePainter extends CustomPainter {
  const BracePainter({required this.dashed, required this.palette, this.label});

  final bool dashed;
  final GestureReaderPalette palette;
  final String? label;

  static const double _stroke = 2;
  static const double _hook = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    // Chave nos 12 dp da direita; o resto da coluna é do rótulo.
    final x = size.width - 12;
    final tip = size.width - 2;
    final midY = size.height / 2;
    final path = Path()
      ..moveTo(x - _hook, 1)
      ..quadraticBezierTo(x, 1, x, _hook)
      ..lineTo(x, midY - _hook)
      ..quadraticBezierTo(x, midY, tip, midY)
      ..quadraticBezierTo(x, midY, x, midY + _hook)
      ..lineTo(x, size.height - _hook)
      ..quadraticBezierTo(x, size.height - 1, x - _hook, size.height - 1);

    canvas.drawPath(dashed ? _dash(path) : path, paint);

    final label = this.label;
    if (label == null) return;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: palette.blue,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: x - 2);
    painter.paint(
      canvas,
      Offset((x - 2 - painter.width) / 2, midY - painter.height / 2),
    );
  }

  static Path _dash(Path source) {
    const dash = 5.0;
    const gap = 4.0;
    final out = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0, metric.length).toDouble();
        out.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(BracePainter old) =>
      old.dashed != dashed || old.label != label || old.palette != palette;
}
