import 'package:flutter/material.dart';

import '../../domain/entities/gesture_dictionary.dart';
import '../../domain/entities/gesture_document.dart';
import '../theme/gesture_reader_palette.dart';
import 'gesture_figure.dart';
import 'lyric_line_text.dart';

/// Chave estável do cartão de índice [index] (o índice do `flatten`).
Key gestureCardKey(int index) => ValueKey('gesture-card-$index');

/// Chave do `Material` que pinta a faixa da zebra do cartão [index].
Key gestureCardStripeKey(int index) => ValueKey('gesture-card-stripe-$index');

/// Cartão de gesto: figura à esquerda, letra à direita, **centralizados na
/// vertical** — com 1 ou 3 linhas, a letra fica no meio da figura.
///
/// Ocupa a largura toda do nível e zebra pelo índice do `flatten`
/// (ímpar = [GestureReaderPalette.stripe]); é a zebra que separa os cartões,
/// por isso o gap entre eles é pequeno. A figura e **toda** a letra ficam no
/// mesmo cartão — a leitura é o que se canta enquanto o gesto dura.
/// [entry] já vem resolvido pelo dicionário; `null` mostra o placeholder.
class GestureCardTile extends StatelessWidget {
  const GestureCardTile({
    required this.index,
    required this.card,
    required this.entry,
    required this.fontSize,
    required this.palette,
    this.onTap,
    super.key,
  });

  final int index;
  final GestureCard card;
  final GestureEntry? entry;
  final double fontSize;
  final GestureReaderPalette palette;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final side = gestureFigureSide(fontSize);
    // `Material` colorido, não `DecoratedBox`: o ink do `InkWell` pinta no
    // `Material` mais próximo — assim o toque aparece sobre a faixa.
    return Material(
      key: gestureCardStripeKey(index),
      color: index.isOdd ? palette.stripe : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        key: gestureCardKey(index),
        onTap: onTap == null ? null : () => onTap!(index),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureFigure(
                entry: entry,
                gestureId: card.gestureId,
                side: side,
                palette: palette,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in card.lyrics)
                      LyricLineText(
                        line: line,
                        fontSize: fontSize,
                        palette: palette,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
