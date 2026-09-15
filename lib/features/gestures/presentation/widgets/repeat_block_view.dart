import 'package:flutter/material.dart';

import '../theme/gesture_reader_palette.dart';
import 'brace_painter.dart';

/// Bloco `Nx`: filhos empilhados + chave azul à direita com a altura deles.
///
/// `Stack` de propósito, não `Row(stretch)`: em altura ilimitada (corpo
/// rolável) o `RenderFlex` passaria `tightFor(height: ∞)` aos filhos. Aqui a
/// `Column` (com padding da largura da chave) dá o tamanho ao `Stack`, e o
/// `Positioned.fill` herda a altura sem medição intrínseca. Aninhar é só
/// empilhar `Stack`s: cada nível recua os filhos em [kGestureBraceWidth].
class RepeatBlockView extends StatelessWidget {
  const RepeatBlockView({
    required this.count,
    required this.palette,
    required this.children,
    super.key,
  });

  final int count;
  final GestureReaderPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return BracedChildren(
      dashed: false,
      label: '${count}x',
      palette: palette,
      children: children,
    );
  }
}

/// Filhos + chave vertical à direita. Compartilhado por repeat e coro.
class BracedChildren extends StatelessWidget {
  const BracedChildren({
    required this.dashed,
    required this.palette,
    required this.children,
    this.label,
    super.key,
  });

  final bool dashed;
  final GestureReaderPalette palette;
  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: kGestureBraceWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: kGestureBraceWidth,
          child: CustomPaint(
            key: gestureBraceKey,
            painter: BracePainter(dashed: dashed, label: label, palette: palette),
          ),
        ),
      ],
    );
  }
}
