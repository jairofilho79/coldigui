import 'package:flutter/material.dart';

import '../theme/gesture_reader_palette.dart';

/// Linha livre (`text`) e destino de itens desconhecidos: cinza, itálico.
class TextLineView extends StatelessWidget {
  const TextLineView({required this.text, required this.fontSize, super.key});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: GestureReaderPalette.freeText,
        fontStyle: FontStyle.italic,
        fontSize: fontSize - 2,
      ),
    );
  }
}
