import 'package:flutter/material.dart';

import '../theme/gesture_reader_palette.dart';

const Key gestureLinkConnectorKey = ValueKey('gesture-link-connector');

/// Conector vertical laranja com seta para baixo: os filhos executam sem pausa.
class LinkConnectorPainter extends CustomPainter {
  const LinkConnectorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GestureReaderPalette.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    final bottom = size.height - 4;
    canvas.drawLine(Offset(x, 4), Offset(x, bottom - 6), paint);
    final head = Path()
      ..moveTo(x - 5, bottom - 8)
      ..lineTo(x, bottom)
      ..lineTo(x + 5, bottom - 8)
      ..close();
    canvas.drawPath(head, Paint()..color = GestureReaderPalette.orange);
  }

  @override
  bool shouldRepaint(LinkConnectorPainter old) => false;
}
