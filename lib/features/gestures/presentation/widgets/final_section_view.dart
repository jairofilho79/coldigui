import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../theme/gesture_reader_palette.dart';

const Key gestureFinalDividerKey = ValueKey('gesture-final-divider');

/// `FINAL`: divisor traço-ponto + rótulo à esquerda, depois os filhos.
class FinalSectionView extends StatelessWidget {
  const FinalSectionView({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                l10n?.gestureContextFinal ?? 'FINAL',
                style: const TextStyle(
                  color: GestureReaderPalette.wine,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: SizedBox(
                  height: 2,
                  child: CustomPaint(
                    key: gestureFinalDividerKey,
                    painter: _DashDotPainter(),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _DashDotPainter extends CustomPainter {
  const _DashDotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GestureReaderPalette.wine
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + 8).clamp(0, size.width), y), paint);
      x += 12;
      if (x < size.width) canvas.drawPoints(PointMode.points, [Offset(x, y)], paint);
      x += 5;
    }
  }

  @override
  bool shouldRepaint(_DashDotPainter old) => false;
}
