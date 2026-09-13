import 'package:flutter/material.dart';

import '../../domain/entities/gesture_dictionary.dart';
import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';
import 'gesture_figure.dart';
import 'lyric_line_text.dart';

/// Chave estável do cartão de índice [index] (o índice do `flatten`).
Key gestureCardKey(int index) => ValueKey('gesture-card-$index');

/// Cartão de gesto: figura à esquerda, letra à direita, alinhados pelo topo.
///
/// A figura e **toda** a letra ficam no mesmo cartão — a leitura preta é o que
/// se canta enquanto o gesto dura. [entry] já vem resolvido pelo dicionário
/// (alias seguido); `null` mostra o placeholder.
class GestureCardTile extends StatelessWidget {
  const GestureCardTile({
    required this.index,
    required this.card,
    required this.entry,
    required this.fontSize,
    this.onTap,
    super.key,
  });

  final int index;
  final GestureCard card;
  final GestureEntry? entry;
  final double fontSize;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final side = gestureFigureSide(fontSize);
    return InkWell(
      key: gestureCardKey(index),
      onTap: onTap == null ? null : () => onTap!(index),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureFigure(entry: entry, gestureId: card.gestureId, side: side),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in card.lyrics)
                  LyricLineText(line: line, fontSize: fontSize),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
