import 'package:flutter/material.dart';

import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';

/// Pontuação que cola no gatilho sem espaço (spec §4).
const _noSpaceBefore = {',', '.', ';', ':', '!', '?', ')', ']'};

/// Troca espaços por NBSP: o gatilho nunca quebra linha.
String nonBreaking(String s) => s.replaceAll(' ', ' ');

/// Uma linha de letra: gatilho vermelho negrito + leitura preta.
///
/// Um `Text.rich` com dois `TextSpan` — o espaço entre eles entra no span da
/// leitura para que a quebra de linha, se vier, caia depois do gatilho inteiro.
class LyricLineText extends StatelessWidget {
  const LyricLineText({
    required this.line,
    required this.fontSize,
    required this.palette,
    super.key,
  });

  final LyricLine line;
  final double fontSize;
  final GestureReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    final trigger = line.trigger;
    final text = line.text;
    final glue = text.isEmpty || _noSpaceBefore.contains(text[0]) ? '' : ' ';

    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: fontSize, height: 1.3, color: palette.lyric),
        children: [
          if (trigger.isNotEmpty)
            TextSpan(
              text: nonBreaking(trigger),
              style: TextStyle(
                color: palette.trigger,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (text.isNotEmpty)
            TextSpan(
              text: trigger.isEmpty ? text : '$glue$text',
              style: TextStyle(
                color: palette.lyric,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }
}
